"""Explanatory feature deltas always derive from real scoring outputs."""

from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.scoring.features import FEATURE_NAMES
from wordgame_pipeline.scoring.feature_shifts import review_feature_shifts
from wordgame_pipeline.scoring.model import ScoringConfig


def config(active):
    return ScoringConfig.from_dict(
        {
            "schema_version": 1,
            "features": {
                name: {
                    "weight": int(name == active),
                    "minimum": 0,
                    "maximum": 8,
                    "direction": "higher",
                }
                for name in FEATURE_NAMES
            },
        }
    )


def raw():
    return {
        name: 8 if name == "letter_count" else 4 if name == "word_count" else 0
        for name in FEATURE_NAMES
    }


def test_signed_contribution_explanation_and_tie_order():
    changes = review_feature_shifts(
        raw(), config("letter_count"), config("word_count"), minimum_delta=0
    )
    assert [(row.feature, row.delta) for row in changes] == [
        ("letter_count", -1),
        ("word_count", 0.5),
    ]
    assert review_feature_shifts(
        raw(), config("letter_count"), config("word_count"), minimum_delta=0.5
    ) == (changes[0],)
    assert (
        review_feature_shifts(
            raw(), config("letter_count"), config("letter_count"), minimum_delta=0
        )
        == ()
    )
    with pytest.raises(FrozenInstanceError):
        changes[0].delta = 0


@pytest.mark.parametrize("cutoff", [True, None, -1, 1.1, float("nan"), "0.1", 10**400])
def test_invalid_cutoff_rejected(cutoff):
    with pytest.raises(ValueError):
        review_feature_shifts(
            raw(), config("letter_count"), config("word_count"), minimum_delta=cutoff
        )


def test_invalid_features_are_rejected_without_partial_report():
    features = raw()
    for value in (True, -1, float("inf")):
        bad = features | {"word_count": value}
        with pytest.raises(ValueError):
            review_feature_shifts(
                bad, config("letter_count"), config("word_count"), minimum_delta=0
            )
    with pytest.raises(ValueError):
        review_feature_shifts(features, None, config("word_count"), minimum_delta=0)
