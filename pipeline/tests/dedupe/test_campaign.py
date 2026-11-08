"""Crossword diversity is checked independently from generated bonus words."""

from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.dedupe import DuplicatePolicy
from wordgame_pipeline.dedupe.campaign import (
    audit_campaign_diversity,
    require_campaign_diversity,
)

LANG = load_config(Path(__file__).parents[2], "pl")
POLICY = DuplicatePolicy(0.75, 100)


def level(slot, wheel, answers):
    return {
        "id": f"pl-c-{slot:06d}",
        "slot": slot,
        "letters": list(wheel),
        "words": [{"w": word} for word in answers],
        "bonus": ["NOT_A_CROSSWORD"],
    }


def test_clean_campaign_is_order_independent_and_keeps_bonus_out():
    levels = [level(2, "DOM", ["DOM"]), level(1, "KOT", ["KOT"])]
    seeds = {1: "KOT", 2: "DOM"}
    first = audit_campaign_diversity(levels, seeds, LANG, POLICY)
    assert first.slots == 2 and first.conflicts == ()
    assert audit_campaign_diversity(levels[::-1], seeds, LANG, POLICY) == first
    require_campaign_diversity(first)


def test_reused_wheel_is_blocked_even_when_answer_spacing_is_100():
    levels = [
        level(i, "KOT" if i in (1, 101) else "DOM", ["KOT"] if i in (1, 101) else ["DOM"])
        for i in range(1, 102)
    ]
    # Reusing DOM at every slot also violates the explicit wheel-multiset rule.
    seeds = {i: ("KOT" if i in (1, 101) else "DOM") for i in range(1, 102)}
    audit = audit_campaign_diversity(levels, seeds, LANG, POLICY)
    assert any("letter_multiset" in item.reasons for item in audit.conflicts)
    with pytest.raises(ValueError, match="letter_multiset"):
        require_campaign_diversity(audit)


def test_same_selected_word_inside_100_slots_is_detected():
    levels = [level(1, "KOT", ["KOT"]), level(2, "KOTA", ["KOT", "KOTA"])]
    result = audit_campaign_diversity(levels, {1: "KOT", 2: "KOT"}, LANG, POLICY)
    assert "word_spacing" in result.conflicts[0].reasons
    assert "seed_spacing" in result.conflicts[0].reasons


@pytest.mark.parametrize("seed", [{}, {1: "DOM"}, {1: "KOT", 2: "DOM"}])
def test_missing_wrong_or_extra_seed_rejected(seed):
    with pytest.raises(ValueError):
        audit_campaign_diversity([level(1, "KOT", ["KOT"])], seed, LANG, POLICY)


def test_duplicate_slots_and_incorrect_identity_rejected():
    a = level(1, "KOT", ["KOT"])
    with pytest.raises(ValueError):
        audit_campaign_diversity([a, a], {1: "KOT"}, LANG, POLICY)
    a["id"] = "wrong"
    with pytest.raises(ValueError):
        audit_campaign_diversity([a], {1: "KOT"}, LANG, POLICY)
