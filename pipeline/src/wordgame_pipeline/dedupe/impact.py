"""Per-identity diagnostic view over authoritative duplicate conflicts."""

from collections import Counter, defaultdict
from dataclasses import dataclass

from ..config import LanguageConfig
from .core import DuplicatePolicy, audit_duplicates
from .summary import REASONS


@dataclass(frozen=True)
class ConflictImpact:
    candidate_id: str
    conflicting_pairs: int
    reasons: tuple[str, ...]


def rank_conflict_impact(
    records: list | tuple, policy: DuplicatePolicy, config: LanguageConfig
) -> tuple[ConflictImpact, ...]:
    """Return impacted identities; never drop or resequence candidates."""
    counts: Counter[str] = Counter()
    reasons: dict[str, set[str]] = defaultdict(set)
    for conflict in audit_duplicates(records, policy, config):
        for identity in (conflict.left_id, conflict.right_id):
            counts[identity] += 1
            reasons[identity].update(conflict.reasons)
    return tuple(
        sorted(
            (
                ConflictImpact(
                    identity,
                    count,
                    tuple(reason for reason in REASONS if reason in reasons[identity]),
                )
                for identity, count in counts.items()
            ),
            key=lambda row: (-row.conflicting_pairs, row.candidate_id),
        )
    )
