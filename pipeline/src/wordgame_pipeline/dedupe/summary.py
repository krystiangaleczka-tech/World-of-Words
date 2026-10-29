"""Deterministic summary of exact pairwise content conflicts."""

from dataclasses import dataclass

from ..config import LanguageConfig
from .core import DuplicatePolicy, audit_duplicates

REASONS = ("letter_multiset", "word_jaccard", "word_spacing", "seed_spacing")


@dataclass(frozen=True)
class ConflictSummary:
    compared_pairs: int
    conflicting_pairs: int
    by_reason: tuple[tuple[str, int], ...]
    affected_ids: tuple[str, ...]
    highest_jaccard: float


def summarize_duplicate_conflicts(
    records: list | tuple,
    policy: DuplicatePolicy,
    config: LanguageConfig,
) -> ConflictSummary:
    """Analyze all supplied records; no automatic filtering or selection."""
    conflicts = audit_duplicates(records, policy, config)
    counts = {reason: 0 for reason in REASONS}
    affected: set[str] = set()
    for conflict in conflicts:
        affected.update((conflict.left_id, conflict.right_id))
        for reason in conflict.reasons:
            counts[reason] += 1
    return ConflictSummary(
        len(records) * (len(records) - 1) // 2,
        len(conflicts),
        tuple((reason, counts[reason]) for reason in REASONS),
        tuple(sorted(affected)),
        max((conflict.jaccard for conflict in conflicts), default=0.0),
    )
