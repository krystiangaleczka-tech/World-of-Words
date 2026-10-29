"""Read-only P2 campaign difficulty-window gate against protected slot targets."""

import math

from ..sequence.slots import SlotPlan


def _unit(value: object) -> float:
    if type(value) not in (int, float):
        raise ValueError("Expected numeric score or window, not bool/coercion")
    try:
        number = float(value)
    except OverflowError as exc:
        raise ValueError("Unrepresentable score or window") from exc
    if not math.isfinite(number) or not 0 <= number <= 1:
        raise ValueError("Expected finite difficulty in [0,1]")
    return number


def validate_difficulty_window(
    levels: list | tuple, plan: SlotPlan, *, max_deviation: float
) -> None:
    """Verify all campaign scores against explicit region-local curve targets.

    Onboarding has no generated target, but must still have a valid score.
    Caller owns scoring provenance and a reviewed production window.
    """
    tolerance = _unit(max_deviation)
    if not isinstance(plan, SlotPlan) or not isinstance(levels, (list, tuple)):
        raise ValueError("Expected slot plan and finite level collection")
    if len(levels) != plan.total:
        raise ValueError("Difficulty gate requires every planned campaign slot")
    found: set[int] = set()
    for level in levels:
        if not isinstance(level, dict):
            raise ValueError("Expected validated campaign level")
        slot = level.get("slot")
        if type(slot) is not int or slot in found or not 1 <= slot <= plan.total:
            raise ValueError("Invalid, duplicated or missing campaign position")
        if level.get("id") != f"pl-c-{slot:06d}":
            raise ValueError("Campaign slot and identity mismatch")
        found.add(slot)
        score = _unit(level.get("difficulty"))
        requirement = plan.requirement(slot)
        if level.get("landmark") is not (requirement.curve.kind == "landmark"):
            raise ValueError(f"Landmark/curve mismatch at slot {slot}")
        source = level.get("source")
        if source not in ("handmade", "generated") or (
            (source == "handmade") != requirement.authored
        ):
            raise ValueError(f"Authored slot/source mismatch at slot {slot}")
        target = requirement.curve.target
        if target is not None and abs(score - target) > tolerance:
            raise ValueError(f"Difficulty outside reviewed window at slot {slot}")
