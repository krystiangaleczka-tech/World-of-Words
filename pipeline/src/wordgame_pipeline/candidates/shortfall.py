"""Rank read-only production candidate deficits by missing eligible words."""

from dataclasses import dataclass

from .core import WordIndex


@dataclass(frozen=True)
class CandidateShortfall:
    candidate_id: str
    available: int
    missing: int
    wheel_length: int
    seed_count: int


def rank_candidate_shortfalls(index: WordIndex, *, required_words: int) -> tuple[CandidateShortfall, ...]:
    """Prioritize wheel supply gaps; never invent missing source words."""
    if not isinstance(index, WordIndex) or type(required_words) is not int or required_words < 1:
        raise ValueError("Expected word index and explicit positive word target")
    result = []
    for row in index.automatic():
        available = len(row["level_ok"])
        if available < required_words:
            result.append(
                CandidateShortfall(
                    row["id"], available, required_words - available,
                    len(row["letters"]), len(row["seeds"]),
                )
            )
    return tuple(sorted(result, key=lambda item: (-item.missing, item.candidate_id)))
