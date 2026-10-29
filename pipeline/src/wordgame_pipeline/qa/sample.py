"""Conservative deterministic human review sample, not a release signoff."""

from ..sequence.curve import ONBOARDING_LAST
from ..sequence.slots import SlotPlan


def plan_review_slots(
    plan: SlotPlan, flagged_slots: tuple[int, ...], *, regular_stride: int
) -> tuple[int, ...]:
    """Include all onboarding, landmarks, breathers and explicit review flags."""
    if not isinstance(plan, SlotPlan):
        raise ValueError("Expected protected slot plan")
    if type(regular_stride) is not int or regular_stride < 1:
        raise ValueError("Review stride must be a positive integer")
    if (
        not isinstance(flagged_slots, tuple)
        or any(type(slot) is not int or not 1 <= slot <= plan.total for slot in flagged_slots)
        or len(set(flagged_slots)) != len(flagged_slots)
    ):
        raise ValueError("Expected distinct in-range flagged review slots")
    chosen = set(flagged_slots)
    for slot in range(1, plan.total + 1):
        requirement = plan.requirement(slot)
        if (
            slot <= ONBOARDING_LAST
            or requirement.curve.kind in ("landmark", "breather")
            or (slot > ONBOARDING_LAST and (slot - ONBOARDING_LAST - 1) % regular_stride == 0)
        ):
            chosen.add(slot)
    return tuple(sorted(chosen))
