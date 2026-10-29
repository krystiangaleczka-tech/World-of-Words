"""Bounded regional sequence coverage for an explicit reviewed slot window."""

from collections import defaultdict
from dataclasses import dataclass

from .slots import SlotPlan

KINDS = ("onboarding", "regular", "landmark", "breather")


@dataclass(frozen=True)
class PhaseCoverage:
    region: str
    location: str
    first: int
    last: int
    kinds: tuple[tuple[str, int], ...]
    authored: int
    released: int


def summarize_phase_coverage(plan: SlotPlan, *, first: int, last: int) -> tuple[PhaseCoverage, ...]:
    """Group immutable plan requirements, with no estimated targets or assignment."""
    if (
        not isinstance(plan, SlotPlan)
        or type(first) is not int
        or type(last) is not int
        or not 1 <= first <= last <= plan.total
        or last - first + 1 > 10000
    ):
        raise ValueError("Expected bounded, explicit in-plan slot window")
    groups: dict[tuple[str, str], list] = defaultdict(list)
    for slot in range(first, last + 1):
        req = plan.requirement(slot)
        groups[(req.region, req.location)].append(req)
    output = []
    for (region, location), rows in groups.items():
        output.append(
            PhaseCoverage(
                region,
                location,
                rows[0].slot,
                rows[-1].slot,
                tuple((kind, sum(row.curve.kind == kind for row in rows)) for kind in KINDS),
                sum(row.authored for row in rows),
                sum(row.released for row in rows),
            )
        )
    return tuple(sorted(output, key=lambda row: (row.first, row.region, row.location)))
