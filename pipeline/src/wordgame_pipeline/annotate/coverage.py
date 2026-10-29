"""Audit exact-form ARF coverage before difficulty scoring and human QA."""

import math
from collections.abc import Mapping
from dataclasses import dataclass

from ..config import LanguageConfig
from ..tiers.core import valid_word
from .frequency import Frequency


@dataclass(frozen=True)
class ArfCoverage:
    selected_count: int
    available_count: int
    missing_words: tuple[str, ...]
    zero_arf_words: tuple[str, ...]
    low_arf_words: tuple[str, ...]


def audit_arf_coverage(
    words: tuple[str, ...],
    evidence: Mapping[str, Frequency | None],
    config: LanguageConfig,
    *,
    low_arf: float,
) -> ArfCoverage:
    """Missing, known zero and known low-frequency forms stay distinct."""
    if type(low_arf) not in (int, float):
        raise ValueError("Explicit ARF review threshold must be numeric")
    try:
        cutoff = float(low_arf)
    except OverflowError as exc:
        raise ValueError("ARF threshold cannot overflow") from exc
    if not math.isfinite(cutoff) or cutoff < 0:
        raise ValueError("ARF threshold must be finite nonnegative")
    if (
        not isinstance(config, LanguageConfig)
        or not isinstance(words, tuple)
        or any(not valid_word(word, config) for word in words)
        or len(set(words)) != len(words)
        or not isinstance(evidence, Mapping)
        or set(evidence) != set(words)
    ):
        raise ValueError("Expected distinct normalized words with exact evidence keys")
    missing = []
    zeros = []
    low = []
    for word in sorted(words):
        value = evidence[word]
        if value is None:
            missing.append(word)
            continue
        if not isinstance(value, Frequency):
            raise ValueError("Expected exact Frequency records or None")
        if any(
            type(number) not in (int, float)
            or not math.isfinite(number)
            or number < 0
            for number in (value.arf, value.ipm)
        ):
            raise ValueError("Frequency metrics must be finite nonnegative")
        if value.arf == 0:
            zeros.append(word)
        if value.arf <= cutoff:
            low.append(word)
    return ArfCoverage(
        len(words), len(words) - len(missing), tuple(missing), tuple(zeros), tuple(low)
    )
