"""Crossword geometry reviews use no production thresholds."""

import copy
from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.grid.quality import GridQuality, review_grid_quality


def test_crossed_portrait_grid_exact_geometry_and_fill():
    layout = (("KOT", 0, 0, "v"), ("TOK", 0, 2, "h"))
    before = copy.deepcopy(layout)
    report = review_grid_quality(layout, ("KOT", "TOK"), minimum_crossings=1)
    assert report == GridQuality(3, 3, 2, 5, 1, 5 / 9, True)
    assert layout == before
    assert review_grid_quality(layout[::-1], ("TOK", "KOT"), minimum_crossings=1) == report
    with pytest.raises(FrozenInstanceError):
        report.crossings = 9


def test_single_word_and_explicit_crossing_minimum():
    layout = (("KOT", 0, 0, "v"),)
    a = review_grid_quality(layout, ("KOT",), minimum_crossings=0)
    b = review_grid_quality(layout, ("KOT",), minimum_crossings=1)
    assert a.meets_minimum and not b.meets_minimum
    assert a.crossings == b.crossings == 0
    assert a.fill_ratio == 1


@pytest.mark.parametrize("minimum", [True, -1, 1.5, "1", None])
def test_invalid_threshold_rejected(minimum):
    with pytest.raises(ValueError):
        review_grid_quality((("KOT", 0, 0, "v"),), ("KOT",), minimum_crossings=minimum)


def test_invalid_and_unintended_placements_are_rejected():
    cases = (
        ((("KOT", 0, 0, "v"), ("TOK", 4, 0, "h")), ("KOT", "TOK")),
        ((("KOT", 0, 0, "v"), ("TOK", 0, 0, "h")), ("KOT", "TOK")),
        ((("KOT", 0, 0, "v"),), ("TOK",)),
        ((("KOT", 0, 0, "v"), ("KOT", 0, 0, "v")), ("KOT", "KOT")),
        ((("KOT", True, 0, "v"),), ("KOT",)),
        ((("KOT", 0, 0, "v"),), ()),
    )
    for layout, selected in cases:
        with pytest.raises(ValueError):
            review_grid_quality(layout, selected, minimum_crossings=0)


def test_mutable_container_inputs_rejected():
    with pytest.raises(ValueError):
        review_grid_quality([("KOT", 0, 0, "v")], ("KOT",), minimum_crossings=0)
    with pytest.raises(ValueError):
        review_grid_quality((("KOT", 0, 0, "v"),), ["KOT"], minimum_crossings=0)


def test_connected_consistent_letters_reject_accidental_horizontal_runs():
    layout = (("KOT", 0, 0, "v"), ("TOK", 1, 0, "v"))
    with pytest.raises(ValueError, match="Accidental adjacency or unintended word run"):
        review_grid_quality(layout, ("KOT", "TOK"), minimum_crossings=0)
