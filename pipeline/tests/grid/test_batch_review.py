"""Batch QA reuses canonical geometry validation."""

import copy
from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.grid.batch_review import GridReviewRow, review_grid_batch


def cases():
    return {
        "one": ((("KOT", 0, 0, "v"),), ("KOT",)),
        "cross": (
            (("KOT", 0, 0, "v"), ("TOK", 0, 2, "h")),
            ("KOT", "TOK"),
        ),
    }


def test_rank_below_threshold_first_and_no_mutations():
    values = cases()
    original = copy.deepcopy(values)
    rows = review_grid_batch(values, minimum_crossings=1)
    assert tuple(row.candidate_id for row in rows) == ("one", "cross")
    assert rows[0].quality.crossings == 0
    assert rows[0].quality.meets_minimum is False
    assert rows[1].quality.crossings == 1
    assert rows[1].quality.meets_minimum is True
    assert rows == review_grid_batch(dict(reversed(list(values.items()))), minimum_crossings=1)
    assert values == original
    with pytest.raises(FrozenInstanceError):
        rows[0].candidate_id = "other"
    assert isinstance(rows[0], GridReviewRow)


@pytest.mark.parametrize(
    "values,threshold",
    [
        (None, 0),
        ({}, True),
        ({}, -1),
        ({"one": cases()["one"]}, True),
        ({"one": cases()["one"]}, -1),
        ({"one": cases()["one"]}, 1.0),
        ({"": cases()["one"]}, 0),
        ({" a": cases()["one"]}, 0),
        ({"a": None}, 0),
        ({"a": cases()["one"][:1]}, 0),
        ({"a": ((("KOT", 0, 0, "v"),), ("DOM",))}, 0),
    ],
)
def test_invalid_batch_rejected(values, threshold):
    with pytest.raises(ValueError):
        review_grid_batch(values, minimum_crossings=threshold)


def test_empty_explicit_batch():
    assert review_grid_batch({}, minimum_crossings=0) == ()
