"""Pure SGJP interpretation mapping, with an injected analyzer for offline tests."""

import unicodedata
from collections.abc import Mapping
from typing import Protocol

from ..config import LanguageConfig, canonical_bytes
from .frequency import Frequency

Interpretation = tuple[int, int, tuple[str, str, str, list[str], list[str]]]


class Analyzer(Protocol):
    version: str
    dictionary_id: str

    def analyse(self, word: str) -> list[Interpretation]: ...


def annotate_words(
    words: list[str],
    config: LanguageConfig,
    analyzer: Analyzer,
    form_frequency: Mapping[str, Frequency],
    lemma_frequency: Mapping[tuple[str, str], Frequency],
) -> dict[str, object]:
    if words != sorted(set(words)) or any(
        not config.min_length <= len(word) <= config.max_length
        or word != unicodedata.normalize("NFC", word)
        or any(letter not in config.alphabet for letter in word)
        for word in words
    ):
        raise ValueError("Annotation requires normalized sorted unique source forms")
    records: list[dict[str, object]] = []
    known = 0
    frequency_known = 0
    lemmas: set[str] = set()
    for word in words:
        unique: dict[bytes, dict[str, object]] = {}
        for start, end, interpretation in analyzer.analyse(word.lower()):
            orth, lemma_raw, tag, names, labels = interpretation
            if start != 0 or end <= start or unicodedata.normalize("NFC", orth).upper() != word:
                continue
            pos = tag.split(":", 1)[0]
            lemma = unicodedata.normalize("NFC", lemma_raw.split(":", 1)[0]).upper()
            if pos == "ign" or not lemma or any(letter not in config.alphabet for letter in lemma):
                continue
            lemma_metric = lemma_frequency.get((lemma.lower(), pos))
            analysis = {
                "lemma": lemma,
                "lemma_raw": lemma_raw,
                "pos": pos,
                "tag": tag,
                "names": sorted(set(names)),
                "labels": sorted(set(labels)),
                "is_inflected": lemma != word,
                "frequency": lemma_metric.to_dict() if lemma_metric is not None else None,
            }
            unique[canonical_bytes(analysis)] = analysis
        analyses = [unique[key] for key in sorted(unique)]
        metric = form_frequency.get(word.lower())
        known += bool(analyses)
        frequency_known += metric is not None
        lemmas.update(analysis["lemma"] for analysis in analyses)
        records.append(
            {
                "word": word,
                "analyses": analyses,
                "frequency": metric.to_dict() if metric is not None else None,
                "has_lemma_evidence": bool(analyses),
            }
        )
    return {
        "records": records,
        "coverage": {
            "source_forms": len(words),
            "forms_with_lemma": known,
            "forms_with_frequency": frequency_known,
            "unique_lemmas": len(lemmas),
        },
    }
