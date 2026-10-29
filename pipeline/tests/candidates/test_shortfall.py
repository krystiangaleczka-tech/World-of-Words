"""Candidate shortage ordering is stable and never manufactures words."""

import pytest
from pathlib import Path
from wordgame_pipeline.candidates.core import WordIndex
from wordgame_pipeline.candidates.shortfall import CandidateShortfall, rank_candidate_shortfalls
from wordgame_pipeline.config import load_config

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")


def index():
    return WordIndex(
        [{"word": w, "tier": "level_ok"} for w in ("DOM", "KOT", "TOK")],
        CONFIG,
    )


def test_ranked_shortages_and_anagram_seed_dedup():
    result = rank_candidate_shortfalls(index(), required_words=3)
    assert result == (
        CandidateShortfall("pl-auto-DMO", 1, 2, 3, 1),
        CandidateShortfall("pl-auto-KOT", 2, 1, 3, 2),
    )
    assert rank_candidate_shortfalls(index(), required_words=2) == (
        CandidateShortfall("pl-auto-DMO", 1, 1, 3, 1),
    )
    assert rank_candidate_shortfalls(index(), required_words=1) == ()


def test_fresh_stable_empty_and_input_integrity():
    idx = index()
    before = idx.automatic()
    first = rank_candidate_shortfalls(idx, required_words=3)
    second = rank_candidate_shortfalls(idx, required_words=3)
    assert first == second and first is not second
    assert idx.automatic() == before
    assert rank_candidate_shortfalls(WordIndex([], CONFIG), required_words=1) == ()


@pytest.mark.parametrize("value", [None, 0, -1, True, 1.2, "3"])
def test_invalid_explicit_target_rejected(value):
    with pytest.raises(ValueError):
        rank_candidate_shortfalls(index(), required_words=value)


def test_invalid_index_rejected():
    with pytest.raises(ValueError):
        rank_candidate_shortfalls(None, required_words=2)
