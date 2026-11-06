"""Crossing positions are exact and order independent."""

import pytest
from wordgame_pipeline.grid.intersections import crossing_positions


def test_single_intersection_and_input_reorder():
    layout = (("KOT", 0, 0, "v"), ("TOK", 0, 2, "h"))
    assert crossing_positions(layout, ("KOT", "TOK")) == ((0, 2),)
    assert crossing_positions(layout[::-1], ("TOK", "KOT")) == ((0, 2),)
    assert layout[0] == ("KOT", 0, 0, "v")


def test_single_vertical_word_has_no_crossings():
    assert crossing_positions((("KOT", 0, 0, "v"),), ("KOT",)) == ()


def test_invalid_geometry_is_not_silently_accepted():
    for layout, words in (
        ((("KOT", 0, 0, "v"), ("TOK", 5, 0, "h")), ("KOT", "TOK")),
        ((("KOT", 0, 0, "v"),), ("TOK",)),
        ((("KOT", True, 0, "v"),), ("KOT",)),
        ((), ()),
        ([("KOT", 0, 0, "v")], ("KOT",)),
        ((("KOT", 0, 0, "v"),), ["KOT"]),
    ):
        with pytest.raises(ValueError):
            crossing_positions(layout, words)
