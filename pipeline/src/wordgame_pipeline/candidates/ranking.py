"""Deterministic shortlist of tier-backed wheel opportunities."""

from dataclasses import dataclass

from .core import WordIndex


@dataclass(frozen=True)
class WheelOpportunity:
    candidate_id: str
    letters: int
    seeds: int
    selected_options: int
    bonus_options: int


def rank_candidate_wheels(
    index: WordIndex, *, minimum_words: int, limit: int
) -> tuple[WheelOpportunity, ...]:
    """Rank, never choose or change, explicitly eligible wheel pools."""
    if not isinstance(index, WordIndex):
        raise ValueError("Expected validated candidate index")
    if (
        type(minimum_words) is not int
        or minimum_words < 1
        or type(limit) is not int
        or limit < 1
    ):
        raise ValueError("Expected positive integer minimum and review limit")
    rows = [
        WheelOpportunity(
            entry["id"],
            len(entry["letters"]),
            len(entry["seeds"]),
            len(entry["level_ok"]),
            len(entry["bonus_ok"]),
        )
        for entry in index.automatic()
        if len(entry["level_ok"]) >= minimum_words
    ]
    return tuple(
        sorted(
            rows,
            key=lambda row: (
                -row.selected_options,
                -row.bonus_options,
                row.candidate_id,
            ),
        )[:limit]
    )
