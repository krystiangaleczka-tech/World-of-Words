"""P2 campaign score integration with explicit fixture weights."""

from copy import deepcopy
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.content_limits import MAX_CAMPAIGN_SLOTS
from wordgame_pipeline.scoring import FEATURE_NAMES, ScoringConfig
from wordgame_pipeline.scoring.campaign import score_campaign

LANGUAGE = load_config(Path(__file__).parents[2], "pl")


def scoring():
    rules = {
        name: {"weight": 0, "minimum": 0, "maximum": 10, "direction": "higher"}
        for name in FEATURE_NAMES
    }
    rules["letter_count"]["weight"] = 1
    return ScoringConfig.from_dict({"schema_version": 1, "features": rules})


def level(slot, word):
    return {
        "id": f"pl-c-{slot:06d}",
        "slot": slot,
        "letters": list(word),
        "words": [{"w": word, "x": 0, "y": 0, "dir": "v"}],
        "grid": {"w": 1, "h": len(word)},
    }


def test_contiguous_slots_have_explicit_scores_without_mutating_levels():
    levels = [level(2, "DOMY"), level(1, "KOT")]
    original = str(levels)
    result = score_campaign(levels, {"KOT": 20, "DOMY": None}, LANGUAGE, scoring())
    assert tuple(row.slot for row in result) == (1, 2)
    assert [row.score for row in result] == pytest.approx([0.3, 0.4])
    assert result[0].scoring_sha256 == result[1].scoring_sha256
    assert len(result[0].contributions) == len(FEATURE_NAMES)
    assert levels == [level(2, "DOMY"), level(1, "KOT")]
    assert str(levels) == original
    assert score_campaign(levels[::-1], {"DOMY": None, "KOT": 20}, LANGUAGE, scoring()) == result


def test_missing_frequency_duplicate_slot_and_bad_geometry_are_rejected():
    with pytest.raises(ValueError, match="frequency"):
        score_campaign([level(1, "KOT")], {}, LANGUAGE, scoring())
    with pytest.raises(ValueError, match="identity"):
        score_campaign([level(1, "KOT"), level(1, "DOM")], {}, LANGUAGE, scoring())
    with pytest.raises(ValueError, match="contiguous"):
        score_campaign([level(2, "KOT")], {"KOT": None}, LANGUAGE, scoring())
    malformed = level(1, "KOT")
    malformed["grid"] = {"w": 2, "h": 3}
    with pytest.raises(ValueError):
        score_campaign([malformed], {"KOT": None}, LANGUAGE, scoring())


@pytest.mark.parametrize("bad", [True, -1, "20", float("nan")])
def test_bad_source_frequency_is_not_coerced(bad):
    with pytest.raises(ValueError):
        score_campaign([level(1, "KOT")], {"KOT": bad}, LANGUAGE, scoring())


@pytest.mark.parametrize("slot", [True, 0, -1, 1.0, "1", MAX_CAMPAIGN_SLOTS + 1])
def test_campaign_identity_respects_canonical_slot_bounds(slot):
    candidate = level(1, "KOT")
    candidate["slot"] = slot
    with pytest.raises(ValueError):
        score_campaign([candidate], {"KOT": 20}, LANGUAGE, scoring())


def test_result_is_immutable_with_ordered_complete_contributions():
    levels = [level(1, "KOT")]
    frequencies = {"KOT": None}
    original = deepcopy((levels, frequencies))
    result = score_campaign(levels, frequencies, LANGUAGE, scoring())
    assert (levels, frequencies) == original
    assert isinstance(result, tuple)
    assert tuple(name for name, _ in result[0].contributions) == FEATURE_NAMES
    assert sum(value for _, value in result[0].contributions) == pytest.approx(result[0].score)
    with pytest.raises(FrozenInstanceError):
        result[0].score = 0
    assert result[0].level_id == "pl-c-000001"


@pytest.mark.parametrize("placements", [None, [], [None], [{"w": []}], [{"w": "KOT"}]])
def test_malformed_selected_words_fail_closed(placements):
    candidate = level(1, "KOT")
    candidate["words"] = placements
    with pytest.raises(ValueError):
        score_campaign([candidate], {"KOT": 20}, LANGUAGE, scoring())


@pytest.mark.parametrize("levels", [[], {}, None, [None]])
def test_invalid_campaign_container_is_rejected(levels):
    with pytest.raises(ValueError):
        score_campaign(levels, {"KOT": 20}, LANGUAGE, scoring())
