"""Hotspot priority counts unique peers even for multiple conflict reasons."""

from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.dedupe import DuplicatePolicy
from wordgame_pipeline.dedupe.hotspots import rank_duplicate_hotspots

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")
POLICY = DuplicatePolicy(0.5, 100)


def record(identity, slot, letters, word):
    return dict(
        id=identity, pool="campaign", slot=slot,
        letters=list(letters), words=[word], seed_word=word,
    )


def test_peer_count_not_reason_count_and_deterministic_ties():
    rows = [
        record("a", 1, "KOT", "KOT"),
        record("b", 2, "TOK", "KOT"),
        record("c", 3, "KOTA", "KOT"),
        record("z", 4, "DOM", "DOM"),
    ]
    first = rank_duplicate_hotspots(rows, POLICY, CONFIG)
    assert tuple((r.identity, r.conflicting_peers) for r in first) == (
        ("a", 2), ("b", 2), ("c", 2)
    )
    assert first[0].peers == ("b", "c")
    assert "word_spacing" in first[0].reasons
    assert first == rank_duplicate_hotspots(rows[::-1], POLICY, CONFIG)


def test_no_conflicts_and_invalid_inputs():
    assert rank_duplicate_hotspots([], POLICY, CONFIG) == ()
    assert rank_duplicate_hotspots([record("a", 1, "KOT", "KOT")], POLICY, CONFIG) == ()
    with pytest.raises(ValueError):
        rank_duplicate_hotspots([record("a", 1, "KOT", "KOT")] * 2, POLICY, CONFIG)
    with pytest.raises(ValueError):
        rank_duplicate_hotspots([], None, CONFIG)
