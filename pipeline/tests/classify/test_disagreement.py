"""Classification queue is strictly offline and never approves any tier."""

from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.classify.disagreement import (
    ClassificationDisagreement,
    compare_classification_passes,
)
from wordgame_pipeline.config import load_config

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")


def test_exact_ban_boundary_and_sorted_disagreements():
    first = {"TOK": "bonus_ok", "DOM": "level_ok", "KOT": "banned"}
    second = {"KOT": "level_ok", "DOM": "bonus_ok", "TOK": "bonus_ok"}
    result = compare_classification_passes(first, second, CONFIG)
    assert result == (
        ClassificationDisagreement("DOM", "level_ok", "bonus_ok", False),
        ClassificationDisagreement("KOT", "banned", "level_ok", True),
    )
    assert result == compare_classification_passes(
        dict(reversed(list(first.items()))), dict(reversed(list(second.items()))), CONFIG
    )
    with pytest.raises(FrozenInstanceError):
        result[0].word = "TOK"


def test_agreement_and_empty_are_no_approval():
    assert compare_classification_passes({}, {}, CONFIG) == ()
    assert compare_classification_passes({"KOT": "banned"}, {"KOT": "banned"}, CONFIG) == ()


def test_malformed_source_or_mismatched_keys_fail_closed():
    for a, b in (
        ({"KOT": "bonus_ok"}, {}),
        ({"kot": "bonus_ok"}, {"kot": "bonus_ok"}),
        ({"KOT": "unknown"}, {"KOT": "bonus_ok"}),
        ({"KOT": "bonus_ok"}, {"KOT": None}),
        ({1: "bonus_ok"}, {1: "bonus_ok"}),
    ):
        with pytest.raises(ValueError):
            compare_classification_passes(a, b, CONFIG)
    with pytest.raises(ValueError):
        compare_classification_passes({}, {}, None)
