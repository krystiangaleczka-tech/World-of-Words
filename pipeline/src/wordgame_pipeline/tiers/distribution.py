"""Compare explicit tier snapshots without changing a single word classification."""

from collections import Counter
from dataclasses import dataclass

from ..config import LanguageConfig
from .core import TIERS, valid_word


@dataclass(frozen=True)
class TierChange:
    word: str
    previous: str
    proposed: str


@dataclass(frozen=True)
class TierDistributionDiff:
    counts_before: tuple[tuple[str, int], ...]
    counts_after: tuple[tuple[str, int], ...]
    changes: tuple[TierChange, ...]


def _snapshot(records: list, config: LanguageConfig) -> dict[str, str]:
    if not isinstance(records, list):
        raise ValueError("Expected list of tier records")
    result = {}
    for row in records:
        if (
            not isinstance(row, dict)
            or set(row) != {"word", "tier"}
            or not valid_word(row["word"], config)
            or row["tier"] not in TIERS
            or row["word"] in result
        ):
            raise ValueError("Invalid or duplicate tier evidence")
        result[row["word"]] = row["tier"]
    return result


def compare_tier_distributions(
    previous: list, proposed: list, config: LanguageConfig
) -> TierDistributionDiff:
    """Require unchanged vocabulary; changes are human-review evidence only."""
    if not isinstance(config, LanguageConfig):
        raise ValueError("Expected explicit language rules")
    before = _snapshot(previous, config)
    after = _snapshot(proposed, config)
    if set(before) != set(after):
        raise ValueError("Tier comparison cannot add or remove words")
    a, b = Counter(before.values()), Counter(after.values())
    return TierDistributionDiff(
        tuple((tier, a[tier]) for tier in TIERS),
        tuple((tier, b[tier]) for tier in TIERS),
        tuple(
            TierChange(word, before[word], after[word])
            for word in sorted(before)
            if before[word] != after[word]
        ),
    )
