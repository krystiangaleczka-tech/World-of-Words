"""Deviation examples use fixture curve targets, not production calibration."""

import copy
from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.sequence.curve import CurveConfig
from wordgame_pipeline.sequence.deviation_review import CurveDeviation, review_curve_deviations
from wordgame_pipeline.sequence.slots import Location, Region, Reservation, SlotPlan


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
        authored=tuple(
            Reservation(slot, f"pl-c-{slot:06d}") for slot in range(1, 17)
        ),
        released=(),
    )


def scores():
    schedule = plan()
    return {
        slot: schedule.requirement(slot).curve.target or 0.0
        for slot in range(1, schedule.total + 1)
    }


def test_target_boundary_strict_window_and_landmark_breather_context():
    campaign = scores()
    campaign[16] = 0.5
    campaign[17] = 0.75
    campaign[18] = 1
    result = review_curve_deviations(plan(), campaign, max_deviation=0.25)
    assert result == (
        CurveDeviation(17, "r", "l", "breather", 0.75, 0.25, 0.5),
        CurveDeviation(18, "r", "l", "regular", 1.0, 0.5, 0.5),
    )
    assert review_curve_deviations(plan(), scores(), max_deviation=0) == ()
    assert review_curve_deviations(plan(), campaign, max_deviation=0.5) == ()


def test_onboarding_is_not_flagged_but_still_validated():
    campaign = scores()
    campaign[1] = 1
    assert review_curve_deviations(plan(), campaign, max_deviation=0) == ()


def test_order_independence_nonmutation_and_frozen_report():
    campaign = scores()
    campaign[18] = 1
    before = copy.deepcopy(campaign)
    first = review_curve_deviations(plan(), campaign, max_deviation=0)
    second = review_curve_deviations(
        plan(), dict(reversed(list(campaign.items()))), max_deviation=0
    )
    assert first == second and campaign == before
    with pytest.raises(FrozenInstanceError):
        first[0].slot = 999


@pytest.mark.parametrize(
    "bad",
    [True, None, "0.1", -0.1, 1.1, float("nan"), float("inf"), 10**400],
)
def test_invalid_window_fails(bad):
    with pytest.raises(ValueError):
        review_curve_deviations(plan(), scores(), max_deviation=bad)


@pytest.mark.parametrize(
    "bad",
    [True, None, "0.1", -0.1, 1.1, float("nan"), float("inf"), 10**400],
)
def test_invalid_score_fails_even_on_onboarding(bad):
    campaign = scores()
    campaign[1] = bad
    with pytest.raises(ValueError):
        review_curve_deviations(plan(), campaign, max_deviation=0.1)


def test_missing_extra_bool_and_malformed_mapping_fail():
    campaign = scores()
    cases = [
        {k: v for k, v in campaign.items() if k != 18},
        campaign | {19: 0.5},
        {True if slot == 1 else slot: value for slot, value in campaign.items()},
        {18.0 if slot == 18 else slot: value for slot, value in campaign.items()},
        None,
        [0.5] * 18,
    ]
    for case in cases:
        with pytest.raises(ValueError):
            review_curve_deviations(plan(), case, max_deviation=0.1)
    with pytest.raises(ValueError):
        review_curve_deviations(None, campaign, max_deviation=0.1)
