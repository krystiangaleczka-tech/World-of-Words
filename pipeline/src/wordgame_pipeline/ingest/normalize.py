"""Source form normalization does not invent morphology or familiarity evidence."""

import unicodedata
from collections import Counter
from collections.abc import Iterable
from dataclasses import dataclass

from ..config import LanguageConfig


@dataclass(frozen=True)
class WordEntry:
    word: str
    proper_noun: bool | None = None
    abbreviation: bool | None = None


def normalize_words(entries: Iterable[WordEntry], config: LanguageConfig) -> dict[str, object]:
    source_alphabet = set(config.alphabet + config.alphabet.lower())
    accepted: set[str] = set()
    rejected: Counter[str] = Counter()
    source_count = 0
    for entry in entries:
        source_count += 1
        if entry.proper_noun is True:
            rejected["proper_noun"] += 1
            continue
        if entry.abbreviation is True:
            rejected["abbreviation"] += 1
            continue
        nfc = unicodedata.normalize("NFC", entry.word)
        if any(letter not in source_alphabet for letter in nfc):
            rejected["alphabet"] += 1
            continue
        word = nfc.upper()
        if len(word) < config.min_length:
            rejected["short"] += 1
        elif len(word) > config.max_length:
            rejected["long"] += 1
        elif word in accepted:
            rejected["duplicate"] += 1
        else:
            accepted.add(word)
    words = sorted(accepted)
    lengths = Counter(len(word) for word in words)
    return {
        "words": words,
        "counts": {
            "source_entries": source_count,
            "normalized_forms": len(words),
            "by_length": {str(length): lengths[length] for length in sorted(lengths)},
            "rejected": dict(sorted(rejected.items())),
        },
        "annotation": {
            "status": "pending_T-0122",
            "proper_name_and_abbreviation_metadata": "absent_from_flat_source",
            "verified_lemma_count": 0,
            "verified_level_candidate_count": 0,
        },
    }
