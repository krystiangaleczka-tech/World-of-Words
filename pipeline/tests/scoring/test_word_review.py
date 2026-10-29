"""Pure exact-form review flags; missing is never mistaken for ARF zero."""

import copy
from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.scoring.word_review import WordReviewFlag, flag_word_evidence


def level(slot, words):
    return {
        "id": f"pl-c-{slot:06d}",
        "slot": slot,
        "words": [{"w": word} for word in words],
    }


def test_unknown_zero_known_and_cutoff_boundary():
    levels = [level(1, ["KOT", "TOK"]), level(2, ["DOM"])]
    evidence = {"KOT": None, "TOK": 0, "DOM": 3}
    result = flag_word_evidence(levels, evidence, low_arf=0, limit=10)
    assert result == (
        WordReviewFlag(1, "KOT", "missing_arf", None),
        WordReviewFlag(1, "TOK", "low_arf", 0),
    )
    result = flag_word_evidence(levels, evidence, low_arf=3, limit=2)
    assert len(result) == 2
    assert result[0].reason == "missing_arf"
    assert flag_word_evidence(levels, evidence, low_arf=3, limit=3)[-1] == (
        WordReviewFlag(2, "DOM", "low_arf", 3)
    )
    with pytest.raises(FrozenInstanceError):
        result[0].slot = 100


def test_reordering_limits_and_nonmutation():
    levels = [level(1, ["KOT", "TOK"]), level(2, ["DOM"])]
    evidence = {"DOM": 0.5, "TOK": 0, "KOT": None}
    before = copy.deepcopy((levels, evidence))
    first = flag_word_evidence(levels, evidence, low_arf=1, limit=10)
    second = flag_word_evidence(levels[::-1], dict(reversed(list(evidence.items()))),
                                low_arf=1, limit=10)
    assert first == second
    assert flag_word_evidence(levels, evidence, low_arf=1, limit=1) == first[:1]
    assert (levels, evidence) == before


def test_unflagged_known_evidence_returns_empty():
    levels = [level(1, ["KOT"])]
    assert flag_word_evidence(levels, {"KOT": 10}, low_arf=1, limit=10) == ()


@pytest.mark.parametrize(
    "bad",
    [True, -1, float("nan"), float("inf"), "1", 10**400],
)
def test_invalid_explicit_threshold_fails(bad):
    with pytest.raises(ValueError):
        flag_word_evidence([level(1, ["KOT"])], {"KOT": 1}, low_arf=bad, limit=1)


@pytest.mark.parametrize(
    "bad",
    [True, -1, float("nan"), float("inf"), "1", 10**400],
)
def test_invalid_arf_fails_before_returning_flags(bad):
    with pytest.raises(ValueError):
        flag_word_evidence(
            [level(1, ["KOT", "TOK"])],
            {"KOT": None, "TOK": bad},
            low_arf=1,
            limit=10,
        )


def test_bad_slots_sources_seed_guesses_and_shapes_rejected():
    valid = level(1, ["KOT"])
    for levels, evidence in (
        ([], {}),
        ([level(2, ["KOT"])], {"KOT": None}),
        ([valid, valid], {"KOT": None}),
        ([valid, level(3, ["TOK"])], {"KOT": None, "TOK": None}),
        ([valid | {"id": "wrong"}], {"KOT": None}),
        ([valid | {"slot": True}], {"KOT": None}),
        ([valid | {"words": []}], {"KOT": None}),
        ([level(1, ["KOT", "KOT"])], {"KOT": None}),
        ([level(1, ["kot"])], {"kot": None}),
        ([valid], {}),
        ([valid], {"KOT": None, "TOK": 1}),
    ):
        with pytest.raises(ValueError):
            flag_word_evidence(levels, evidence, low_arf=1, limit=1)
    for invalid_limit in (0, -1, True, 2.0, None):
        with pytest.raises(ValueError):
            flag_word_evidence([valid], {"KOT": None}, low_arf=1, limit=invalid_limit)
