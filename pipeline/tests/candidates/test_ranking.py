"""Ranking reviews eligible wheels without making selections."""

from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.candidates.core import WordIndex
from wordgame_pipeline.candidates.ranking import WheelOpportunity, rank_candidate_wheels
from wordgame_pipeline.config import load_config

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")


def index():
    return WordIndex(
        [
            {"word": "DOM", "tier": "level_ok"},
            {"word": "KOT", "tier": "level_ok"},
            {"word": "TOK", "tier": "level_ok"},
        ],
        CONFIG,
    )


def test_exact_ranking_limit_and_fresh_result():
    idx = index()
    rows = rank_candidate_wheels(idx, minimum_words=1, limit=2)
    assert rows == (
        WheelOpportunity("pl-auto-KOT", 3, 2, 2, 0),
        WheelOpportunity("pl-auto-DMO", 3, 1, 1, 0),
    )
    assert rank_candidate_wheels(idx, minimum_words=2, limit=10) == rows[:1]
    assert rank_candidate_wheels(idx, minimum_words=1, limit=1) == rows[:1]
    assert rank_candidate_wheels(idx, minimum_words=1, limit=2) == rows
    with pytest.raises(FrozenInstanceError):
        rows[0].letters = 4


@pytest.mark.parametrize("minimum,limit", [(0, 1), (1, 0), (True, 1), (1, 1.5), ("1", 1)])
def test_bad_settings_rejected(minimum, limit):
    with pytest.raises(ValueError):
        rank_candidate_wheels(index(), minimum_words=minimum, limit=limit)


def test_no_eligible_and_bad_index():
    assert rank_candidate_wheels(index(), minimum_words=3, limit=1) == ()
    with pytest.raises(ValueError):
        rank_candidate_wheels(None, minimum_words=1, limit=1)
