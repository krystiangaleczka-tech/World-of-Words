"""Deterministic human review ranking of validated crossword grids."""

from collections.abc import Mapping
from dataclasses import dataclass
from unicodedata import category

from .quality import GridQuality, review_grid_quality


@dataclass(frozen=True)
class GridReviewRow:
    candidate_id: str
    quality: GridQuality


def review_grid_batch(candidates: Mapping, *, minimum_crossings: int) -> tuple[GridReviewRow, ...]:
    """Inspect supplied layouts without changing any crossword placements."""
    if not isinstance(candidates, Mapping):
        raise ValueError("Expected candidate layout mapping")
    if type(minimum_crossings) is not int or minimum_crossings < 0:
        raise ValueError("Invalid crossing minimum")
    rows = []
    for candidate_id, record in candidates.items():
        if (
            not isinstance(candidate_id, str)
            or not candidate_id
            or candidate_id != candidate_id.strip()
            or any(category(char) in ("Cc", "Cf") for char in candidate_id)
            or not isinstance(record, tuple)
            or len(record) != 2
        ):
            raise ValueError("Invalid candidate identity or grid record")
        layout, selected = record
        quality = review_grid_quality(layout, selected, minimum_crossings=minimum_crossings)
        rows.append(GridReviewRow(candidate_id, quality))
    return tuple(
        sorted(
            rows,
            key=lambda row: (
                row.quality.meets_minimum,
                row.quality.crossings,
                row.candidate_id,
            ),
        )
    )
