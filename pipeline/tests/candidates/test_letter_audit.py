"""Wheel exposure counts are based on unique seed-eligible signatures."""

from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.candidates.core import WordIndex
from wordgame_pipeline.candidates.letter_audit import WheelLetterAudit, audit_wheel_letters
from wordgame_pipeline.config import load_config

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")


def index(**tiers):
    return WordIndex(
        [{"word": word, "tier": tier} for word, tier in sorted(tiers.items())],
        CONFIG,
    )


def test_unique_wheels_not_one_per_seed_and_sorted_letters():
    report = audit_wheel_letters(index(DOM="level_ok", KOT="level_ok", TOK="level_ok"))
    assert report == (
        WheelLetterAudit("D", 1, 1),
        WheelLetterAudit("K", 1, 1),
        WheelLetterAudit("M", 1, 1),
        WheelLetterAudit("O", 2, 2),
        WheelLetterAudit("T", 1, 1),
    )
    assert report == audit_wheel_letters(index(DOM="level_ok", KOT="level_ok", TOK="level_ok"))
    with pytest.raises(FrozenInstanceError):
        report[0].wheel_count = 9


def test_repeated_tiles_and_no_eligible_seeds():
    report = audit_wheel_letters(index(ANNA="level_ok"))
    assert report == (
        WheelLetterAudit("A", 1, 2),
        WheelLetterAudit("N", 1, 2),
    )
    assert audit_wheel_letters(index(KOT="bonus_ok")) == ()
    assert audit_wheel_letters(index()) == ()


def test_invalid_source_rejected():
    with pytest.raises(ValueError):
        audit_wheel_letters(None)


def test_large_source_audit_does_not_materialize_bonus_pools(monkeypatch):
    words = index(KOT="level_ok", TOK="level_ok", ANNA="level_ok", DOM="bonus_ok")

    def fail_if_enumerated(_index):
        raise AssertionError("Wheel audit must not build automatic bonus pools")

    monkeypatch.setattr(WordIndex, "automatic", fail_if_enumerated)
    report = audit_wheel_letters(words)
    assert next(row for row in report if row.letter == "A") == WheelLetterAudit("A", 1, 2)
    assert next(row for row in report if row.letter == "O") == WheelLetterAudit("O", 1, 1)
    assert next(row for row in report if row.letter == "N") == WheelLetterAudit("N", 1, 2)
