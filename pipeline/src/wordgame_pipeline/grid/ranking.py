"""Rank valid crossword placement alternatives without mutating geometry."""

from collections.abc import Mapping
from dataclasses import dataclass

from .geometry import Placement
from .quality import GridQuality, review_grid_quality


@dataclass(frozen=True)
class LayoutRank:
    identity: str
    quality: GridQuality


def rank_layouts(
    alternatives: Mapping[str, tuple[Placement, ...]],
    selected: tuple[str, ...],
    *,
    minimum_crossings: int,
) -> tuple[LayoutRank, ...]:
    """Prefer crossing requirement, then crossings and density, then ID."""
    if not isinstance(alternatives, Mapping) or not alternatives:
        raise ValueError("Expected nonempty named layout alternatives")
    if any(not isinstance(key, str) or not key or key != key.strip() for key in alternatives):
        raise ValueError("Expected nonempty stable layout identities")
    ranked = [
        LayoutRank(
            identity,
            review_grid_quality(layout, selected, minimum_crossings=minimum_crossings),
        )
        for identity, layout in alternatives.items()
    ]
    return tuple(
        sorted(
            ranked,
            key=lambda row: (
                not row.quality.meets_minimum,
                -row.quality.crossings,
                -row.quality.fill_ratio,
                row.identity,
            ),
        )
    )
