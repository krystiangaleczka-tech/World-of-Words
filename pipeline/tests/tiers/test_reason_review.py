"""Tier reasons are descriptive, including human override provenance."""

from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.tiers.reason_review import (
    TierReasonCount,
    TierReasonReview,
    review_tier_reasons,
)

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")


def record(word, tier, reason):
    return {"word": word, "tier": tier, "tier_reason": reason}


def test_counts_order_provenance_and_nonmutation():
    records = [
        record("TOK", "bonus_ok", "rare_or_missing_frequency"),
        record("DOM", "level_ok", "override"),
        record("KOT", "level_ok", "common_base"),
        record("LAS", "level_ok", "common_base"),
    ]
    expected = TierReasonReview(
        4,
        (
            TierReasonCount("level_ok", "common_base", 2),
            TierReasonCount("level_ok", "override", 1),
            TierReasonCount("bonus_ok", "rare_or_missing_frequency", 1),
        ),
        ("DOM",),
    )
    assert review_tier_reasons(records, CONFIG) == expected
    assert review_tier_reasons(records[::-1], CONFIG) == expected
    assert records[0]["word"] == "TOK"
    with pytest.raises(FrozenInstanceError):
        expected.total = 99


def test_empty_is_a_valid_no_evidence_report():
    assert review_tier_reasons([], CONFIG) == TierReasonReview(0, (), ())


@pytest.mark.parametrize(
    "records",
    [
        None,
        [None],
        [record("KOT", "level_ok", "common_base")] * 2,
        [record("kot", "level_ok", "common_base")],
        [record("KOT", "other", "common_base")],
        [record("KOT", "level_ok", "unapproved")],
        [record("KOT", "level_ok", None)],
        [record("KOT", "level_ok", [])],
        [record("KOT", "level_ok", {})],
        [record("KOT", [], "common_base")],
    ],
)
def test_malformed_classifications_rejected(records):
    with pytest.raises(ValueError):
        review_tier_reasons(records, CONFIG)


def test_missing_config_rejected():
    with pytest.raises(ValueError):
        review_tier_reasons([], None)
