"""Compare explicitly supplied scoring configurations without editing content."""

import math
from collections.abc import Mapping
from dataclasses import dataclass
from unicodedata import category

from .model import ScoringConfig, score_features


@dataclass(frozen=True)
class ScoreShift:
    candidate_id: str
    previous: float
    proposed: float
    delta: float


def review_score_drift(
    candidates: Mapping[str, Mapping],
    previous: ScoringConfig,
    proposed: ScoringConfig,
    *,
    minimum_delta: float,
) -> tuple[ScoreShift, ...]:
    """Return significant signed shifts ranked by magnitude, then identity."""
    if type(minimum_delta) not in (int, float):
        raise ValueError("Expected numeric difference cutoff")
    try:
        cutoff = float(minimum_delta)
    except OverflowError as exc:
        raise ValueError("Unrepresentable difference cutoff") from exc
    if not math.isfinite(cutoff) or not 0 <= cutoff <= 1:
        raise ValueError("Expected difference cutoff in [0,1]")
    if (
        not isinstance(candidates, Mapping)
        or not isinstance(previous, ScoringConfig)
        or not isinstance(proposed, ScoringConfig)
    ):
        raise ValueError("Expected candidate features and explicit scoring rules")
    shifts = []
    for candidate_id, features in candidates.items():
        if (
            not isinstance(candidate_id, str)
            or not candidate_id
            or candidate_id.strip() != candidate_id
            or any(category(char) in ("Cc", "Cf") for char in candidate_id)
        ):
            raise ValueError("Invalid candidate identity")
        before = score_features(features, previous).total
        after = score_features(features, proposed).total
        delta = after - before
        if abs(delta) > cutoff:
            shifts.append(ScoreShift(candidate_id, before, after, delta))
    return tuple(sorted(shifts, key=lambda row: (-abs(row.delta), row.candidate_id)))
