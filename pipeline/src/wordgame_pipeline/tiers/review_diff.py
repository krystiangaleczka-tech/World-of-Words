"""Deterministic P2 tier-drift alarm; editorial review never changes source tiers."""

import hashlib
from collections import Counter
from collections.abc import Mapping

from ..classify import build_review_queue
from ..config import LanguageConfig, canonical_bytes, parse_json
from .core import TIERS


def audit_reviewed_tiers(
    tier_artifact_raw: bytes,
    override_csv_raw: bytes,
    familiarity_csv_raw: bytes,
    previous_tiers: Mapping[str, str],
    config: LanguageConfig,
    expected_source: dict,
    expected_annotations: dict,
    *,
    max_changed_words: int,
) -> bytes:
    """Compare a reviewed baseline with an independently revalidated tier artifact.

    Only owner overrides can authorize a change *into* level_ok. A reviewed
    familiarity band is context, never permission to promote a word.
    """
    if type(max_changed_words) is not int or max_changed_words < 0:
        raise ValueError("Expected an explicit nonnegative change alarm limit")
    if not isinstance(previous_tiers, Mapping):
        raise ValueError("Expected complete previously reviewed tier mapping")
    try:
        artifact = parse_json(tier_artifact_raw.decode("utf-8"))
        records = artifact["payload"]["records"]
        words = tuple(row["word"] for row in records)
    except (UnicodeError, ValueError, KeyError, TypeError, AttributeError) as exc:
        raise ValueError("Invalid source tier artifact") from exc

    # This validates the full pinned artifact against the current rules,
    # override bytes, review catalog, source pin, and annotation pin.
    review_raw = build_review_queue(
        tier_artifact_raw,
        override_csv_raw,
        familiarity_csv_raw,
        words,
        config,
        expected_source,
        expected_annotations,
    )
    review = parse_json(review_raw.decode("utf-8"))
    if (
        any(not isinstance(w, str) or not w for w in previous_tiers)
        or set(previous_tiers) != set(words)
        or any(tier not in TIERS for tier in previous_tiers.values())
    ):
        raise ValueError("Baseline must cover exactly the same source words and legal tiers")

    current = {row["word"]: row for row in records}
    old_counts = Counter(previous_tiers.values())
    new_counts = Counter(row["tier"] for row in records)
    transitions = []
    unapproved_promotions = []
    for word in words:
        prior, row = previous_tiers[word], current[word]
        if prior == row["tier"]:
            continue
        explicit_owner_override = row["tier_reason"] == "override" and row["override"] is not None
        change = {
            "word": word,
            "from": prior,
            "to": row["tier"],
            "explicit_owner_override": explicit_owner_override,
        }
        transitions.append(change)
        if row["tier"] == "level_ok" and not explicit_owner_override:
            unapproved_promotions.append(word)

    alarm_reasons = []
    if len(transitions) > max_changed_words:
        alarm_reasons.append("change_limit_exceeded")
    if unapproved_promotions:
        alarm_reasons.append("level_promotion_without_owner_override")

    result = {
        "schema_version": 1,
        "lang": config.lang,
        "basis": {
            "tier_artifact_sha256": hashlib.sha256(tier_artifact_raw).hexdigest(),
            "override_csv_sha256": hashlib.sha256(override_csv_raw).hexdigest(),
            "familiarity_csv_sha256": hashlib.sha256(familiarity_csv_raw).hexdigest(),
            "baseline_sha256": hashlib.sha256(canonical_bytes(dict(previous_tiers))).hexdigest(),
            "review_queue_sha256": hashlib.sha256(review_raw).hexdigest(),
        },
        "previous_counts": {tier: old_counts[tier] for tier in TIERS},
        "current_counts": {tier: new_counts[tier] for tier in TIERS},
        "transition_count": len(transitions),
        "transitions": transitions,
        "unapproved_promotions": unapproved_promotions,
        "alarm_reasons": alarm_reasons,
        "alarm": bool(alarm_reasons),
        "unresolved_familiarity_count": len(review["unresolved"]),
        "manual_escalation_count": len(review["escalations"]),
        "reviewed_familiarity_count": review["reviewed_familiarity_count"],
        "automated_approval": False,
    }
    return canonical_bytes(result)
