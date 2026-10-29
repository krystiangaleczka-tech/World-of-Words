"""Regions use explicit curve plans rather than production guesses."""

from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.sequence.curve import CurveConfig
from wordgame_pipeline.sequence.region_review import RegionTargetReview, review_region_targets
from wordgame_pipeline.sequence.slots import Location, Region, Reservation, SlotPlan


def plan(last=18):
    curve = CurveConfig(
        first=1,
        last=last,
        base=0.5,
        trend=0,
        period=5,
        amplitude=0,
        landmark_spike=0.25,
        breather_drop=0.25,
        landmarks=(16,) if last >= 18 else (),
    )
    authored = tuple(
        Reservation(slot, f"pl-c-{slot:06d}")
        for slot in range(1, min(last, 16 if last >= 18 else 15) + 1)
    )
    return SlotPlan(
        regions=(Region("r", curve),),
        locations=(Location("l", "r", 1, last),),
        authored=authored,
        released=(),
    )


def test_generated_range_and_onboarding_count():
    rows = review_region_targets(plan())
    assert rows == (RegionTargetReview("r", 18, 15, 3, 0.25, 0.75, 0.5),)
    assert rows == review_region_targets(plan())
    with pytest.raises(FrozenInstanceError):
        rows[0].slots = 9


def test_onboarding_only_has_no_inferred_targets():
    assert review_region_targets(plan(15)) == (
        RegionTargetReview("r", 15, 15, 0, None, None, None),
    )


def test_invalid_plan_rejected():
    with pytest.raises(ValueError):
        review_region_targets(None)


def test_review_does_not_rebuild_reservation_maps_for_each_slot(monkeypatch):
    validated_plan = plan()

    def forbidden_lookup(_self, _slot):
        raise AssertionError("Regional QA must use its validated curve directly")

    monkeypatch.setattr(SlotPlan, "requirement", forbidden_lookup)
    assert review_region_targets(validated_plan) == (
        RegionTargetReview("r", 18, 15, 3, 0.25, 0.75, 0.5),
    )
