"""Order the QA campaign by measured difficulty bands under answer spacing."""

import hashlib
import heapq
from collections import Counter
from dataclasses import dataclass

from ..config import LanguageConfig, canonical_bytes
from ..dedupe.core import CROSSWORD_SPACING
from ..scoring import ScoringConfig, extract_features, score_features

BAND_COUNT = 5


@dataclass(frozen=True)
class DifficultyBand:
    number: int
    first: int
    last: int
    minimum: float
    maximum: float


@dataclass(frozen=True)
class DifficultyAssignment:
    source_slot: int
    band: int
    estimate: float


@dataclass(frozen=True)
class Progression:
    assignments: tuple[DifficultyAssignment, ...]
    bands: tuple[DifficultyBand, ...]
    scoring_sha256: str


@dataclass(frozen=True)
class _Candidate:
    slot: int
    score: float
    words: tuple[str, ...]


def _first_available(candidate: _Candidate, last_use: dict[str, int]) -> int:
    latest = max(last_use.get(word, -CROSSWORD_SPACING) for word in candidate.words)
    return latest + CROSSWORD_SPACING


def _arrange_band(
    measured: list[_Candidate],
    band: DifficultyBand,
    last_use: dict[str, int],
    *,
    opening: bool,
    final: bool,
) -> list[_Candidate]:
    remaining = measured.copy()
    closer = remaining.pop() if final else None
    ending_words = set(closer.words) if closer else set()
    arranged: list[_Candidate] = []

    def place(candidate: _Candidate) -> None:
        last_use.update(dict.fromkeys(candidate.words, band.first + len(arranged)))
        arranged.append(candidate)

    if opening:
        first = next(
            (i for i, c in enumerate(remaining) if _first_available(c, last_use) <= band.first),
            None,
        )
        if first is None:
            raise ValueError(f"Difficulty band {band.number} has no eligible opening crossword")
        place(remaining.pop(first))

    counts = Counter(word for candidate in remaining for word in candidate.words)
    ready = []
    for candidate in remaining:
        uses = [counts[word] for word in candidate.words]
        # Every crossword sharing a final answer has a deadline before the closer's gap.
        # For the remaining crosswords, consume frequent repeats before one-off answers.
        priority = (
            ending_words.isdisjoint(candidate.words),
            -max(uses),
            -sum(uses),
            candidate.score,
            candidate.slot,
        )
        ready.append((priority, candidate))
    heapq.heapify(ready)
    blocked = []
    while ready or blocked:
        slot = band.first + len(arranged)
        while blocked and blocked[0][0] <= slot:
            heapq.heappush(ready, heapq.heappop(blocked)[1])
        if not ready:
            raise ValueError(
                f"Difficulty band {band.number} cannot preserve spacing at slot {slot}"
            )
        item = heapq.heappop(ready)
        candidate = item[1]
        eligible = _first_available(candidate, last_use)
        if band.last - slot < CROSSWORD_SPACING and not ending_words.isdisjoint(candidate.words):
            eligible = max(eligible, band.last + CROSSWORD_SPACING)
        if eligible > slot:
            heapq.heappush(blocked, (eligible, item))
        else:
            place(candidate)

    if closer is not None:
        if _first_available(closer, last_use) > band.last:
            raise ValueError(f"Final crossword conflicts with answer spacing at slot {band.last}")
        place(closer)
    return arranged


def plan_progression(
    fixed: list[dict],
    candidates: list[dict],
    frequencies: dict[str, float | None],
    language: LanguageConfig,
    scoring: ScoringConfig,
) -> Progression:
    """Measure validated layouts and plan five bands with a deterministic greedy pass."""
    if len(candidates) < BAND_COUNT:
        raise ValueError("The candidate campaign requires five nonempty difficulty bands")
    measured = []
    for level in candidates:
        words = tuple(p["w"] for p in level["words"])
        features = extract_features(level, {word: frequencies[word] for word in words}, language)
        measured.append(_Candidate(level["slot"], score_features(features, scoring).total, words))
    measured.sort(key=lambda candidate: (candidate.score, candidate.slot))
    last_use = {p["w"]: level["slot"] for level in fixed for p in level["words"]}
    assignments = []
    bands = []
    for number in range(1, BAND_COUNT + 1):
        start = len(measured) * (number - 1) // BAND_COUNT
        stop = len(measured) * number // BAND_COUNT
        part = measured[start:stop]
        band = DifficultyBand(
            number, len(fixed) + start + 1, len(fixed) + stop, part[0].score, part[-1].score
        )
        arranged = _arrange_band(
            part, band, last_use, opening=number == 1, final=number == BAND_COUNT
        )
        assignments.extend(DifficultyAssignment(c.slot, number, c.score) for c in arranged)
        bands.append(band)
    scoring_hash = hashlib.sha256(canonical_bytes(scoring.to_dict())).hexdigest()
    return Progression(tuple(assignments), tuple(bands), scoring_hash)
