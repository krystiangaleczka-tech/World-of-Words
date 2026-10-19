"""Readonly proposal identity; real release approval remains caller-owned."""

import hashlib
import re
from dataclasses import dataclass
from pathlib import Path

from .config import canonical_bytes, load_config
from .content import bundle, validate_content
from .filesystem import read_regular
from .validate import SchemaRegistry
from .validate.locks import MAX_SLOT, ReleaseLock, extend_release_lock, load_release_lock


def _digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


@dataclass(frozen=True)
class ReleasePlan:
    previous: ReleaseLock | None
    proposed: ReleaseLock
    campaign_slots: int
    manifest_sha256: str
    evidence_sha256: str
    validation_sha256: str

    def __post_init__(self) -> None:
        if (
            (self.previous is not None and not isinstance(self.previous, ReleaseLock))
            or not isinstance(self.proposed, ReleaseLock)
            or type(self.campaign_slots) is not int
            or not len(self.proposed.levels) <= self.campaign_slots <= MAX_SLOT
            or (
                self.previous is not None
                and self.proposed.levels[: len(self.previous.levels)] != self.previous.levels
            )
            or any(
                not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value)
                for value in (self.manifest_sha256, self.evidence_sha256, self.validation_sha256)
            )
        ):
            raise ValueError("Invalid immutable append-only release proposal")

    def to_dict(self) -> dict:
        return dict(
            schema_version=1,
            scope="release-lock-proposal",
            campaign_slots=self.campaign_slots,
            released_through=len(self.proposed.levels),
            previous_sha256=None
            if self.previous is None
            else _digest(canonical_bytes(self.previous.to_dict())),
            proposed=self.proposed.to_dict(),
            proposed_sha256=_digest(canonical_bytes(self.proposed.to_dict())),
            manifest_sha256=self.manifest_sha256,
            evidence_sha256=self.evidence_sha256,
            validation_sha256=self.validation_sha256,
        )

    @property
    def sha256(self) -> str:
        return _digest(canonical_bytes(self.to_dict()))


def _snapshot(root: Path, content_root: Path) -> tuple:
    config, registry = load_config(root, "pl"), SchemaRegistry(root)
    levels, manifest = bundle(content_root / "pl", registry)
    evidence = read_regular(root / "content-evidence/pl.json")
    if evidence is None:
        raise ValueError("Content evidence required for release proposal")
    evidence_hash = _digest(evidence)
    context = dict(
        config=config.to_dict(),
        schemas={name: _digest(raw) for name, raw in registry.raw.items()},
        evidence_sha256=evidence_hash,
    )
    return (
        levels,
        load_release_lock(root, "pl"),
        _digest(manifest),
        evidence_hash,
        _digest(canonical_bytes(context)),
    )


def plan_release_lock(root: Path, content_root: Path, released_through: int) -> ReleasePlan:
    before = _snapshot(root, content_root)
    count = validate_content(root, load_config(root, "pl"), content_root)
    after = _snapshot(root, content_root)
    if before[1:] != after[1:] or count != len(after[0]):
        raise ValueError("Release proposal inputs changed during validation")
    levels, previous, manifest, evidence, context = after
    proposed = extend_release_lock(previous, levels, released_through)
    return ReleasePlan(previous, proposed, len(levels), manifest, evidence, context)
