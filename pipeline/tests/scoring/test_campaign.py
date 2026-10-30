"""P2 campaign score integration with explicit fixture weights."""

from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
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
