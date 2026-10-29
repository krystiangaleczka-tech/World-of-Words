"""Explain candidate low-frequency and missing-evidence crossword words."""

import math
from collections.abc import Mapping
from dataclasses import dataclass


@dataclass(frozen=True)
class WordReviewFlag:
    slot: int
    word: str
    reason: str
    arf: float | None


def _nonnegative(value: object) -> float:
    if type(value) not in (int, float):
        raise ValueError("ARF and cutoff must be finite nonnegative numbers")
    try:
        number = float(value)
    except OverflowError as exc:
        raise ValueError("Unrepresentable ARF/cutoff") from exc
    if not math.isfinite(number) or number < 0:
        raise ValueError("ARF and cutoff must be finite nonnegative numbers")
    return number


def flag_word_evidence(
    levels: list | tuple,
    frequencies: Mapping[str, float | None],
    *,
    low_arf: float,
    limit: int,
) -> tuple[WordReviewFlag, ...]:
    """Flag source evidence for human review, not a ban or tier decision.

    Frequency keys represent exact selected forms only. Missing ARF differs
    from known zero, and no synonym, lemma or AI fallback is inferred.
    """
    cutoff = _nonnegative(low_arf)
    if (
        not isinstance(levels, (list, tuple))
        or not levels
        or not isinstance(frequencies, Mapping)
        or type(limit) is not int
        or limit < 1
    ):
        raise ValueError("Expected campaign, exact-form map and positive review limit")
    positions: set[int] = set()
    observed: set[str] = set()
    occurrences: list[tuple[int, str]] = []
    for level in levels:
        if not isinstance(level, Mapping):
            raise ValueError("Expected validated campaign level")
        slot = level.get("slot")
        if (
            type(slot) is not int
            or not 1 <= slot <= 9999
            or slot in positions
            or level.get("id") != f"pl-c-{slot:06d}"
        ):
            raise ValueError("Invalid or repeated campaign identity")
        positions.add(slot)
        placements = level.get("words")
        if not isinstance(placements, list) or not placements:
            raise ValueError("Expected nonempty crossword placements")
        selected: set[str] = set()
        for item in placements:
            if not isinstance(item, Mapping):
                raise ValueError("Malformed crossword placement")
            word = item.get("w")
            if (
                not isinstance(word, str)
                or not 3 <= len(word) <= 8
                or word != word.upper()
                or word in selected
            ):
                raise ValueError("Invalid or repeated crossword form")
            selected.add(word)
            observed.add(word)
            occurrences.append((slot, word))
    if len(positions) != max(positions) or set(frequencies) != observed:
        raise ValueError("Noncontiguous campaign or mismatched exact-form ARF keys")
    validated: dict[str, float | None] = {}
    for word in sorted(observed):
        value = frequencies[word]
        validated[word] = None if value is None else _nonnegative(value)
    flagged = []
    for slot, word in occurrences:
        arf = validated[word]
        if arf is None:
            flagged.append(WordReviewFlag(slot, word, "missing_arf", None))
        elif arf <= cutoff:
            flagged.append(WordReviewFlag(slot, word, "low_arf", arf))
    flagged.sort(
        key=lambda flag: (
            flag.reason != "missing_arf",
            flag.arf if flag.arf is not None else 0.0,
            flag.slot,
            flag.word,
        )
    )
    return tuple(flagged[:limit])
