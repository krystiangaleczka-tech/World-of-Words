"""Read-only location composition against protected slot requirements."""

from dataclasses import dataclass

from .slots import SlotPlan


@dataclass(frozen=True)
class LocationCurveAudit:
    location: str
    region: str
    slots: int
    onboarding: int
    landmarks: int
    breathers: int
    regular: int
    authored: int
    released: int


def audit_location_curve(plan: SlotPlan) -> tuple[LocationCurveAudit, ...]:
    """Report each location exactly once without changing any assignments."""
    if not isinstance(plan, SlotPlan):
        raise ValueError("Expected validated protected slot plan")
    results = []
    for location in plan.locations:
        requirements = tuple(
            plan.requirement(slot) for slot in range(location.first, location.last + 1)
        )
        results.append(
            LocationCurveAudit(
                location.id,
                location.region,
                len(requirements),
                sum(item.curve.kind == "onboarding" for item in requirements),
                sum(item.curve.kind == "landmark" for item in requirements),
                sum(item.curve.kind == "breather" for item in requirements),
                sum(item.curve.kind == "regular" for item in requirements),
                sum(item.authored for item in requirements),
                sum(item.released for item in requirements),
            )
        )
    return tuple(results)
