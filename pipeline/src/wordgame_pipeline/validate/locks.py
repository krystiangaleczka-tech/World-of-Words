"""Released identity/geometry guard; never create or update a release baseline."""

import hashlib
import os
import re
import stat
from dataclasses import dataclass
from pathlib import Path

from ..config import canonical_bytes, parse_json
from .schema import json_value

MAX_SLOT = 9999  # Current four-digit campaign pack filename contract.


def _identity(slot: object, identity: object) -> None:
    if (
        type(slot) is not int
        or not 1 <= slot <= MAX_SLOT
        or not isinstance(identity, str)
        or identity != f"pl-c-{slot:06d}"
    ):
        raise ValueError("Invalid released campaign identity/slot")


def geometry_sha256(level: object) -> str:
    json_value(level)
    if not isinstance(level, dict):
        raise ValueError("Expected campaign level object")
    _identity(level.get("slot"), level.get("id"))
    letters, words, grid = (level.get(key) for key in ("letters", "words", "grid"))
    if (
        not isinstance(letters, list)
        or not 3 <= len(letters) <= 8
        or any(not isinstance(c, str) or len(c) != 1 for c in letters)
        or not isinstance(words, list)
        or not words
        or not isinstance(grid, dict)
        or set(grid) != {"w", "h"}
        or any(type(n) is not int or not 1 <= n <= 10 for n in grid.values())
    ):
        raise ValueError("Invalid released geometry projection")
    for placement in words:
        if (
            not isinstance(placement, dict)
            or set(placement) != {"w", "x", "y", "dir"}
            or not isinstance(placement["w"], str)
            or not 3 <= len(placement["w"]) <= 8
            or placement["dir"] not in ("h", "v")
            or any(type(placement[k]) is not int or not 0 <= placement[k] <= 9 for k in ("x", "y"))
        ):
            raise ValueError("Invalid released word placement")
    return hashlib.sha256(
        canonical_bytes(dict(letters=letters, words=words, grid=grid))
    ).hexdigest()


@dataclass(frozen=True)
class LockedSlot:
    slot: int
    id: str
    geometry_sha256: str

    def __post_init__(self) -> None:
        _identity(self.slot, self.id)
        if not isinstance(self.geometry_sha256, str) or not re.fullmatch(
            r"[0-9a-f]{64}", self.geometry_sha256
        ):
            raise ValueError("Invalid released geometry SHA256")


@dataclass(frozen=True)
class ReleaseLock:
    lang: str
    levels: tuple[LockedSlot, ...]

    def __post_init__(self) -> None:
        if (
            self.lang != "pl"
            or not isinstance(self.levels, tuple)
            or not self.levels
            or any(not isinstance(level, LockedSlot) for level in self.levels)
            or any(level.slot != slot for slot, level in enumerate(self.levels, 1))
        ):
            raise ValueError("Expected nonempty ordered PL released prefix1..R")

    @classmethod
    def from_dict(cls, data: object) -> "ReleaseLock":
        json_value(data)
        if (
            not isinstance(data, dict)
            or set(data) != {"schema_version", "lang", "levels"}
            or type(data["schema_version"]) is not int
            or data["schema_version"] != 1
            or not isinstance(data["levels"], list)
        ):
            raise ValueError("Invalid version1 release lock fields")
        entries = []
        for item in data["levels"]:
            if not isinstance(item, dict) or set(item) != {"slot", "id", "geometry_sha256"}:
                raise ValueError("Invalid released slot fields")
            entries.append(LockedSlot(**item))
        return cls(data["lang"], tuple(entries))

    def to_dict(self) -> dict:
        return dict(
            schema_version=1,
            lang=self.lang,
            levels=[
                dict(slot=e.slot, id=e.id, geometry_sha256=e.geometry_sha256) for e in self.levels
            ],
        )


def verify_release_lock(lock: ReleaseLock, levels: list | tuple) -> None:
    if not isinstance(lock, ReleaseLock) or not isinstance(levels, (list, tuple)):
        raise ValueError("Expected release lock and complete campaign collection")
    hashes = []
    for slot, level in enumerate(levels, 1):
        hashes.append(geometry_sha256(level))
        if level["slot"] != slot:
            raise ValueError(f"Released campaign order mismatch at slot {slot}")
    if len(hashes) < len(lock.levels):
        raise ValueError("Released campaign prefix missing")
    for entry, actual in zip(lock.levels, hashes, strict=False):
        if entry.geometry_sha256 != actual:
            raise ValueError(f"Released geometry changed at slot {entry.slot}")


def load_release_lock(root: Path, lang: str) -> ReleaseLock | None:
    if lang != "pl":
        raise ValueError("Released locks support language pl only")
    path = (root / "locks" / f"{lang}.lock.json").absolute()
    directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
    directory = os.open(path.anchor, directory_flags)
    try:
        try:
            for component in path.parts[1:-1]:
                child = os.open(component, directory_flags, dir_fd=directory)
                os.close(directory)
                directory = child
            descriptor = os.open(
                path.name,
                os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
                dir_fd=directory,
            )
            try:
                if not stat.S_ISREG(os.fstat(descriptor).st_mode):
                    raise ValueError("Release lock must be a regular file")
                with os.fdopen(descriptor, encoding="utf-8", closefd=False) as stream:
                    raw = stream.read()
            finally:
                os.close(descriptor)
        except FileNotFoundError:
            return None
        except OSError as exc:
            raise ValueError(
                "Release lock path must use real directories and a regular file"
            ) from exc
    finally:
        os.close(directory)
    return ReleaseLock.from_dict(parse_json(raw))


def extend_release_lock(
    previous: ReleaseLock | None, levels: list | tuple, released_through: int
) -> ReleaseLock:
    """Propose an explicit prefix; callers own approval and full semantic gates."""
    if previous is not None and not isinstance(previous, ReleaseLock):
        raise ValueError("Expected previous release lock or None")
    if (
        not isinstance(levels, (list, tuple))
        or type(released_through) is not int
        or not 1 <= released_through <= min(len(levels), MAX_SLOT)
        or (previous is not None and released_through < len(previous.levels))
    ):
        raise ValueError("Invalid release cutoff or attempted prefix shrink")
    if previous is None:
        # A temporary first entry enables the existing complete-campaign validator.
        first = levels[0]
        previous = ReleaseLock("pl", (LockedSlot(1, "pl-c-000001", geometry_sha256(first)),))
    verify_release_lock(previous, levels)
    return ReleaseLock(
        "pl",
        previous.levels
        + tuple(
            LockedSlot(level["slot"], level["id"], geometry_sha256(level))
            for level in levels[len(previous.levels) : released_through]
        ),
    )
