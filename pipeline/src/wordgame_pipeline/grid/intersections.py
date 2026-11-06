"""Read-only coordinates where validated crossword words cross."""

from .geometry import Placement, validate_geometry


def crossing_positions(
    layout: tuple[Placement, ...], words: tuple[str, ...]
) -> tuple[tuple[int, int], ...]:
    """Return stable crossing coordinates from the canonical grid validator."""
    if not isinstance(layout, tuple) or not isinstance(words, tuple):
        raise ValueError("Expected immutable layout and selected words")
    validate_geometry(layout, words)
    axes: dict[tuple[int, int], set[str]] = {}
    for word, x, y, direction in layout:
        dx, dy = (1, 0) if direction == "h" else (0, 1)
        for offset in range(len(word)):
            point = (x + dx * offset, y + dy * offset)
            axes.setdefault(point, set()).add(direction)
    return tuple(sorted(point for point, used in axes.items() if len(used) == 2))
