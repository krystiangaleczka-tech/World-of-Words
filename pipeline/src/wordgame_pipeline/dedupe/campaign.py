"""Translate validated campaign levels into authoritative duplicate policy evidence."""

from collections.abc import Mapping, Sequence
from dataclasses import dataclass

from ..config import LanguageConfig
from .core import DuplicateConflict, DuplicatePolicy, audit_duplicates


@dataclass(frozen=True)
class CampaignDiversity:
    slots: int
    conflicts: tuple[DuplicateConflict, ...]


def audit_campaign_diversity(
    levels: Sequence[Mapping],
    seed_words: Mapping[int, str],
    config: LanguageConfig,
    policy: DuplicatePolicy,
) -> CampaignDiversity:
    """Inspect every crossword word, not bonuses; no mutation or automatic removal."""
    if not isinstance(levels, (list, tuple)) or not levels or not isinstance(seed_words, Mapping):
        raise ValueError("Expected nonempty campaign and explicit seed-word mapping")
    records = []
    used_slots = set()
    for level in levels:
        if not isinstance(level, Mapping):
            raise ValueError("Invalid campaign record")
        slot = level.get("slot")
        if (
            type(slot) is not int
            or slot < 1
            or slot in used_slots
            or level.get("id") != f"pl-c-{slot:06d}"
        ):
            raise ValueError("Duplicate or invalid campaign slot identity")
        used_slots.add(slot)
        placements = level.get("words")
        if not isinstance(placements, list) or not placements:
            raise ValueError("Expected selected crossword placements")
        if any(
            not isinstance(row, Mapping) or not isinstance(row.get("w"), str) for row in placements
        ):
            raise ValueError("Malformed selected crossword word")
        words = [row["w"] for row in placements]
        if len(set(words)) != len(words):
            raise ValueError("Duplicate selected crossword word")
        records.append(
            {
                "id": level["id"],
                "pool": "campaign",
                "slot": slot,
                "letters": level.get("letters"),
                "words": words,
                "seed_word": seed_words.get(slot),
            }
        )
    if set(seed_words) != used_slots or sorted(used_slots) != list(range(1, len(levels) + 1)):
        raise ValueError("Every contiguous campaign slot requires exactly one explicit seed")
    return CampaignDiversity(
        len(levels),
        audit_duplicates(records, policy, config),
    )


def require_campaign_diversity(result: CampaignDiversity) -> None:
    """Hard fail closed before P2 publication; caller retains conflict evidence."""
    if not isinstance(result, CampaignDiversity):
        raise ValueError("Expected a validated campaign diversity audit")
    if result.conflicts:
        reasons = sorted({reason for conflict in result.conflicts for reason in conflict.reasons})
        raise ValueError("Campaign diversity violation: " + ", ".join(reasons))
