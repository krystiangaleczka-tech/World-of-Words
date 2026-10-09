"""P1 tiers retain pins and provenance through the existing atomic stage runner."""

import hashlib
from dataclasses import asdict
from pathlib import Path

from ..annotate.sources import load_pin as annotation_pin
from ..config import LanguageConfig, TierRules, canonical_bytes
from ..ingest.source import load_pin as source_pin
from ..stages import StageHandler
from .core import assign_tiers, parse_overrides


def handlers_for(root: Path) -> dict[str, StageHandler]:
    def tiers(config: LanguageConfig, previous: object) -> object:
        if (
            not isinstance(previous, dict)
            or previous.get("source") != source_pin(root).to_dict()
            or previous.get("annotation_sources") != annotation_pin(root)
        ):
            raise ValueError("Tiers require pinned SJP and annotation provenance")
        raw = (root / "overrides" / f"{config.lang}.csv").read_bytes()
        overrides = parse_overrides(raw.decode("utf-8"), config)
        rules = asdict(config.tier_rules or TierRules())
        return {
            "source": previous["source"],
            "annotation_sources": previous["annotation_sources"],
            "tier_rules": rules,
            "tier_rules_sha256": hashlib.sha256(canonical_bytes(rules)).hexdigest(),
            "overrides_sha256": hashlib.sha256(raw).hexdigest(),
            **assign_tiers(previous.get("records"), config, overrides),
        }

    return {"tiers": tiers}
