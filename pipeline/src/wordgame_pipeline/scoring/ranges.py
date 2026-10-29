"""Observed raw scoring feature ranges for deterministic calibration review."""

import math
from collections.abc import Mapping
from dataclasses import dataclass
from unicodedata import category

from .features import FEATURE_NAMES
from .model import ScoringConfig, score_features


@dataclass(frozen=True)
class FeatureRange:
    name: str
    minimum: float
    maximum: float
    mean: float


def review_feature_ranges(candidates: Mapping, config: ScoringConfig) -> tuple[FeatureRange, ...]:
    """Validate all candidate evidence and report its uncalibrated ranges."""
    if (
        not isinstance(candidates, Mapping)
        or not candidates
        or not isinstance(config, ScoringConfig)
    ):
        raise ValueError("Expected nonempty raw candidate features and scoring config")
    raw: dict[str, list[float]] = {name: [] for name in FEATURE_NAMES}
    for candidate_id in sorted(candidates):
        if (
            not isinstance(candidate_id, str)
            or not candidate_id
            or candidate_id != candidate_id.strip()
            or any(category(char) in ("Cc", "Cf") for char in candidate_id)
        ):
            raise ValueError("Invalid candidate identity")
        result = score_features(candidates[candidate_id], config)
        for feature in result.features:
            raw[feature.name].append(feature.raw)
    return tuple(
        FeatureRange(
            name,
            min(raw[name]),
            max(raw[name]),
            math.fsum(raw[name]) / len(raw[name]),
        )
        for name in FEATURE_NAMES
    )
