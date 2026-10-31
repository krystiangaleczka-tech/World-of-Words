"""Read-only tier reason distribution and explicit override review inventory."""

from collections import Counter
from collections.abc import Mapping
from dataclasses import dataclass

from ..config import LanguageConfig
from .core import TIERS, valid_word

REASONS = frozenset(
    (
        "banned_label",
        "proper_name_or_abbreviation",
        "common_base",
        "common_inflection",
        "missing_lemma",
        "rare_or_missing_frequency",
        "override",
    )
)


@dataclass(frozen=True)
class TierReasonCount:
    tier: str
    reason: str
    count: int


@dataclass(frozen=True)
class TierReasonReview:
    total: int
    reasons: tuple[TierReasonCount, ...]
    override_words: tuple[str, ...]


def review_tier_reasons(records: list | tuple, config: LanguageConfig) -> TierReasonReview:
    """Summarize evidence without accepting or editing override decisions."""
    if not isinstance(records, (list, tuple)) or not isinstance(config, LanguageConfig):
        raise ValueError("Expected explicit classified records and language config")
    seen: set[str] = set()
    reasons: Counter[tuple[str, str]] = Counter()
    overridden = []
    for record in records:
        if not isinstance(record, Mapping):
            raise ValueError("Expected classified word mapping")
        word, tier, reason = (
            record.get("word"),
            record.get("tier"),
            record.get("tier_reason"),
        )
        if (
            not valid_word(word, config)
            or word in seen
            or not isinstance(tier, str)
            or tier not in TIERS
            or not isinstance(reason, str)
            or reason not in REASONS
        ):
            raise ValueError("Invalid classified word or evidence reason")
        seen.add(word)
        reasons[(tier, reason)] += 1
        if reason == "override":
            overridden.append(word)
    return TierReasonReview(
        len(seen),
        tuple(
            TierReasonCount(tier, reason, reasons[(tier, reason)])
            for tier in TIERS
            for reason in sorted(key[1] for key in reasons if key[0] == tier)
        ),
        tuple(sorted(overridden)),
    )
