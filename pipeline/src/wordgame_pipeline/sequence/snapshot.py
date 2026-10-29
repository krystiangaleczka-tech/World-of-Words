"""Selected slot curve snapshot for offline charting and manual review."""

from dataclasses import dataclass

from .slots import SlotPlan


@dataclass(frozen=True)
class SlotCurveRow:
    slot: int
    region: str
    location: str
    kind: str
    target: float | None
    baseline: float | None
    authored: bool
    released: bool


def snapshot_curve(plan: SlotPlan, slots: tuple[int, ...]) -> tuple[SlotCurveRow, ...]:
    """Read exactly the requested slots; no guessing region or production values."""
    if not isinstance(plan, SlotPlan) or not isinstance(slots, tuple) or not slots:
        raise ValueError("Expected an approved slot plan and nonempty slot tuple")
    if (
        any(type(slot) is not int or not 1 <= slot <= plan.total for slot in slots)
        or len(set(slots)) != len(slots)
    ):
        raise ValueError("Requested slots must be unique in-range integers")
    result = []
    for slot in sorted(slots):
        requirement = plan.requirement(slot)
        curve = requirement.curve
        result.append(
            SlotCurveRow(
                slot,
                requirement.region,
                requirement.location,
                curve.kind,
                curve.target,
                curve.baseline,
                requirement.authored,
                requirement.released,
            )
        )
    return tuple(result)
