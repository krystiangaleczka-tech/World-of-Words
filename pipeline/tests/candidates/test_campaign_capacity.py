"""The launch content budget must be measured against source-backed signatures."""

import json
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.candidates.campaign_capacity import (
    CampaignCapacity,
    audit_campaign_capacity,
)
from wordgame_pipeline.candidates.core import WordIndex
from wordgame_pipeline.config import load_config

ROOT = Path(__file__).resolve().parents[2]
REPO = ROOT.parent
CONFIG = load_config(ROOT, "pl")


def index(**tiers):
    return WordIndex(
        [{"word": word, "tier": tier} for word, tier in sorted(tiers.items())],
        CONFIG,
    )


def test_real_pinned_p1_supply_sets_hard_upper_bound(monkeypatch):
    receipt = json.loads((ROOT / "content-inputs/pl.json").read_text(encoding="utf-8"))
    pack = json.loads(
        (REPO / "game/content/pl/packs/c-0001-0065.json").read_text(encoding="utf-8")
    )
    idx = WordIndex(receipt["records"], CONFIG)
    wheels = [entry["letters"] for entry in pack["levels"]]
    original = [letters.copy() for letters in wheels]

    def forbidden_automatic(_self):
        raise AssertionError("Do not enumerate bonus pools during capacity preflight")

    monkeypatch.setattr(WordIndex, "automatic", forbidden_automatic)
    launch = audit_campaign_capacity(idx, wheels, target_slots=10_000)
    assert launch == CampaignCapacity(10_000, 65, 486, 421, 486, 9_514)
    assert audit_campaign_capacity(idx, wheels, target_slots=30_000) == CampaignCapacity(
        30_000, 65, 486, 421, 486, 29_514
    )
    assert wheels == original
    with pytest.raises(FrozenInstanceError):
        launch.missing_unique_wheels = 0


def test_anagram_seed_counted_once_and_bonus_not_source():
    idx = index(DOM="level_ok", KOT="level_ok", TOK="level_ok", LAS="bonus_ok")
    assert audit_campaign_capacity(idx, [], target_slots=2) == CampaignCapacity(
        2, 0, 2, 2, 2, 0
    )
    assert audit_campaign_capacity(idx, [list("KOT")], target_slots=4) == CampaignCapacity(
        4, 1, 2, 1, 2, 2
    )


def test_historical_wheel_not_present_in_current_source_is_preserved():
    idx = index(DOM="level_ok")
    result = audit_campaign_capacity(idx, [list("KOT")], target_slots=3)
    assert result == CampaignCapacity(3, 1, 1, 1, 2, 1)
    assert audit_campaign_capacity(index(), [], target_slots=1) == CampaignCapacity(
        1, 0, 0, 0, 0, 1
    )


@pytest.mark.parametrize("target", [None, True, False, 0, -1, 1.0, "10000"])
def test_invalid_target_rejected(target):
    with pytest.raises(ValueError, match="target"):
        audit_campaign_capacity(index(KOT="level_ok"), [], target_slots=target)


@pytest.mark.parametrize(
    "wheels",
    [
        None,
        "KOT",
        [["K", "O"]],
        [["K", "O", "T", "X", "Y", "Z", "L", "M", "S"]],
        [["K", "O", None]],
        [["K", "O", "lowercase"]],
        [["K", "O", "1"]],
        [list("KOT"), list("TOK")],
        [list("KOT"), tuple("TOK")],
    ],
)
def test_invalid_or_duplicate_existing_wheels_rejected(wheels):
    with pytest.raises(ValueError):
        audit_campaign_capacity(index(KOT="level_ok"), wheels, target_slots=10_000)


def test_target_cannot_be_smaller_than_shipped_and_invalid_index_fails():
    with pytest.raises(ValueError, match="smaller"):
        audit_campaign_capacity(index(), [list("KOT"), list("DOM")], target_slots=1)
    with pytest.raises(ValueError, match="index"):
        audit_campaign_capacity(None, [], target_slots=10_000)
