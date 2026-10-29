"""Score drift is review evidence, not approved production calibration."""

import copy
from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.scoring.drift import ScoreShift, review_score_drift
from wordgame_pipeline.scoring.features import FEATURE_NAMES
from wordgame_pipeline.scoring.model import ScoringConfig


def config(active):
    return ScoringConfig.from_dict(
        {
            "schema_version": 1,
            "features": {
                name: {
                    "weight": int(name == active),
                    "minimum": 0,
                    "maximum": 4 if name == "word_count" else 8,
                    "direction": "higher",
                }
                for name in FEATURE_NAMES
            },
        }
    )


def features(letter_count, word_count):
    return {
        name: (
            letter_count if name == "letter_count" else word_count if name == "word_count" else 0
        )
        for name in FEATURE_NAMES
    }


def test_signed_ranked_shifts_and_strict_cutoff():
    entries = {
        "b": features(4, 4),
        "a": features(8, 1),
        "c": features(4, 2),
    }
    old, new = config("letter_count"), config("word_count")
    result = review_score_drift(entries, old, new, minimum_delta=0.5)
    assert result == (ScoreShift("a", 1, 0.25, -0.75),)
    all_shifts = review_score_drift(entries, old, new, minimum_delta=0)
    assert all_shifts == (
        ScoreShift("a", 1, 0.25, -0.75),
        ScoreShift("b", 0.5, 1, 0.5),
    )
    with pytest.raises(FrozenInstanceError):
        result[0].delta = 0


def test_order_independent_nonmutation_and_no_drift():
    entries = {"a": features(4, 2), "b": features(8, 1)}
    before = copy.deepcopy(entries)
    old, new = config("letter_count"), config("word_count")
    first = review_score_drift(entries, old, new, minimum_delta=0)
    second = review_score_drift(dict(reversed(list(entries.items()))), old, new, minimum_delta=0)
    assert first == second and entries == before
    assert review_score_drift(entries, old, old, minimum_delta=0) == ()


@pytest.mark.parametrize("cutoff", [True, -1, 1.1, "0.1", None, float("nan"), 10**400])
def test_invalid_threshold_rejected(cutoff):
    with pytest.raises(ValueError):
        review_score_drift({}, config("letter_count"), config("word_count"), minimum_delta=cutoff)


def test_invalid_records_or_configuration_rejected_even_when_not_flagged():
    old, new = config("letter_count"), config("word_count")
    for entries in (
        {"": features(4, 2)},
        {" a": features(4, 2)},
        {"a\x00": features(4, 2)},
        {1: features(4, 2)},
        {"a": features(4, 2) | {"other": 1}},
        {"a": features(4, 2) | {"word_count": True}},
        {"a": features(4, 2) | {"word_count": float("inf")}},
        {"a": None},
    ):
        with pytest.raises(ValueError):
            review_score_drift(entries, old, new, minimum_delta=1)
    for bad in (None, {}, []):
        with pytest.raises(ValueError):
            review_score_drift({"a": features(4, 2)}, bad, new, minimum_delta=0)
    assert review_score_drift({}, old, new, minimum_delta=0) == ()
