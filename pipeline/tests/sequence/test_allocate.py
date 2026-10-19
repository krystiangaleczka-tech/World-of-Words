"""Fixture candidates use existing words; this never regenerates shipped content."""

import copy
import json
from dataclasses import FrozenInstanceError, replace
from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.dedupe import DuplicatePolicy
from wordgame_pipeline.sequence import CurveConfig
from wordgame_pipeline.sequence.allocate import AllocationError, ScoredCandidate, allocate
from wordgame_pipeline.sequence.slots import Location, Region, Reservation, SlotPlan

ROOT = Path(__file__).resolve().parents[2]
LANGUAGE = load_config(ROOT, "pl")
POLICY = DuplicatePolicy(1, 100)


def candidates(n=20):
    path = next((ROOT.parent / "game/content/pl/packs").glob("*.json"))
    levels = json.loads(path.read_bytes())["levels"][:n]
    # Explicit fixture seed choice only; production preview requires seed evidence.
    return tuple(
        ScoredCandidate(
            f"c{i}",
            tuple(level["letters"]),
            tuple(p["w"] for p in level["words"]),
            level["words"][0]["w"],
            i / 100,
            i <= 15,
            False,
        )
        for i, level in enumerate(levels, 1)
    )


def plan(total=17, extra=(), landmarks=(), released=3):
    curve = CurveConfig(1, total, 0.16, 0, 5, 0, 0.2, 0.1, landmarks)
    return SlotPlan(
        (Region("r", curve),),
        (Location("l", "r", 1, total),),
        tuple(Reservation(s, f"c{s}") for s in [*range(1, 16), *extra]),
        tuple(Reservation(s, f"c{s}") for s in range(1, released + 1)),
    )


def test_nearest_tie_order_fixed_modes_deviations_and_immutable_result():
    pool = candidates()
    result = allocate(plan(), pool, POLICY, LANGUAGE)
    assert [a.candidate.id for a in result.assignments] == [f"c{i}" for i in range(1, 18)]
    assert result.unused == ("c18", "c19", "c20")
    assert result.assignments[0].mode == "released" and result.assignments[0].deviation is None
    assert result.assignments[3].mode == "authored" and result.assignments[15].mode == "nearest"
    assert allocate(plan(), tuple(reversed(pool)), POLICY, LANGUAGE) == result
    tied = tuple(replace(c, difficulty=0.5) if not c.authored else c for c in pool)
    assert (
        allocate(plan(), tuple(reversed(tied)), POLICY, LANGUAGE).assignments[15].candidate.id
        == "c16"
    )
    with pytest.raises(FrozenInstanceError):
        result.unused = ()
    with pytest.raises(FrozenInstanceError):
        result.assignments[15].candidate.id = "x"


def test_future_authored_id_is_reserved_and_unreserved_authored_is_not_moved():
    pool = list(candidates())
    pool[16] = replace(pool[16], authored=True, difficulty=0.16)
    result = allocate(plan(extra=(17,)), pool, POLICY, LANGUAGE)
    assert result.assignments[16].candidate.id == "c17"
    assert result.assignments[15].candidate.id == "c16"
    pool[15] = replace(pool[15], authored=True)
    result = allocate(plan(total=16), pool, POLICY, LANGUAGE)
    assert result.assignments[15].candidate.id not in {"c16", "c17"}
    assert result.assignments[15].rejected[0].reason == "unreserved_authored"


def test_future_fixed_words_block_nearer_candidate_before_that_slot():
    pool = list(candidates())
    future = replace(pool[17], authored=True)
    pool[17] = future
    pool[15] = replace(future, id="c16", authored=False, difficulty=0.16)
    result = allocate(plan(total=18, extra=(18,)), pool, POLICY, LANGUAGE)
    selected = result.assignments[15]
    assert selected.candidate.id != "c16"
    rejection = next(r for r in selected.rejected if r.candidate_id == "c16")
    assert any("c18" in (c.left_id, c.right_id) for c in rejection.conflicts)
    assert result.assignments[17].candidate.id == "c18"


def test_landmark_authorship_and_fixed_compatibility():
    value, pool = plan(total=19, extra=(18,), landmarks=(18,)), list(candidates())
    with pytest.raises(AllocationError, match="fixed_incompatible"):
        allocate(value, pool, POLICY, LANGUAGE)
    pool[17] = replace(pool[17], authored=True, landmark=True)
    result = allocate(value, pool, POLICY, LANGUAGE)
    assert result.assignments[17].candidate.landmark
    pool[0] = replace(pool[0], authored=False)
    with pytest.raises(AllocationError, match="fixed_incompatible"):
        allocate(value, pool, POLICY, LANGUAGE)


def test_fixed_conflict_missing_pool_shortage_and_huge_plan_fail_closed():
    pool = list(candidates())
    pool[1] = replace(pool[0], id="c2")
    with pytest.raises(AllocationError) as error:
        allocate(plan(), pool, POLICY, LANGUAGE)
    assert error.value.code == "fixed_conflict" and error.value.conflicts
    with pytest.raises(AllocationError, match="fixed_missing"):
        allocate(plan(), candidates()[1:], POLICY, LANGUAGE)
    with pytest.raises(AllocationError, match="pool_too_small"):
        allocate(plan(total=2**53 - 1), candidates(), POLICY, LANGUAGE)


def test_greedy_block_reports_exact_slot_and_conflicts_without_partial_or_mutation():
    pool = list(candidates(16))
    pool[15] = replace(pool[0], id="c16", authored=False)
    before = copy.deepcopy(pool)
    with pytest.raises(AllocationError) as error:
        allocate(plan(total=16), pool, POLICY, LANGUAGE)
    assert error.value.code == "greedy_blocked" and error.value.slot == 16
    assert error.value.blocked[0].candidate_id == "c16" and error.value.blocked[0].conflicts
    assert not hasattr(error.value, "assignments") and pool == before


@pytest.mark.parametrize(
    "update",
    [
        dict(id=""),
        dict(id="x\x7f"),
        dict(difficulty=True),
        dict(difficulty=float("nan")),
        dict(difficulty=1.1),
        dict(letters=[]),
        dict(words=[]),
        dict(seed_word="missing"),
        dict(authored=1),
        dict(authored=False, landmark=True),
    ],
)
def test_invalid_candidate_constructors(update):
    with pytest.raises(ValueError):
        replace(candidates()[0], **update)


def test_language_record_validation_and_malformed_call_shapes():
    pool = list(candidates())
    pool[-1] = replace(pool[-1], letters=("Q", "O", "T"))
    with pytest.raises(ValueError):
        allocate(plan(), pool, POLICY, LANGUAGE)
    with pytest.raises(ValueError):
        allocate(plan(), candidates() + candidates()[:1], POLICY, LANGUAGE)
    with pytest.raises(ValueError):
        allocate(None, candidates(), POLICY, LANGUAGE)
    with pytest.raises(ValueError):
        allocate(plan(), iter(candidates()), POLICY, LANGUAGE)
    with pytest.raises(ValueError):
        allocate(plan(), candidates(), POLICY, None)
    with pytest.raises(ValueError):
        allocate(plan(), candidates(), None, LANGUAGE)
    item = candidates()[0]
    item.record(1)["letters"].clear()
    assert item.letters


def test_released_nonauthored_reservation_rejects_authored_candidate():
    value, pool = plan(released=16), list(candidates())
    pool[15] = replace(pool[15], authored=True)
    with pytest.raises(AllocationError) as error:
        allocate(value, pool, POLICY, LANGUAGE)
    assert error.value.code == "fixed_incompatible" and error.value.slot == 16
