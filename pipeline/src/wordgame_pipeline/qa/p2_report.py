"""Offline P2 campaign QA combines measured scores with editorial uncertainty."""

import hashlib
from collections import defaultdict

from ..config import canonical_bytes, parse_json
from .summary import summarize_campaign


def campaign_qa_report(
    levels: list | tuple,
    lexical_review_raw: bytes,
    *,
    bucket_edges: tuple,
    review_limit: int,
) -> bytes:
    """Create canonical QA evidence; never infer word safety or release approval."""
    if type(review_limit) is not int or review_limit < 1:
        raise ValueError("Expected a positive explicit review limit")
    if not isinstance(lexical_review_raw, bytes):
        raise ValueError("Expected canonical pinned lexical review bytes")
    try:
        lexical = parse_json(lexical_review_raw.decode("utf-8"))
    except (UnicodeError, ValueError) as exc:
        raise ValueError("Invalid lexical review encoding") from exc
    if (
        not isinstance(lexical, dict)
        or canonical_bytes(lexical) != lexical_review_raw
        or lexical.get("schema_version") != 1
        or lexical.get("lang") != "pl"
        or lexical.get("semantic_approval_inferred") is not False
        or not isinstance(lexical.get("basis"), dict)
        or not isinstance(lexical.get("unresolved"), list)
        or not isinstance(lexical.get("escalations"), list)
    ):
        raise ValueError("Lexical review must be the canonical P2 no-approval artifact")
    summary = summarize_campaign(levels, bucket_edges=bucket_edges)
    unresolved = {}
    escalation = {}
    for collection, target, tier in (
        (lexical["unresolved"], unresolved, "level_ok"),
        (lexical["escalations"], escalation, None),
    ):
        previous = ""
        for row in collection:
            if (
                not isinstance(row, dict)
                or not isinstance(row.get("word"), str)
                or row["word"] <= previous
                or row.get("source_tier") not in (
                    ("bonus_ok", "banned") if tier is None else (tier,)
                )
                or not isinstance(row.get("evidence_flags"), list)
                or any(not isinstance(flag, str) or not flag for flag in row["evidence_flags"])
            ):
                raise ValueError("Invalid or unsorted lexical review evidence")
            target[row["word"]] = row
            previous = row["word"]
    if set(unresolved) & set(escalation):
        raise ValueError("A word cannot be unresolved and escalated simultaneously")

    slots: dict[str, list[int]] = defaultdict(list)
    for level in levels:
        for word in {row["w"] for row in level["words"]}:
            slots[word].append(level["slot"])
    flagged = []
    for word in sorted(set(slots) & (set(unresolved) | set(escalation))):
        evidence = unresolved.get(word) or escalation[word]
        flagged.append(
            {
                "word": word,
                "slots": sorted(slots[word]),
                "source_tier": evidence["source_tier"],
                "evidence_flags": evidence["evidence_flags"],
                "action": "human_lexical_review_required",
            }
        )
    hardest = sorted(levels, key=lambda row: (-row["difficulty"], row["slot"]))[
        :review_limit
    ]
    report = {
        "schema_version": 1,
        "lang": "pl",
        "scope": "offline_review_not_release_approval",
        "basis": {
            "lexical_review_sha256": hashlib.sha256(lexical_review_raw).hexdigest(),
            "tier_basis": lexical["basis"],
        },
        "summary": summary,
        "hardest_slots": [
            {"slot": level["slot"], "difficulty": level["difficulty"]} for level in hardest
        ],
        "uncertain_selected_words": flagged,
        "unresolved_lexical_candidates": len(unresolved),
        "manual_escalations": len(escalation),
        "human_approval_recorded": False,
    }
    return canonical_bytes(report)
