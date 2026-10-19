"""Explicit bounded scoring with immutable, provenance-bearing explanations."""

import hashlib
import math
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path

from ..config import canonical_bytes, parse_json
from .features import FEATURE_NAMES


def _number(value: object) -> float:
    if type(value) not in (int, float):
        raise ValueError("Expected finite nonnegative number, not bool/coercion")
    try:
        result = float(value)
    except OverflowError as exc:
        raise ValueError("Unrepresentable scoring number") from exc
    if not math.isfinite(result) or result < 0:
        raise ValueError("Expected finite nonnegative scoring number")
    return result


@dataclass(frozen=True)
class FeatureRule:
    name: str
    weight: float
    minimum: float
    maximum: float
    direction: str

    def __post_init__(self) -> None:
        if self.name not in FEATURE_NAMES or self.direction not in ("higher", "lower"):
            raise ValueError("Unknown feature or scoring direction")
        for field in ("weight", "minimum", "maximum"):
            object.__setattr__(self, field, _number(getattr(self, field)))
        if self.minimum >= self.maximum:
            raise ValueError("Feature minimum must be less than maximum")


@dataclass(frozen=True)
class ScoringConfig:
    rules: tuple[FeatureRule, ...]

    def __post_init__(self) -> None:
        if (
            not isinstance(self.rules, tuple)
            or any(not isinstance(rule, FeatureRule) for rule in self.rules)
            or tuple(rule.name for rule in self.rules) != FEATURE_NAMES
            or not any(rule.weight > 0 for rule in self.rules)
        ):
            raise ValueError("Config requires ordered complete rules and a positive weight")

    @classmethod
    def from_dict(cls, data: object) -> "ScoringConfig":
        if (
            not isinstance(data, dict)
            or set(data) != {"schema_version", "features"}
            or type(data["schema_version"]) is not int
            or data["schema_version"] != 1
            or not isinstance(data["features"], dict)
            or set(data["features"]) != set(FEATURE_NAMES)
        ):
            raise ValueError("Expected version1 scoring config with exact feature names")
        rules = []
        for name in FEATURE_NAMES:
            rule = data["features"][name]
            if not isinstance(rule, dict) or set(rule) != {
                "weight",
                "minimum",
                "maximum",
                "direction",
            }:
                raise ValueError("Invalid scoring rule fields")
            rules.append(FeatureRule(name, **rule))
        return cls(tuple(rules))

    def to_dict(self) -> dict:
        return {
            "schema_version": 1,
            "features": {
                rule.name: {
                    key: getattr(rule, key) for key in ("weight", "minimum", "maximum", "direction")
                }
                for rule in self.rules
            },
        }


@dataclass(frozen=True)
class FeatureScore:
    name: str
    raw: float
    normalized: float
    contribution: float

    def __post_init__(self) -> None:
        if self.name not in FEATURE_NAMES:
            raise ValueError("Unknown score feature")
        for field in ("raw", "normalized", "contribution"):
            object.__setattr__(self, field, _number(getattr(self, field)))
        if self.normalized > 1 or self.contribution > self.normalized:
            raise ValueError("Normalized score and contribution must be bounded")


@dataclass(frozen=True)
class DifficultyScore:
    total: float
    config_sha256: str
    features: tuple[FeatureScore, ...]

    def __post_init__(self) -> None:
        object.__setattr__(self, "total", _number(self.total))
        if (
            self.total > 1
            or not isinstance(self.config_sha256, str)
            or len(self.config_sha256) != 64
            or any(c not in "0123456789abcdef" for c in self.config_sha256)
            or not isinstance(self.features, tuple)
            or any(not isinstance(feature, FeatureScore) for feature in self.features)
            or tuple(feature.name for feature in self.features) != FEATURE_NAMES
            or self.total != min(1.0, math.fsum(feature.contribution for feature in self.features))
        ):
            raise ValueError("Invalid bounded difficulty explanation")


def load_scoring(path: Path) -> ScoringConfig:
    try:
        return ScoringConfig.from_dict(parse_json(path.read_text(encoding="utf-8")))
    except (OSError, ValueError) as exc:
        raise ValueError(f"{path}: {exc}") from exc


def score_features(features: Mapping, config: ScoringConfig) -> DifficultyScore:
    if not isinstance(config, ScoringConfig):
        raise ValueError("Expected validated scoring configuration")
    if not isinstance(features, Mapping) or set(features) != set(FEATURE_NAMES):
        raise ValueError("Raw score requires exactly the known features")
    raw = {name: _number(features[name]) for name in FEATURE_NAMES}
    scale = max(rule.weight for rule in config.rules)
    scaled = [rule.weight / scale for rule in config.rules]
    total_weight = math.fsum(scaled)
    explanation = []
    for rule, weight in zip(config.rules, scaled, strict=True):
        value = min(rule.maximum, max(rule.minimum, raw[rule.name]))
        normalized = (value - rule.minimum) / (rule.maximum - rule.minimum)
        if rule.direction == "lower":
            normalized = 1 - normalized
        explanation.append(
            FeatureScore(
                rule.name, raw[rule.name], normalized, normalized * (weight / total_weight)
            )
        )
    total = min(1.0, math.fsum(feature.contribution for feature in explanation))
    digest = hashlib.sha256(canonical_bytes(config.to_dict())).hexdigest()
    return DifficultyScore(total, digest, tuple(explanation))
