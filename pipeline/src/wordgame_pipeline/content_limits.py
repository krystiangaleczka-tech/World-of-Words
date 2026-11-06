"""Shared campaign upper bound and canonical pack-path formatting."""

MAX_CAMPAIGN_SLOTS = 30_000


def validate_campaign_slots(slots: object, minimum: int = 1) -> int:
    """Fail closed on bool, non-integer or out-of-range campaign counts."""
    if type(minimum) is not int or not 1 <= minimum <= MAX_CAMPAIGN_SLOTS:
        raise ValueError("Invalid campaign minimum")
    if type(slots) is not int or not minimum <= slots <= MAX_CAMPAIGN_SLOTS:
        raise ValueError(
            f"Campaign slots must be an integer from {minimum} to {MAX_CAMPAIGN_SLOTS}"
        )
    return slots


def pack_filename(first: int, last: int) -> str:
    """Four digits for legacy packs; five digits when a boundary exceeds 9,999."""
    validate_campaign_slots(first)
    validate_campaign_slots(last)
    if first > last:
        raise ValueError("Campaign pack has a reversed range")
    return f"packs/c-{first:04d}-{last:04d}.json"
