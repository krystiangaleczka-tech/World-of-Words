"""Review-only crossword geometry measurements; never alter placements."""

from dataclasses import dataclass

from .geometry import Placement, cells_for, validate_geometry


@dataclass(frozen=True)
class GridQuality:
    width: int
    height: int
    selected_words: int
    occupied_cells: int
    crossings: int
    fill_ratio: float
    meets_minimum: bool


def review_grid_quality(
    layout: tuple[Placement, ...],
    selected: tuple[str, ...],
    *,
    minimum_crossings: int,
) -> GridQuality:
    """Validate canonical geometry and report crossing density for review."""
    if type(minimum_crossings) is not int or minimum_crossings < 0:
        raise ValueError("Minimum crossing count must be a nonnegative integer")
    if not isinstance(layout, tuple) or not isinstance(selected, tuple):
        raise ValueError("Expected immutable crossword placements and selected words")
    dimensions = validate_geometry(layout, selected)
    occupied = len(cells_for(layout))
    crossings = sum(len(word) for word in selected) - occupied
    return GridQuality(
        dimensions["w"],
        dimensions["h"],
        len(selected),
        occupied,
        crossings,
        occupied / (dimensions["w"] * dimensions["h"]),
        crossings >= minimum_crossings,
    )
