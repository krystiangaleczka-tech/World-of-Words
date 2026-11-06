"""Pure tier assignment difference evidence; never apply an override."""

from collections import Counter
from collections.abc import Mapping
from dataclasses import dataclass

from .core import TIERS


@dataclass(frozen=True)
class TierTransition:
    previous: str
    proposed: str
    count: int


@dataclass(frozen=True)
class TierTransitionReport:
    words: int
    changed: int
    transitions: tuple[TierTransition, ...]


def compare_tiers(before: Mapping, after: Mapping) -> TierTransitionReport:
    """Compare exact word-to-tier assignments with no source inference."""
    if not isinstance(before, Mapping) or not isinstance(after, Mapping):
        raise ValueError("Expected explicit tier mappings")
    if set(before) != set(after):
        raise ValueError("Tier sets must contain identical word identities")
    if any(
        not isinstance(word, str)
        or not word
        or before[word] not in TIERS
        or after[word] not in TIERS
        for word in before
    ):
        raise ValueError("Invalid tier word identity or classification")
    counts: Counter[tuple[str, str]] = Counter(
        (before[word], after[word]) for word in before if before[word] != after[word]
    )
    return TierTransitionReport(
        len(before),
        sum(counts.values()),
        tuple(TierTransition(old, new, count) for (old, new), count in sorted(counts.items())),
    )
