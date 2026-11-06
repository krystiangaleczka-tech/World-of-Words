"""Changes are reported, never applied to reviewed tiers."""

from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.tiers.transitions import (
    TierTransition,
    TierTransitionReport,
    compare_tiers,
)


def test_two_transitions_are_stable_and_distinct():
    before = {"DOM": "level_ok", "KOT": "bonus_ok", "TOK": "banned"}
    after = {"TOK": "bonus_ok", "KOT": "level_ok", "DOM": "level_ok"}
    expected = TierTransitionReport(
        3,
        2,
        (
            TierTransition("banned", "bonus_ok", 1),
            TierTransition("bonus_ok", "level_ok", 1),
        ),
    )
    assert compare_tiers(before, after) == expected
    assert before["TOK"] == "banned"
    assert compare_tiers(dict(reversed(list(before.items()))), after) == expected
    with pytest.raises(FrozenInstanceError):
        expected.changed = 9


def test_no_changes_and_empty():
    assert compare_tiers({}, {}) == TierTransitionReport(0, 0, ())
    assert compare_tiers({"KOT": "level_ok"}, {"KOT": "level_ok"}).changed == 0


@pytest.mark.parametrize(
    "before,after",
    [
        (None, {}),
        ({"KOT": "bonus_ok"}, {}),
        ({"KOT": "unknown"}, {"KOT": "bonus_ok"}),
        ({"KOT": "bonus_ok"}, {"KOT": True}),
        ({1: "bonus_ok"}, {1: "bonus_ok"}),
        ({"": "bonus_ok"}, {"": "bonus_ok"}),
    ],
)
def test_invalid_classifications_rejected(before, after):
    with pytest.raises(ValueError):
        compare_tiers(before, after)
