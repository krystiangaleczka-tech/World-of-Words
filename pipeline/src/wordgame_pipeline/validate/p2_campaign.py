"""Read-only P2 combined campaign gate; never emits release approval."""

from collections.abc import Mapping
from pathlib import Path

from ..candidates.core import WordIndex
from ..config import LanguageConfig
from ..dedupe import DuplicatePolicy
from ..dedupe.campaign import audit_campaign_diversity, require_campaign_diversity
from ..sequence.slots import SlotPlan
from .compact import load_compact_tokens, validate_compact_grid
from .core import validate_level
from .difficulty import validate_difficulty_window
from .locks import ReleaseLock, verify_release_lock
from .schema import SchemaRegistry


def validate_p2_campaign(
    levels: list[dict] | tuple[dict, ...],
    index: WordIndex,
    registry: SchemaRegistry,
    language: LanguageConfig,
    plan: SlotPlan,
    seed_words: Mapping[int, str],
    policy: DuplicatePolicy,
    *,
    tokens_path: Path,
    compact_area_width: float,
    compact_area_height: float,
    compact_body_height: float,
    max_deviation: float,
    lock: ReleaseLock | None,
    require_lock: bool,
) -> None:
    """Enforce real source words, layout, curve, diversity, and released geometry.

    Compact sizes must come from measured reference-screen geometry. The token
    values are always parsed from the canonical Godot source, never copied here.
    Passing this gate is necessary but does not constitute human approval.
    """
    if (
        not isinstance(levels, (list, tuple))
        or not isinstance(index, WordIndex)
        or not isinstance(registry, SchemaRegistry)
        or not isinstance(language, LanguageConfig)
        or not isinstance(plan, SlotPlan)
        or type(require_lock) is not bool
        or (lock is not None and not isinstance(lock, ReleaseLock))
    ):
        raise ValueError("Invalid P2 campaign validation inputs")
    if require_lock and lock is None:
        raise ValueError("P2 publication requires an explicit released-prefix lock")
    if len(levels) != plan.total or any(
        type(level.get("slot")) is not int or level["slot"] != i
        for i, level in enumerate(levels, 1)
    ):
        raise ValueError("P2 campaign order must exactly match the planned slots")

    tokens = load_compact_tokens(tokens_path)
    for level in levels:
        validate_level(level, index, registry)
        validate_compact_grid(
            level["grid"],
            area_width=compact_area_width,
            area_height=compact_area_height,
            body_height=compact_body_height,
            tokens=tokens,
        )
    validate_difficulty_window(levels, plan, max_deviation=max_deviation)
    require_campaign_diversity(audit_campaign_diversity(levels, seed_words, language, policy))

    if plan.released and (lock is None or len(plan.released) != len(lock.levels)):
        raise ValueError("Released slot reservations require the exact prefix lock")
    if lock is not None:
        verify_release_lock(lock, levels)
