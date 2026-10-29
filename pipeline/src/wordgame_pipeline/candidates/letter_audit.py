"""Descriptive alphabet exposure of tier-backed automatic wheel candidates."""

from collections import Counter
from dataclasses import dataclass

from .core import WordIndex


@dataclass(frozen=True)
class WheelLetterAudit:
    letter: str
    wheel_count: int
    tile_count: int


def audit_wheel_letters(index: WordIndex) -> tuple[WheelLetterAudit, ...]:
    """Count wheel presence and tile multiplicity without choosing candidates."""
    if not isinstance(index, WordIndex):
        raise ValueError("Expected validated candidate index")
    presence: Counter[str] = Counter()
    totals: Counter[str] = Counter()
    for candidate in index.automatic():
        letters = candidate["letters"]
        presence.update(set(letters))
        totals.update(letters)
    return tuple(
        WheelLetterAudit(letter, presence[letter], totals[letter])
        for letter in sorted(totals)
    )
