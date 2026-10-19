"""Pure pairwise duplicate evidence; never choose, reorder or write levels."""

import math
from collections import Counter
from collections.abc import Mapping
from dataclasses import dataclass
from itertools import combinations

from ..config import LanguageConfig
from ..tiers.core import valid_word

CROSSWORD_SPACING = 100  # CONTENT.md: every crossword word, not only the seed.


@dataclass(frozen=True)
class DuplicatePolicy:
    jaccard_threshold: float
    seed_spacing: int

    def __post_init__(self) -> None:
        value = self.jaccard_threshold
        if (
            type(value) not in (int, float)
            or not 0 <= value <= 1
            or not math.isfinite(value)
            or type(self.seed_spacing) is not int
            or self.seed_spacing < CROSSWORD_SPACING
        ):
            raise ValueError("Expected threshold0..1 and seed spacing>=100")
        object.__setattr__(self, "jaccard_threshold", float(value))


@dataclass(frozen=True)
class DuplicateConflict:
    left_id: str
    right_id: str
    reasons: tuple[str, ...]
    shared_words: tuple[str, ...]
    jaccard: float


@dataclass(frozen=True)
class _Record:
    id: str
    pool: str
    slot: int
    letters: tuple[str, ...]
    words: frozenset[str]
    seed_word: str


def _record(data: object, config: LanguageConfig) -> _Record:
    fields = {"id", "pool", "slot", "letters", "words", "seed_word"}
    if not isinstance(data, Mapping) or set(data) != fields:
        raise ValueError("Invalid duplicate-analysis record fields")
    identity, pool, slot = data["id"], data["pool"], data["slot"]
    if (
        not isinstance(identity, str)
        or not identity
        or identity != identity.strip()
        or any(ord(c) < 32 for c in identity)
        or not isinstance(pool, str)
        or pool not in ("campaign", "daily")
        or type(slot) is not int
        or slot < 1
    ):
        raise ValueError("Invalid record identity/pool/slot")
    letters, words, seed = data["letters"], data["words"], data["seed_word"]
    if (
        not isinstance(letters, list)
        or not config.min_length <= len(letters) <= config.max_length
        or any(not isinstance(c, str) or len(c) != 1 or c not in config.alphabet for c in letters)
        or not isinstance(words, list)
        or not words
        or any(not valid_word(word, config) for word in words)
        or len(set(words)) != len(words)
        or not isinstance(seed, str)
        or seed not in words
    ):
        raise ValueError("Invalid normalized tiles/selected words/explicit seed")
    wheel = Counter(letters)
    if any(not Counter(word) <= wheel for word in words):
        raise ValueError("Selected word is not formable with tile multiplicity")
    return _Record(identity, pool, slot, tuple(sorted(letters)), frozenset(words), seed)


def audit_duplicates(
    records: list | tuple, policy: DuplicatePolicy, config: LanguageConfig
) -> tuple[DuplicateConflict, ...]:
    if not isinstance(records, (list, tuple)) or not isinstance(policy, DuplicatePolicy):
        raise ValueError("Expected finite analysis records and explicit duplicate policy")
    if not isinstance(config, LanguageConfig):
        raise ValueError("Expected language configuration")
    prepared = [_record(record, config) for record in records]
    if len({r.id for r in prepared}) != len(prepared) or len(
        {(r.pool, r.slot) for r in prepared}
    ) != len(prepared):
        raise ValueError("Duplicate analysis ID or pool/slot position")
    prepared.sort(key=lambda r: (r.pool, r.slot, r.id))
    conflicts = []
    for left, right in combinations(prepared, 2):
        shared = left.words & right.words
        ratio = len(shared) / len(left.words | right.words)
        reasons = []
        if left.letters == right.letters:
            reasons.append("letter_multiset")
        if ratio > policy.jaccard_threshold:
            reasons.append("word_jaccard")
        if left.pool == right.pool == "campaign":
            gap = abs(left.slot - right.slot)
            if shared and gap < CROSSWORD_SPACING:
                reasons.append("word_spacing")
            if left.seed_word == right.seed_word and gap < policy.seed_spacing:
                reasons.append("seed_spacing")
        if reasons:
            conflicts.append(
                DuplicateConflict(left.id, right.id, tuple(reasons), tuple(sorted(shared)), ratio)
            )
    return tuple(conflicts)
