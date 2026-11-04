"""Tier changes are diffs, not automatic approvals or overridden outputs."""

from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.tiers.distribution import (
    TierChange,
    compare_tier_distributions,
)

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")


def rows(**pairs):
    return [{"word": word, "tier": tier} for word, tier in pairs.items()]


def test_exact_counts_and_changed_words():
    a = rows(DOM="level_ok", KOT="bonus_ok", TOK="banned")
    b = rows(TOK="bonus_ok", KOT="level_ok", DOM="level_ok")
    diff = compare_tier_distributions(a, b, CONFIG)
    assert diff.counts_before == (("level_ok", 1), ("bonus_ok", 1), ("banned", 1))
    assert diff.counts_after == (("level_ok", 2), ("bonus_ok", 1), ("banned", 0))
    assert diff.changes == (
        TierChange("KOT", "bonus_ok", "level_ok"),
        TierChange("TOK", "banned", "bonus_ok"),
    )
    assert diff == compare_tier_distributions(a[::-1], b[::-1], CONFIG)
    with pytest.raises(FrozenInstanceError):
        diff.changes[0].word = "NOT"


def test_empty_and_unchanged():
    assert compare_tier_distributions([], [], CONFIG).changes == ()
    records = rows(DOM="level_ok")
    assert compare_tier_distributions(records, records, CONFIG).changes == ()


def test_missing_words_and_duplicate_or_invalid_tiers_fail():
    a = rows(DOM="level_ok")
    for proposed in (
        [],
        rows(DOM="incorrect"),
        [{"word": "dom", "tier": "bonus_ok"}],
        rows(DOM="bonus_ok") * 2,
        [{"word": "KOT", "tier": "bonus_ok"}],
    ):
        with pytest.raises(ValueError):
            compare_tier_distributions(a, proposed, CONFIG)
    with pytest.raises(ValueError):
        compare_tier_distributions(a, a, None)
