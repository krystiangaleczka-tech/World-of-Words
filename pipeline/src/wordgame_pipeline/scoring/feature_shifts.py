"""Explain exactly which weighted scoring features changed between configs."""

import math
from collections.abc import Mapping
from dataclasses import dataclass

from .model import ScoringConfig, score_features


@dataclass(frozen=True)
class FeatureShift:
    feature: str
    previous_contribution: float
    proposed_contribution: float
    delta: float


def review_feature_shifts(
    features: Mapping,
    previous: ScoringConfig,
    proposed: ScoringConfig,
    *,
    minimum_delta: float,
) -> tuple[FeatureShift, ...]:
    """Rank per-feature contribution differences from validated scoring results."""
    if type(minimum_delta) not in (int, float):
        raise ValueError("Expected numeric delta cutoff")
    try:
        cutoff = float(minimum_delta)
    except OverflowError as exc:
        raise ValueError("Unrepresentable cutoff") from exc
    if not math.isfinite(cutoff) or not 0 <= cutoff <= 1:
        raise ValueError("Expected delta cutoff within [0,1]")
    before = score_features(features, previous)
    after = score_features(features, proposed)
    shifts = []
    for old, new in zip(before.features, after.features, strict=True):
        delta = new.contribution - old.contribution
        if abs(delta) > cutoff:
            shifts.append(FeatureShift(old.name, old.contribution, new.contribution, delta))
    return tuple(sorted(shifts, key=lambda row: (-abs(row.delta), row.feature)))
