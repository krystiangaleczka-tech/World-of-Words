"""Explicit zero versus missing form evidence must not be conflated."""

from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.annotate.coverage import ArfCoverage, audit_arf_coverage
from wordgame_pipeline.annotate.frequency import Frequency
from wordgame_pipeline.config import load_config

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")


def test_nullable_zero_low_and_known_arf():
    report = audit_arf_coverage(
        ("TOK", "DOM", "KOT", "LAS"),
        {"TOK": Frequency(0, 0), "DOM": Frequency(5, 1),
         "KOT": None, "LAS": Frequency(2, 0.1)},
        CONFIG,
        low_arf=2,
    )
    assert report == ArfCoverage(4, 3, ("KOT",), ("TOK",), ("LAS", "TOK"))
    with pytest.raises(FrozenInstanceError):
        report.available_count = 4


def test_order_independent_and_empty():
    a = audit_arf_coverage(("TOK", "KOT"), {"TOK": None, "KOT": Frequency(0, 0)},
                           CONFIG, low_arf=0)
    b = audit_arf_coverage(("KOT", "TOK"), {"KOT": Frequency(0, 0), "TOK": None},
                           CONFIG, low_arf=0)
    assert a == b
    assert audit_arf_coverage((), {}, CONFIG, low_arf=0) == ArfCoverage(0, 0, (), (), ())


@pytest.mark.parametrize("value", [-1, True, None, "2", float("inf"), float("nan"), 10**400])
def test_invalid_threshold_rejected(value):
    with pytest.raises(ValueError):
        audit_arf_coverage((), {}, CONFIG, low_arf=value)


def test_bad_evidence_and_words_fail():
    for words, evidence in (
        (("KOT", "KOT"), {"KOT": None}),
        (("kot",), {"kot": None}),
        (("KOT",), {}),
        (("KOT",), {"KOT": Frequency(float("nan"), 1)}),
        (("KOT",), {"KOT": Frequency(1, -1)}),
        (("KOT",), {"KOT": {"arf": 1, "ipm": 1}}),
        (("KOT",), {"KOT": None, "TOK": None}),
    ):
        with pytest.raises(ValueError):
            audit_arf_coverage(words, evidence, CONFIG, low_arf=1)
