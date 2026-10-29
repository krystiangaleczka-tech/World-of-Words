"""Grid alternatives are validated by the actual geometry contract."""

from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.grid.ranking import rank_layouts

CROSSED = (("KOT", 0, 0, "v"), ("TOK", 0, 2, "h"))
ROTATED = (("KOT", 0, 0, "h"), ("TOK", 2, 0, "v"))


def test_equal_valid_alternatives_break_ties_by_id():
    result = rank_layouts(
        {"z": CROSSED, "a": ROTATED}, ("KOT", "TOK"), minimum_crossings=1
    )
    assert tuple(row.identity for row in result) == ("a", "z")
    assert all(row.quality.crossings == 1 and row.quality.meets_minimum for row in result)
    assert result == rank_layouts(
        {"a": ROTATED, "z": CROSSED}, ("TOK", "KOT"), minimum_crossings=1
    )
    with pytest.raises(FrozenInstanceError):
        result[0].identity = "oops"


def test_threshold_only_changes_quality_not_layout():
    first = rank_layouts({"a": CROSSED}, ("KOT", "TOK"), minimum_crossings=1)
    second = rank_layouts({"a": CROSSED}, ("KOT", "TOK"), minimum_crossings=2)
    assert first[0].quality.meets_minimum is True
    assert second[0].quality.meets_minimum is False
    assert first[0].quality.crossings == second[0].quality.crossings == 1


def test_invalid_alternatives_rejected_without_partial_rank():
    for cases in (
        {},
        {"a": CROSSED, "z": (("KOT", 0, 0, "h"), ("TOK", 0, 0, "v"))},
        {"a": (("KOT", 0, 0, "v"),)},
        {" ": CROSSED},
    ):
        with pytest.raises(ValueError):
            rank_layouts(cases, ("KOT", "TOK"), minimum_crossings=0)
    with pytest.raises(ValueError):
        rank_layouts({"a": CROSSED}, ("KOT", "TOK"), minimum_crossings=True)
