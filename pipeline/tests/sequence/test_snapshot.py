"""Protected ownership and curve visualization snapshots remain readonly."""

from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.sequence.curve import CurveConfig
from wordgame_pipeline.sequence.slots import Location, Region, Reservation, SlotPlan
from wordgame_pipeline.sequence.snapshot import SlotCurveRow, snapshot_curve


def plan():
    config = CurveConfig(
        first=1,
        last=18,
        base=0.5,
        trend=0,
        period=5,
        amplitude=0,
        landmark_spike=0.25,
        breather_drop=0.25,
        landmarks=(16,),
    )
    return SlotPlan(
        regions=(Region("r", config),),
        locations=(Location("l", "r", 1, 18),),
        authored=tuple(Reservation(i, f"pl-c-{i:06d}") for i in range(1, 17)),
        released=(
            Reservation(1, "pl-c-000001"),
            Reservation(2, "pl-c-000002"),
        ),
    )


def test_explicit_onboarding_landmark_breather_and_regular():
    report = snapshot_curve(plan(), (18, 1, 17, 16, 2))
    assert tuple(row.slot for row in report) == (1, 2, 16, 17, 18)
    assert report[0] == SlotCurveRow(1, "r", "l", "onboarding", None, None, True, True)
    assert report[1].released is True
    assert report[2] == SlotCurveRow(16, "r", "l", "landmark", 0.75, 0.5, True, False)
    assert report[3] == SlotCurveRow(17, "r", "l", "breather", 0.25, 0.5, False, False)
    assert report[4] == SlotCurveRow(18, "r", "l", "regular", 0.5, 0.5, False, False)
    with pytest.raises(FrozenInstanceError):
        report[0].slot = 4


def test_order_independent_and_fresh_results():
    a = snapshot_curve(plan(), (17, 16))
    b = snapshot_curve(plan(), (16, 17))
    assert a == b and a is not b
    assert snapshot_curve(plan(), (18,))[0].kind == "regular"


@pytest.mark.parametrize(
    "slots",
    [(), (0,), (19,), (1, 1), (True,), (1.0,), ("1",), [1], (None,)],
)
def test_invalid_positions_fail(slots):
    with pytest.raises(ValueError):
        snapshot_curve(plan(), slots)


def test_missing_plan_fails():
    with pytest.raises(ValueError):
        snapshot_curve(None, (1,))
