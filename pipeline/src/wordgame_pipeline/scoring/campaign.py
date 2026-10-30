"""Score validated campaign slots using explicit, never inferred scoring weights."""

from collections.abc import Mapping, Sequence
from dataclasses import dataclass

from ..config import LanguageConfig
from .features import extract_features
from .model import ScoringConfig, score_features


@dataclass(frozen=True)
class CampaignDifficulty:
    slot: int
    level_id: str
    score: float
    scoring_sha256: str
    contributions: tuple[tuple[str, float], ...]


def score_campaign(
    levels: Sequence[Mapping],
    frequencies: Mapping[str, float | None],
    language: LanguageConfig,
    scoring: ScoringConfig,
) -> tuple[CampaignDifficulty, ...]:
    """Read-only P2 scoring. Caller must separately validate tier and content locks."""
    if (
        not isinstance(levels, (list, tuple))
        or not levels
        or not isinstance(frequencies, Mapping)
        or not isinstance(language, LanguageConfig)
        or not isinstance(scoring, ScoringConfig)
    ):
        raise ValueError("Expected nonempty levels, source frequency map and explicit configs")
    indexed = {}
    for level in levels:
        if not isinstance(level, Mapping):
            raise ValueError("Invalid campaign level")
        slot = level.get("slot")
        if (
            type(slot) is not int
            or slot < 1
            or slot in indexed
            or level.get("id") != f"pl-c-{slot:06d}"
        ):
            raise ValueError("Duplicate or invalid campaign identity")
        indexed[slot] = level
    if sorted(indexed) != list(range(1, len(indexed) + 1)):
        raise ValueError("Campaign scoring requires a contiguous prefix")
    result = []
    for slot in sorted(indexed):
        level = indexed[slot]
        placements = level.get("words")
        if not isinstance(placements, list) or not placements:
            raise ValueError("Missing selected crossword words")
        try:
            words = {entry["w"] for entry in placements}
        except (TypeError, KeyError) as exc:
            raise ValueError("Malformed selected crossword words") from exc
        if not words <= frequencies.keys():
            raise ValueError("Missing exact-form source frequency evidence")
        raw = extract_features(level, {word: frequencies[word] for word in words}, language)
        calculated = score_features(raw, scoring)
        result.append(
            CampaignDifficulty(
                slot,
                level["id"],
                calculated.total,
                calculated.config_sha256,
                tuple((item.name, item.contribution) for item in calculated.features),
            )
        )
    return tuple(result)
