"""Observed ranges are evidence, not production score thresholds."""

from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.scoring.features import FEATURE_NAMES
from wordgame_pipeline.scoring.model import ScoringConfig
from wordgame_pipeline.scoring.ranges import FeatureRange, review_feature_ranges


def config():
    return ScoringConfig.from_dict(
        {
            "schema_version": 1,
            "features": {
                name: {
                    "weight": int(name == "letter_count"),
                    "minimum": 0,
                    "maximum": 10,
                    "direction": "higher",
                }
                for name in FEATURE_NAMES
            },
        }
    )


def entry(letters):
    return {name: letters if name == "letter_count" else 0 for name in FEATURE_NAMES}


def test_ranges_are_exact_ordered_and_nonmutating():
    candidates = {"b": entry(6), "a": entry(2)}
    rows = review_feature_ranges(candidates, config())
    assert len(rows) == len(FEATURE_NAMES)
    assert rows[0] == FeatureRange("letter_count", 2, 6, 4)
    assert all(row.minimum == 0 for row in rows[1:])
    assert rows == review_feature_ranges(dict(reversed(list(candidates.items()))), config())
    assert candidates["a"]["letter_count"] == 2
    with pytest.raises(FrozenInstanceError):
        rows[0].mean = 99


@pytest.mark.parametrize(
    "bad",
    [
        None,
        {},
        [],
        {"": entry(2)},
        {1: entry(2)},
        {" a": entry(2)},
        {"a": {}},
        {"a": entry(2) | {"letter_count": True}},
        {"a": entry(2) | {"letter_count": float("inf")}},
    ],
)
def test_invalid_evidence_rejected(bad):
    with pytest.raises(ValueError):
        review_feature_ranges(bad, config())


def test_missing_config_rejected():
    with pytest.raises(ValueError):
        review_feature_ranges({"a": entry(2)}, None)
