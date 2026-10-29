"""Conflict burden is ranked without changing source records."""

from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.dedupe import DuplicatePolicy
from wordgame_pipeline.dedupe.impact import ConflictImpact, rank_conflict_impact

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")
POLICY = DuplicatePolicy(1, 100)


def record(identity, slot, letters, word):
    return {
        "id": identity, "pool": "campaign", "slot": slot,
        "letters": list(letters), "words": [word], "seed_word": word,
    }


def test_rank_and_unique_reasons_and_immutable_rows():
    rows = [
        record("a", 1, "KOT", "KOT"),
        record("b", 2, "TOK", "KOT"),
        record("c", 3, "KOTA", "KOT"),
    ]
    result = rank_conflict_impact(rows, POLICY, CONFIG)
    assert result == (
        ConflictImpact("a", 2, ("letter_multiset", "word_spacing", "seed_spacing")),
        ConflictImpact("b", 2, ("letter_multiset", "word_spacing", "seed_spacing")),
        ConflictImpact("c", 2, ("word_spacing", "seed_spacing")),
    )
    assert rank_conflict_impact(rows[::-1], POLICY, CONFIG) == result
    with pytest.raises(FrozenInstanceError):
        result[0].candidate_id = "x"


def test_no_conflicts_and_invalid_source():
    a = record("a", 1, "KOT", "KOT")
    b = record("b", 2, "DOM", "DOM")
    assert rank_conflict_impact([a, b], POLICY, CONFIG) == ()
    with pytest.raises(ValueError):
        rank_conflict_impact([a, a], POLICY, CONFIG)
    with pytest.raises(ValueError):
        rank_conflict_impact([a], None, CONFIG)
