"""Read-only campaign diversity hard gate with explicit, reviewed seed words."""

from collections.abc import Mapping

from ..config import LanguageConfig
from ..dedupe import DuplicatePolicy, audit_duplicates


def validate_campaign_diversity(
    levels: list | tuple,
    seed_by_slot: Mapping[int, str],
    policy: DuplicatePolicy,
    config: LanguageConfig,
) -> None:
    """Reject duplicate letter multisets, word sets and spacing across all slots.

    Tier, bonus, geometry, and seed provenance are validated by the caller.
    The explicit seed map is mandatory: a numeric grid RNG seed is not a word.
    """
    if not isinstance(levels, (list, tuple)) or not levels:
        raise ValueError("Expected a nonempty finite campaign")
    if not isinstance(seed_by_slot, Mapping):
        raise ValueError("Expected explicit seed words keyed by campaign slot")
    if any(type(slot) is not int for slot in seed_by_slot):
        raise ValueError("Seed slots must be integers")
    records = []
    slots: set[int] = set()
    for level in levels:
        if not isinstance(level, dict):
            raise ValueError("Expected validated campaign level dictionaries")
        slot = level.get("slot")
        if (
            type(slot) is not int
            or not 1 <= slot <= 9999
            or slot in slots
            or level.get("id") != f"pl-c-{slot:06d}"
        ):
            raise ValueError("Invalid or repeated campaign slot identity")
        slots.add(slot)
        try:
            words = [placement["w"] for placement in level["words"]]
            record = dict(
                id=level["id"],
                pool="campaign",
                slot=slot,
                letters=level["letters"],
                words=words,
                seed_word=seed_by_slot[slot],
            )
        except (KeyError, TypeError) as exc:
            raise ValueError("Missing campaign words or explicit seed") from exc
        records.append(record)
    if slots != set(range(1, len(levels) + 1)) or set(seed_by_slot) != slots:
        raise ValueError("Campaign or seed positions must cover contiguous slots")
    conflicts = audit_duplicates(records, policy, config)
    if conflicts:
        first = conflicts[0]
        raise ValueError(
            f"Campaign duplicate {first.left_id}/{first.right_id}: {','.join(first.reasons)}"
        )
