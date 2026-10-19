"""Hand-calculated measurements and shipped inputs; no dictionary or paid calls."""

import copy
import json
import math
from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.scoring import FEATURE_NAMES, extract_features

ROOT = Path(__file__).resolve().parents[2]
CONFIG = load_config(ROOT, "pl")


def crossing():
    return {
        "letters": list("KOT"),
        "words": [
            {"w": "KOT", "x": 0, "y": 0, "dir": "h"},
            {"w": "TOK", "x": 2, "y": 0, "dir": "v"},
        ],
        "grid": {"w": 3, "h": 3},
        "bonus": ["irrelevant bonus evidence"],
    }


def single(word="KOT"):
    return {
        "letters": list(word),
        "words": [{"w": word, "x": 0, "y": 0, "dir": "v"}],
        "grid": {"w": 1, "h": len(word)},
    }


def test_exact_crossing_anagram_and_partial_frequency_measurements():
    result = extract_features(crossing(), {"KOT": math.e - 1, "TOK": None}, CONFIG)
    assert list(result) == list(FEATURE_NAMES)
    assert result == pytest.approx(
        dict(zip(FEATURE_NAMES, [3, 3, 2, 3, 3, 1, 0.5, 1, 9, 5 / 9, 1, 1 / 5], strict=True))
    )
    assert all(type(v) is float and math.isfinite(v) for v in result.values())


def test_repeated_letters_and_zero_frequency_are_not_missing():
    result = extract_features(single("ANNA"), {"ANNA": 0}, CONFIG)
    assert result["distinct_letters"] == 2
    assert result["frequency_coverage"] == 1
    assert result["mean_log_arf"] == result["anagram_pairs"] == result["crossings"] == 0
    assert result["grid_fill"] == 1
    missing = extract_features(single("ANNA"), {"ANNA": None}, CONFIG)
    assert missing["frequency_coverage"] == 0
    assert missing["mean_log_arf"] == 0


def test_order_independence_no_mutation_and_fresh_output():
    level = crossing()
    frequencies = {"TOK": 12, "KOT": 23}
    before = copy.deepcopy((level, frequencies))
    expected = extract_features(level, frequencies, CONFIG)
    assert (level, frequencies) == before
    level["letters"].reverse()
    level["words"].reverse()
    assert extract_features(level, dict(reversed(list(frequencies.items()))), CONFIG) == expected
    expected["letter_count"] = -1
    assert extract_features(level, frequencies, CONFIG)["letter_count"] == 3


@pytest.mark.parametrize("frequency", [True, -1, float("nan"), float("inf"), "1", {}, 10**1000])
def test_invalid_frequency_rejected(frequency):
    with pytest.raises(ValueError):
        extract_features(single(), {"KOT": frequency}, CONFIG)


@pytest.mark.parametrize("frequency", [{}, {"KOT": None, "TOK": 1}, None])
def test_frequency_keys_are_exact(frequency):
    with pytest.raises(ValueError):
        extract_features(single(), frequency, CONFIG)


@pytest.mark.parametrize(
    "letters",
    ["KOT", [], ["K", "O"], list("kot"), list("QOT"), ["K", "O", "T", "A\u0328"], [True, "O", "T"]],
)
def test_invalid_wheel_rejected(letters):
    level = single()
    level["letters"] = letters
    with pytest.raises(ValueError):
        extract_features(level, {"KOT": None}, CONFIG)


@pytest.mark.parametrize(
    "update",
    [
        {"words": []},
        {"words": [{"w": "DOM", "x": 0, "y": 0, "dir": "v"}]},
        {"words": [{"w": "KOT", "x": True, "y": 0, "dir": "v"}]},
        {"words": [{"w": "KOT", "x": 0, "y": 0, "dir": "bad"}]},
        {"words": [{"w": "KOT", "x": 0, "y": 0, "dir": "v", "extra": 1}]},
        {"words": [None]},
        {"grid": {"w": True, "h": 3}},
        {"grid": {"w": 2, "h": 3}},
    ],
)
def test_malformed_or_mismatched_grid_rejected(update):
    with pytest.raises(ValueError):
        extract_features(single() | update, {"KOT": None}, CONFIG)


def test_all_current_shipped_levels_can_be_measured_without_writes():
    packs = sorted((ROOT.parent / "game/content/pl/packs").glob("*.json"))
    assert packs
    count = 0
    for path in packs:
        before = path.read_bytes()
        for level in json.loads(before)["levels"]:
            result = extract_features(level, {p["w"]: None for p in level["words"]}, CONFIG)
            assert result["frequency_coverage"] == 0
            assert all(math.isfinite(v) for v in result.values())
            count += 1
        assert path.read_bytes() == before
    assert count >= 65
