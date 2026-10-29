"""Rank candidate identities by validated pairwise duplicate conflicts."""

from collections import defaultdict
from dataclasses import dataclass

from ..config import LanguageConfig
from .core import DuplicatePolicy, audit_duplicates


@dataclass(frozen=True)
class DuplicateHotspot:
    identity: str
    conflicting_peers: int
    reasons: tuple[str, ...]
    peers: tuple[str, ...]


def rank_duplicate_hotspots(
    records: list | tuple, policy: DuplicatePolicy, config: LanguageConfig
) -> tuple[DuplicateHotspot, ...]:
    """Count unique peers, not reasons, for each conflicting candidate."""
    peers: dict[str, set[str]] = defaultdict(set)
    causes: dict[str, set[str]] = defaultdict(set)
    for conflict in audit_duplicates(records, policy, config):
        a, b = conflict.left_id, conflict.right_id
        peers[a].add(b)
        peers[b].add(a)
        causes[a].update(conflict.reasons)
        causes[b].update(conflict.reasons)
    return tuple(
        sorted(
            (
                DuplicateHotspot(
                    identity,
                    len(others),
                    tuple(sorted(causes[identity])),
                    tuple(sorted(others)),
                )
                for identity, others in peers.items()
            ),
            key=lambda row: (-row.conflicting_peers, row.identity),
        )
    )
