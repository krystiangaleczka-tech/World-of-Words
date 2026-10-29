"""Pure, ordered evidence of selected words repeated across campaign slots."""

from collections import defaultdict
from collections.abc import Mapping
from dataclasses import dataclass


@dataclass(frozen=True)
class WordReuse:
    word: str
    slots: tuple[int, ...]


def review_word_reuse(
    levels: list | tuple, *, minimum_levels: int
) -> tuple[WordReuse, ...]:
    """Report repeat occurrences, not a release gate or an approval decision."""
    if (
        not isinstance(levels, (list, tuple))
        or type(minimum_levels) is not int
        or minimum_levels < 2
    ):
        raise ValueError("Expected campaign levels and a minimum of two slots")
    positions: set[int] = set()
    observed: dict[str, set[int]] = defaultdict(set)
    for level in levels:
        if not isinstance(level, Mapping):
            raise ValueError("Expected campaign level mapping")
        slot, placements = level.get("slot"), level.get("words")
        if (
            type(slot) is not int
            or not 1 <= slot <= 9999
            or slot in positions
            or level.get("id") != f"pl-c-{slot:06d}"
            or not isinstance(placements, list)
            or not placements
        ):
            raise ValueError("Invalid or repeated campaign identity/placements")
        positions.add(slot)
        selected: set[str] = set()
        for placement in placements:
            if not isinstance(placement, Mapping):
                raise ValueError("Invalid selected-word placement")
            word = placement.get("w")
            if (
                not isinstance(word, str)
                or not 3 <= len(word) <= 8
                or word != word.upper()
                or word in selected
            ):
                raise ValueError("Invalid or repeated selected word")
            selected.add(word)
            observed[word].add(slot)
    if positions and positions != set(range(1, len(positions) + 1)):
        raise ValueError("Campaign slots must start at one and be contiguous")
    matches = [
        WordReuse(word, tuple(sorted(slots)))
        for word, slots in observed.items()
        if len(slots) >= minimum_levels
    ]
    return tuple(sorted(matches, key=lambda row: (-len(row.slots), row.word)))
