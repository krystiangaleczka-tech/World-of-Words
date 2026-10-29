"""Read-only regional generated-difficulty coverage for content review."""

import math
from dataclasses import dataclass

from .slots import SlotPlan


@dataclass(frozen=True)
class RegionTargetReview:
    region: str
    slots: int
    onboarding: int
    generated: int
    minimum_target: float | None
    maximum_target: float | None
    mean_target: float | None


def review_region_targets(plan: SlotPlan) -> tuple[RegionTargetReview, ...]:
    """Summarize authoritative slot targets without moving any levels."""
    if not isinstance(plan, SlotPlan):
        raise ValueError("Expected validated slot plan")
    rows = []
    for region in plan.regions:
        targets = []
        onboarding = 0
        for slot in range(region.curve.first, region.curve.last + 1):
            curve = plan.requirement(slot).curve
            if curve.target is None:
                onboarding += 1
            else:
                targets.append(curve.target)
        rows.append(
            RegionTargetReview(
                region.id,
                region.curve.last - region.curve.first + 1,
                onboarding,
                len(targets),
                min(targets) if targets else None,
                max(targets) if targets else None,
                math.fsum(targets) / len(targets) if targets else None,
            )
        )
    return tuple(rows)
