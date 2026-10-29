"""Read-only ranked slot deviations from explicitly reviewed curve targets."""

import math
from collections.abc import Mapping
from dataclasses import dataclass

from .slots import SlotPlan


@dataclass(frozen=True)
class CurveDeviation:
    slot: int
    region: str
    location: str
    kind: str
    score: float
    target: float
    deviation: float


def _unit(value: object) -> float:
    if type(value) not in (int, float):
        raise ValueError("Score and review window must be finite numeric values")
    try:
        number = float(value)
    except OverflowError as exc:
        raise ValueError("Unrepresentable score or window") from exc
    if not math.isfinite(number) or not 0 <= number <= 1:
        raise ValueError("Expected normalized score/window in [0,1]")
    return number


def review_curve_deviations(
    plan: SlotPlan, scores: Mapping[int, float], *, max_deviation: float
) -> tuple[CurveDeviation, ...]:
    """Rank explicit scores outside a review window, without moving any slot.

    Slots 1..15 are validated but omitted: onboarding has no generated target.
    The caller owns score provenance and production window approval.
    """
    window = _unit(max_deviation)
    if (
        not isinstance(plan, SlotPlan)
        or not isinstance(scores, Mapping)
        or plan.total > 9999
        or len(scores) != plan.total
    ):
        raise ValueError("Expected complete exported-size campaign scores and slot plan")
    if any(type(slot) is not int or not 1 <= slot <= plan.total for slot in scores):
        raise ValueError("Invalid campaign score slot")
    values = {slot: _unit(scores[slot]) for slot in scores}
    flagged = []
    for slot in range(1, plan.total + 1):
        requirement = plan.requirement(slot)
        target = requirement.curve.target
        if target is None:
            continue
        score = values[slot]
        deviation = abs(score - target)
        if deviation > window:
            flagged.append(
                CurveDeviation(
                    slot,
                    requirement.region,
                    requirement.location,
                    requirement.curve.kind,
                    score,
                    target,
                    deviation,
                )
            )
    return tuple(sorted(flagged, key=lambda item: (-item.deviation, item.slot)))
