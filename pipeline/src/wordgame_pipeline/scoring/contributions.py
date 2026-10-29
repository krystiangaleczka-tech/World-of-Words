"""Read-only explanation of explicitly configured feature contributions."""

import math
from dataclasses import dataclass

from .model import ScoringConfig, score_features


@dataclass(frozen=True)
class ContributionRow:
    name: str
    raw: float
    normalized: float
    contribution: float


def rank_feature_contributions(
    features: dict, config: ScoringConfig, *, minimum_contribution: float
) -> tuple[ContributionRow, ...]:
    """Return feature contributions above an explicit threshold."""
    if type(minimum_contribution) not in (int, float):
        raise ValueError("Expected finite contribution threshold")
    try:
        cutoff = float(minimum_contribution)
    except OverflowError as exc:
        raise ValueError("Unrepresentable contribution threshold") from exc
    if not math.isfinite(cutoff) or not 0 <= cutoff <= 1:
        raise ValueError("Contribution threshold must be in [0,1]")
    explanation = score_features(features, config)
    return tuple(
        sorted(
            (
                ContributionRow(row.name, row.raw, row.normalized, row.contribution)
                for row in explanation.features
                if row.contribution > cutoff
            ),
            key=lambda row: (-row.contribution, row.name),
        )
    )
