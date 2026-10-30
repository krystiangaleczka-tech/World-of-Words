"""Explicit region/location sequence binding preserves authored onboarding slots."""

import json
from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.dedupe import DuplicatePolicy
from wordgame_pipeline.sequence.allocate import AllocationError, ScoredCandidate
from wordgame_pipeline.sequence.campaign import sequence_campaign
from wordgame_pipeline.sequence.curve import CurveConfig
from wordgame_pipeline.sequence.slots import Location, Region, Reservation, SlotPlan

ROOT = Path(__file__).parents[2]
LANGUAGE = load_config(ROOT, "pl")
POLICY = DuplicatePolicy(1, 100)


def fixtures():
    path = next((ROOT.parent / "game/content/pl/packs").glob("*.json"))
    levels = json.loads(path.read_bytes())["levels"][:17]
    candidates = tuple(
        ScoredCandidate(
            f"c{index}",
            tuple(level["letters"]),
            tuple(placement["w"] for placement in level["words"]),
            level["words"][0]["w"],
            index / 100,
            index <= 15,
            False,
        )
        for index, level in enumerate(levels, 1)
    )
    plan = SlotPlan(
        (Region("r1", CurveConfig(1, 16, 0.16, 0, 5, 0, 0.2, 0.1, ())),),
        (Location("l1", "r1", 1, 8), Location("l2", "r1", 9, 16)),
        tuple(Reservation(i, f"c{i}") for i in range(1, 16)),
        (),
    )
    return plan, candidates


def test_allocation_maps_every_slot_to_exact_location_and_curve_kind():
    plan, candidates = fixtures()
    first = sequence_campaign(plan, candidates, POLICY, LANGUAGE)
    assert len(first) == 16
    assert tuple(row.slot for row in first) == tuple(range(1, 17))
    assert first[0].curve_kind == "onboarding"
    assert first[0].mode == "authored"
    assert first[0].curve_target is None
    assert first[7].location_id == "l1" and first[8].location_id == "l2"
    assert first[15].mode == "nearest"
    assert first[15].candidate_id == "c16"
    assert first[15].region_id == "r1"
    assert sequence_campaign(plan, candidates[::-1], POLICY, LANGUAGE) == first


def test_missing_authored_candidate_is_rejected_without_partial_result():
    plan, candidates = fixtures()
    with pytest.raises(AllocationError, match="fixed_missing"):
        sequence_campaign(plan, candidates[1:], POLICY, LANGUAGE)


def test_invalid_duplicate_candidates_rejected():
    plan, candidates = fixtures()
    with pytest.raises(ValueError):
        sequence_campaign(plan, candidates + candidates[:1], POLICY, LANGUAGE)
