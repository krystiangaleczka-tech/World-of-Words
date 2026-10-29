"""Explicit fixture-only difficulty windows; no production calibration is implied."""

import copy
from dataclasses import replace

import pytest
from wordgame_pipeline.sequence.curve import CurveConfig
from wordgame_pipeline.sequence.slots import Location, Region, Reservation, SlotPlan
from wordgame_pipeline.validate.difficulty import validate_difficulty_window


def plan():
    config = CurveConfig(
        first=1,
        last=16,
        base=0.2,
        trend=0,
        period=5,
        amplitude=0,
        landmark_spike=0.1,
        breather_drop=0.1,
        landmarks=(),
    )
    return SlotPlan(
        regions=(Region("region-1", config),),
        locations=(Location("location-1", "region-1", 1, 16),),
        authored=tuple(Reservation(slot, f"pl-c-{slot:06d}") for slot in range(1, 16)),
        released=(),
    )


def campaign():
    return [
        {
            "slot": slot,
            "id": f"pl-c-{slot:06d}",
            "difficulty": 0 if slot <= 15 else 0.2,
            "landmark": False,
            "source": "handmade" if slot <= 15 else "generated",
        }
        for slot in range(1, 17)
    ]


def test_complete_campaign_and_order_independence():
    levels = campaign()
    before = copy.deepcopy(levels)
    assert validate_difficulty_window(levels, plan(), max_deviation=0) is None
    assert validate_difficulty_window(levels[::-1], plan(), max_deviation=0) is None
    assert levels == before


def test_exact_boundary_outside_window_and_unconstrained_onboarding():
    levels = campaign()
    levels[-1]["difficulty"] = 0.25
    validate_difficulty_window(levels, plan(), max_deviation=0.05)
    levels[-1]["difficulty"] = 0.26
    with pytest.raises(ValueError, match="outside reviewed window"):
        validate_difficulty_window(levels, plan(), max_deviation=0.05)
    levels = campaign()
    levels[0]["difficulty"] = 1
    validate_difficulty_window(levels, plan(), max_deviation=0)


@pytest.mark.parametrize(
    "invalid",
    [True, None, "0.2", -0.1, 1.1, float("nan"), float("inf"), 10**400],
)
def test_bad_score_rejected_even_for_onboarding(invalid):
    levels = campaign()
    levels[0]["difficulty"] = invalid
    with pytest.raises(ValueError):
        validate_difficulty_window(levels, plan(), max_deviation=0.2)


@pytest.mark.parametrize(
    "invalid", [True, None, "0.05", -0.1, 1.1, float("nan"), float("inf"), 10**400]
)
def test_unreviewed_or_invalid_window_fails(invalid):
    with pytest.raises(ValueError):
        validate_difficulty_window(campaign(), plan(), max_deviation=invalid)


def test_missing_duplicate_invalid_identity_and_wrong_source_fail():
    levels = campaign()
    for altered in (
        levels[:-1],
        [*levels[:-1], levels[0]],
        [*levels[:-1], levels[-1] | {"slot": True}],
        [*levels[:-1], levels[-1] | {"id": "pl-c-999999"}],
        [*levels[:-1], levels[-1] | {"source": "handmade"}],
        [*levels[:-1], levels[-1] | {"landmark": True}],
        [*levels[:-1], None],
    ):
        with pytest.raises(ValueError):
            validate_difficulty_window(altered, plan(), max_deviation=1)


def test_plan_ownership_and_region_targets_are_not_guessed():
    levels = campaign()
    alternative = replace(plan().regions[0].curve, base=0.8)
    original = plan()
    stricter = replace(original, regions=(Region("region-1", alternative),))
    with pytest.raises(ValueError, match="outside reviewed window"):
        validate_difficulty_window(levels, stricter, max_deviation=0.05)
    with pytest.raises(ValueError):
        validate_difficulty_window(levels, None, max_deviation=1)


@pytest.mark.parametrize("score,window", [(0.8, 0.6), (0.15, 0.05)])
def test_decimal_boundary_does_not_fail_from_binary_rounding(score, window):
    levels = campaign()
    levels[-1]["difficulty"] = score
    validate_difficulty_window(levels, plan(), max_deviation=window)
    levels[-1]["difficulty"] = score + (0.000001 if score > 0.2 else -0.000001)
    with pytest.raises(ValueError, match="outside reviewed window"):
        validate_difficulty_window(levels, plan(), max_deviation=window)
