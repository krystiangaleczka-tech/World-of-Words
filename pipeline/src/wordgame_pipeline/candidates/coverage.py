"""Read-only inventory of eligible word wheels before P2 content generation."""

from collections import Counter
from dataclasses import dataclass

from .core import WordIndex


@dataclass(frozen=True)
class WheelCoverage:
    candidate_id: str
    letter_count: int
    seed_count: int
    selected_options: int
    bonus_options: int
    eligible: bool


@dataclass(frozen=True)
class CoverageReport:
    required_words: int
    total_wheels: int
    eligible_wheels: int
    wheels_by_length: tuple[tuple[int, int], ...]
    shortages: tuple[WheelCoverage, ...]


def audit_candidate_coverage(index: WordIndex, *, minimum_words: int) -> CoverageReport:
    """Count candidate supply; never select, classify or approve any wheel."""
    if not isinstance(index, WordIndex):
        raise ValueError("Expected validated candidate word index")
    if type(minimum_words) is not int or minimum_words < 1:
        raise ValueError("Minimum selected-word count must be a positive integer")
    candidates = index.automatic()
    counts: Counter[int] = Counter()
    insufficient = []
    eligible = 0
    for candidate in candidates:
        size = len(candidate["letters"])
        selected = len(candidate["level_ok"])
        ready = selected >= minimum_words
        counts[size] += 1
        if ready:
            eligible += 1
        else:
            insufficient.append(
                WheelCoverage(
                    candidate["id"],
                    size,
                    len(candidate["seeds"]),
                    selected,
                    len(candidate["bonus_ok"]),
                    False,
                )
            )
    return CoverageReport(
        minimum_words,
        len(candidates),
        eligible,
        tuple(sorted(counts.items())),
        tuple(sorted(insufficient, key=lambda row: (row.letter_count, row.candidate_id))),
    )
