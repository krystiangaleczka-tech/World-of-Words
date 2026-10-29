"""Explicit sequence QA window does not release or assign content."""

from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.sequence.curve import CurveConfig
from wordgame_pipeline.sequence.phase_coverage import summarize_phase_coverage
from wordgame_pipeline.sequence.slots import Location, Region, Reservation, SlotPlan


def plan():
    cfg = CurveConfig(1, 18, 0.5, 0, 5, 0, 0.25, 0.25, (16,))
    return SlotPlan(
        regions=(Region("r", cfg),),
        locations=(Location("a", "r", 1, 16), Location("b", "r", 17, 18)),
        authored=tuple(Reservation(i, f"pl-c-{i:06d}") for i in range(1, 17)),
        released=(Reservation(1, "pl-c-000001"),),
    )


def test_partition_and_protected_counts():
    result = summarize_phase_coverage(plan(), first=15, last=18)
    assert len(result) == 2
    a, b = result
    assert (a.region, a.location, a.first, a.last) == ("r", "a", 15, 16)
    assert a.kinds == (
        ("onboarding", 1), ("regular", 0), ("landmark", 1), ("breather", 0)
    )
    assert a.authored == 2 and a.released == 0
    assert b.kinds == (
        ("onboarding", 0), ("regular", 1), ("landmark", 0), ("breather", 1)
    )
    assert b.authored == b.released == 0
    with pytest.raises(FrozenInstanceError):
        a.authored = 5


def test_full_prefix_and_repeatability():
    report = summarize_phase_coverage(plan(), first=1, last=3)
    assert len(report) == 1 and report[0].kinds[0] == ("onboarding", 3)
    assert report[0].released == 1 and report[0].authored == 3
    assert report == summarize_phase_coverage(plan(), first=1, last=3)


@pytest.mark.parametrize(
    "first,last", [(0, 1), (2, 1), (1, 19), (True, 2), (1, 1.0), ("1", 2)]
)
def test_invalid_window_rejected(first, last):
    with pytest.raises(ValueError):
        summarize_phase_coverage(plan(), first=first, last=last)


def test_invalid_plan_rejected():
    with pytest.raises(ValueError):
        summarize_phase_coverage(None, first=1, last=1)
