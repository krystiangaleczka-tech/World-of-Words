"""Deterministic source-backed lexical review without automated semantic verdicts."""

import csv
import hashlib
import io
import re
from dataclasses import asdict
from pathlib import Path
from typing import cast

from .. import __version__
from ..annotate.sources import load_pin as annotation_pin
from ..config import LanguageConfig, canonical_bytes, parse_json
from ..familiarity import load_catalog
from ..ingest.source import load_pin as source_pin
from ..tiers.core import TIERS, assign_tiers, parse_overrides, valid_word

SHA256 = re.compile(r"[0-9a-f]{64}")
CATALOG_HEADER = ["word", "band", "status", "reviewer", "rationale"]


def _digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


class _MemoryInput:
    """Read-only Path adapter for the existing file-based evidence validators."""

    def __init__(self, raw: bytes, parts: tuple[str, ...] = ()) -> None:
        self.raw = raw
        self.parts = parts

    def __truediv__(self, part: str) -> "_MemoryInput":
        if (*self.parts, part) not in (
            ("sources",),
            ("sources", "sjp-pl.json"),
            ("sources", "annotation-pl.json"),
        ):
            raise ValueError("Unexpected evidence path")
        return _MemoryInput(self.raw, (*self.parts, part))

    def read_text(self, *, encoding: str) -> str:
        return self.raw.decode(encoding)

    def open(self, mode: str = "r", *, encoding: str, newline: str) -> io.StringIO:
        if mode != "r" or self.parts:
            raise ValueError("Evidence is read-only")
        return io.StringIO(self.raw.decode(encoding), newline=newline)


def _memory_path(raw: bytes) -> Path:
    # The validators use only the read operations implemented by this adapter.
    return cast(Path, _MemoryInput(raw))


def _catalog(raw: bytes, tiers: dict[str, str]) -> dict[str, dict[str, object]]:
    try:
        # No supplied judgments is valid for a new review queue, never approval.
        if list(csv.reader(io.StringIO(raw.decode("utf-8")), strict=True)) == [CATALOG_HEADER]:
            return {}
        return {
            word: asdict(review) for word, review in load_catalog(_memory_path(raw), tiers).items()
        }
    except (UnicodeDecodeError, csv.Error) as exc:
        raise ValueError("Malformed UTF-8 editorial catalog") from exc


def _validated_tiers(
    artifact_raw: bytes,
    override_raw: bytes,
    config: LanguageConfig,
    expected_source: dict,
    expected_annotations: dict,
) -> dict:
    try:
        if (
            source_pin(_memory_path(canonical_bytes(expected_source))).to_dict() != expected_source
            or annotation_pin(_memory_path(canonical_bytes(expected_annotations)))
            != expected_annotations
        ):
            raise ValueError("Unpinned source identity")
    except (ValueError, TypeError, KeyError) as exc:
        raise ValueError("Unpinned or malformed source identity") from exc
    try:
        envelope = parse_json(artifact_raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as exc:
        raise ValueError("Invalid tier artifact encoding or JSON") from exc
    if (
        not isinstance(envelope, dict)
        or set(envelope)
        != {
            "schema_version",
            "pipeline_version",
            "lang",
            "stage",
            "config_sha256",
            "input_sha256",
            "payload",
        }
        or canonical_bytes(envelope) != artifact_raw
        or type(envelope["schema_version"]) is not int
        or envelope["schema_version"] != 1
        or envelope["pipeline_version"] != __version__
        or envelope["lang"] != "pl"
        or envelope["lang"] != config.lang
        or envelope["stage"] != "05-tiers"
        or envelope["config_sha256"] != _digest(canonical_bytes(config.to_dict()))
        or not isinstance(envelope["input_sha256"], str)
        or SHA256.fullmatch(envelope["input_sha256"]) is None
    ):
        raise ValueError("Tier artifact identity or provenance mismatch")
    payload = envelope["payload"]
    if (
        not isinstance(payload, dict)
        or set(payload)
        != {
            "source",
            "annotation_sources",
            "overrides_sha256",
            "tier_rules",
            "tier_rules_sha256",
            "records",
            "tier_counts",
            "unmatched_overrides",
        }
        or payload.get("source") != expected_source
        or payload.get("annotation_sources") != expected_annotations
        or payload.get("overrides_sha256") != _digest(override_raw)
        or payload.get("tier_rules")
        != parse_json(canonical_bytes(asdict(config.tier_rules)).decode("utf-8"))
        or payload.get("tier_rules_sha256") != _digest(canonical_bytes(asdict(config.tier_rules)))
    ):
        raise ValueError("Unpinned tier evidence, rules or overrides")
    records = payload.get("records")
    if not isinstance(records, list):
        raise ValueError("Missing tier records")
    raw_records = []
    for record in records:
        if not isinstance(record, dict) or set(record) != {
            "word",
            "frequency",
            "analyses",
            "has_lemma_evidence",
            "tier",
            "tier_reason",
            "override",
        }:
            raise ValueError("Invalid tier record fields")
        if record["tier"] not in TIERS or not isinstance(record["tier_reason"], str):
            raise ValueError("Invalid tier identity")
        raw_records.append(
            {key: record[key] for key in ("word", "frequency", "analyses", "has_lemma_evidence")}
        )
    decisions = parse_overrides(override_raw.decode("utf-8"), config)
    checked = assign_tiers(raw_records, config, decisions)
    if any(
        canonical_bytes(payload.get(key)) != canonical_bytes(checked[key])
        for key in ("records", "tier_counts", "unmatched_overrides")
    ):
        raise ValueError("Tier records disagree with pinned rules and decisions")
    return payload


def _flags(record: dict) -> list[str]:
    flags: list[str] = []
    if record["frequency"] is None:
        flags.append("frequency_missing")
    if not record["has_lemma_evidence"]:
        flags.append("lemma_missing")
    if len(record["analyses"]) > 1:
        flags.append("multiple_analyses")
    if record["tier_reason"] in ("rare_or_missing_frequency", "missing_lemma"):
        flags.append("limited_usage_evidence")
    return flags


def build_review_queue(
    tier_artifact_raw: bytes,
    override_csv_raw: bytes,
    familiarity_csv_raw: bytes,
    candidate_words: tuple[str, ...],
    config: LanguageConfig,
    expected_source: dict,
    expected_annotations: dict,
) -> bytes:
    """Return canonical JSON for human review, never an automatic word verdict.

    Source and annotation pins must be provided independently from trusted loaders.
    Tier artifacts/overrides are revalidated rather than trusted as mere suggestions.
    """
    if config.lang != "pl" or config.tier_rules is None:
        raise ValueError("Only pinned Polish tier rules are supported")
    payload = _validated_tiers(
        tier_artifact_raw, override_csv_raw, config, expected_source, expected_annotations
    )
    rows = payload["records"]
    lookup = {row["word"]: row for row in rows}
    if (
        not isinstance(candidate_words, tuple)
        or any(not valid_word(word, config) or word not in lookup for word in candidate_words)
        or list(candidate_words) != sorted(set(candidate_words))
    ):
        raise ValueError("Candidates must be sorted, unique and source-backed")
    reviews = _catalog(
        familiarity_csv_raw,
        {word: row["tier"] for word, row in lookup.items()},
    )
    unresolved = []
    escalation = []
    reviewed_count = 0
    for word in candidate_words:
        record = lookup[word]
        tier = record["tier"]
        judgment = reviews.get(word)
        if tier == "level_ok" and judgment is not None and judgment["status"] == "reviewed":
            reviewed_count += 1
            continue
        entry = {
            "word": word,
            "source_tier": tier,
            "tier_reason": record["tier_reason"],
            "source_arf": (None if record["frequency"] is None else record["frequency"]["arf"]),
            "source_frequency": record["frequency"],
            "evidence_sha256": _digest(canonical_bytes(record)),
            "has_lemma_evidence": record["has_lemma_evidence"],
            "evidence_flags": _flags(record),
            "editorial_status": judgment["status"] if judgment else "unreviewed",
        }
        if tier == "level_ok":
            unresolved.append(entry)
        else:
            entry["escalation"] = "manual_only_no_automatic_promotion"
            escalation.append(entry)
    result = {
        "schema_version": 1,
        "lang": "pl",
        "basis": {
            "tier_artifact_sha256": _digest(tier_artifact_raw),
            "overrides_sha256": _digest(override_csv_raw),
            "familiarity_catalog_sha256": _digest(familiarity_csv_raw),
        },
        "candidate_count": len(candidate_words),
        "reviewed_familiarity_count": reviewed_count,
        "unresolved": unresolved,
        "escalations": escalation,
        "semantic_approval_inferred": False,
    }
    return canonical_bytes(result)
