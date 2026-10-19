"""Mechanics-only fixture configuration; never production calibration."""

import copy
import hashlib
import math
from dataclasses import FrozenInstanceError, replace
from pathlib import Path

import pytest
from wordgame_pipeline.config import canonical_bytes, load_config
from wordgame_pipeline.scoring import (
    FEATURE_NAMES,
    DifficultyScore,
    FeatureRule,
    FeatureScore,
    ScoringConfig,
    extract_features,
    load_scoring,
    score_features,
)


def settings():
    return {
        "schema_version": 1,
        "features": {
            name: {"weight": 0, "minimum": 0, "maximum": 10, "direction": "higher"}
            for name in FEATURE_NAMES
        },
    }


def configured():
    data = settings()
    data["features"]["letter_count"]["weight"] = 1
    data["features"]["word_count"].update(weight=3, direction="lower")
    return data


def raw():
    return dict.fromkeys(FEATURE_NAMES, 0)


def test_exact_directions_weights_contributions_and_saturation():
    config = ScoringConfig.from_dict(configured())
    features = raw() | {"letter_count": 5, "word_count": 2}
    score = score_features(features, config)
    assert score.total == pytest.approx(0.725)
    assert score.features[0].normalized == 0.5
    assert score.features[0].contribution == 0.125
    words = next(f for f in score.features if f.name == "word_count")
    assert words.normalized == 0.8 and words.contribution == pytest.approx(0.6)
    assert sum(f.contribution for f in score.features) == score.total
    assert score_features(features | {"letter_count": 100}, config).features[0].normalized == 1
    assert score_features(features | {"letter_count": 0}, config).features[0].normalized == 0
    assert score_features(features | {"word_count": 100}, config).features[2].normalized == 0
    assert all(
        f.contribution == 0 for f in score.features if f.name not in {"letter_count", "word_count"}
    )


def test_extreme_finite_weights_and_feature_bounds_do_not_overflow():
    data = settings()
    for rule in data["features"].values():
        rule.update(weight=1e308, maximum=1e308)
    score = score_features(dict.fromkeys(FEATURE_NAMES, 1e308), ScoringConfig.from_dict(data))
    assert math.isfinite(score.total) and score.total == pytest.approx(1)


def test_order_hash_copies_and_frozen_results():
    data = configured()
    original = copy.deepcopy(data)
    config = ScoringConfig.from_dict(data)
    features = raw() | {"letter_count": 4}
    score = score_features(features, config)
    assert data == original
    reversed_data = dict(reversed(list(data.items())))
    reversed_data["features"] = dict(reversed(list(data["features"].items())))
    assert (
        score_features(
            dict(reversed(list(features.items()))), ScoringConfig.from_dict(reversed_data)
        )
        == score
    )
    assert score.config_sha256 == hashlib.sha256(canonical_bytes(config.to_dict())).hexdigest()
    data["features"]["letter_count"]["weight"] = 100
    config.to_dict()["features"]["word_count"]["weight"] = 100
    features["letter_count"] = 100
    assert config.rules[0].weight == 1 and score.features[0].raw == 4
    with pytest.raises(FrozenInstanceError):
        config.rules = ()
    with pytest.raises(FrozenInstanceError):
        score.features[0].raw = 100


@pytest.mark.parametrize(
    "field,value",
    [
        ("weight", True),
        ("weight", -1),
        ("weight", "1"),
        ("weight", float("nan")),
        ("weight", float("inf")),
        ("weight", 10**1000),
        ("minimum", -1),
        ("minimum", 10),
        ("maximum", 0),
        ("direction", "unknown"),
    ],
)
def test_invalid_rule_data_and_direct_constructor_fail(field, value):
    data = configured()
    data["features"]["letter_count"][field] = value
    with pytest.raises(ValueError):
        ScoringConfig.from_dict(data)
    rule = dict(name="letter_count", **configured()["features"]["letter_count"])
    rule[field] = value
    with pytest.raises(ValueError):
        FeatureRule(**rule)


@pytest.mark.parametrize(
    "mode", ["extra", "missing", "version", "bool_version", "feature", "rule", "zero", "null"]
)
def test_config_shape_and_all_zero_weights_fail(mode):
    data = configured()
    if mode == "extra":
        data["extra"] = 1
    elif mode == "missing":
        del data["schema_version"]
    elif mode == "version":
        data["schema_version"] = 2
    elif mode == "bool_version":
        data["schema_version"] = True
    elif mode == "feature":
        del data["features"]["letter_count"]
    elif mode == "rule":
        data["features"]["letter_count"]["extra"] = 1
    elif mode == "zero":
        data = settings()
    elif mode == "null":
        data = None
    with pytest.raises(ValueError):
        ScoringConfig.from_dict(data)


@pytest.mark.parametrize("value", [True, -1, float("nan"), float("inf"), "1", 10**1000])
def test_raw_features_reject_invalid_numeric_values(value):
    with pytest.raises(ValueError):
        score_features(raw() | {"letter_count": value}, ScoringConfig.from_dict(configured()))


def test_raw_and_direct_config_result_shapes_fail_closed():
    config = ScoringConfig.from_dict(configured())
    for features in ({}, raw() | {"unknown": 1}, None):
        with pytest.raises(ValueError):
            score_features(features, config)
    for rules in (list(config.rules), config.rules[:-1], tuple(reversed(config.rules)), (None,)):
        with pytest.raises(ValueError):
            ScoringConfig(rules)
    with pytest.raises(ValueError):
        replace(config, rules=tuple(replace(r, weight=0) for r in config.rules))
    with pytest.raises(ValueError):
        FeatureScore("bad", 0, 0, 0)
    with pytest.raises(ValueError):
        FeatureScore(FEATURE_NAMES[0], 0, 2, 0)
    score = score_features(raw(), config)
    with pytest.raises(ValueError):
        replace(score, total=0.123)
    with pytest.raises(ValueError):
        replace(score, config_sha256="bad")
    with pytest.raises(ValueError):
        DifficultyScore(0, score.config_sha256, ())


def test_explicit_file_loading_rejects_duplicates_nonfinite_and_missing(tmp_path):
    path = tmp_path / "scoring.yaml"
    with pytest.raises(ValueError, match="scoring.yaml"):
        load_scoring(path)
    for text in ('{"schema_version":1,"schema_version":1}', '{"features":NaN}', "features: {}"):
        path.write_text(text)
        with pytest.raises(ValueError):
            load_scoring(path)
    path.write_bytes(canonical_bytes(configured()))
    before = path.read_bytes()
    assert load_scoring(path) == ScoringConfig.from_dict(configured())
    assert path.read_bytes() == before


def test_extracted_features_and_monotonic_direction():
    level = {
        "letters": list("KOT"),
        "words": [{"w": "KOT", "x": 0, "y": 0, "dir": "v"}],
        "grid": {"w": 1, "h": 3},
    }
    language = load_config(Path(__file__).resolve().parents[2], "pl")
    features = extract_features(level, {"KOT": None}, language)
    config = ScoringConfig.from_dict(configured())
    baseline = score_features(features, config)
    assert 0 <= baseline.total <= 1
    assert score_features(features | {"letter_count": 4}, config).total > baseline.total
    assert score_features(features | {"word_count": 2}, config).total < baseline.total


def test_invalid_configuration_and_impossible_feature_contribution_reject():
    with pytest.raises(ValueError):
        score_features(raw(), None)
    with pytest.raises(ValueError):
        FeatureScore(FEATURE_NAMES[0], 0, 0.5, 0.6)


def test_shifted_positive_range_clamps_and_normalizes_in_both_directions():
    data = settings()
    data["features"]["letter_count"].update(weight=1, minimum=2, maximum=6)
    for value, expected in [(0, 0), (2, 0), (4, 0.5), (6, 1), (100, 1)]:
        features = raw() | {"letter_count": value}
        data["features"]["letter_count"]["direction"] = "higher"
        assert score_features(features, ScoringConfig.from_dict(data)).total == expected
        data["features"]["letter_count"]["direction"] = "lower"
        assert score_features(features, ScoringConfig.from_dict(data)).total == 1 - expected
