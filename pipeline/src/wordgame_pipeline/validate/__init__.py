"""Validate grid artifacts using the pinned authoritative tier index."""

import hashlib
from dataclasses import asdict
from pathlib import Path

from ..annotate.sources import load_pin as annotation_pin
from ..candidates.core import WordIndex
from ..candidates.handmade import load_handmade
from ..config import LanguageConfig, TierRules, canonical_bytes, parse_json
from ..grid.geometry import normalize
from ..ingest.source import load_pin as source_pin
from ..stages import P1_STAGES, StageHandler, read_artifact
from .core import validate_grid, validate_level
from .schema import Schemas

__all__ = ["handlers_for", "validate_grid", "validate_level", "Schemas"]


def handlers_for(root: Path) -> dict[str, StageHandler]:
    def validate(config: LanguageConfig, previous: object) -> object:
        tiers, _raw = read_artifact(root, config, next(s for s in P1_STAGES if s.name == "tiers"))
        rules = parse_json(
            canonical_bytes(asdict(config.tier_rules or TierRules())).decode("utf-8")
        )
        expected = {
            "source": source_pin(root).to_dict(),
            "annotation_sources": annotation_pin(root),
            "tier_rules": rules,
            "tier_rules_sha256": hashlib.sha256(canonical_bytes(rules)).hexdigest(),
            "overrides_sha256": hashlib.sha256(
                (root / "overrides" / f"{config.lang}.csv").read_bytes()
            ).hexdigest(),
        }
        if (
            not isinstance(previous, dict)
            or not isinstance(tiers, dict)
            or any(previous.get(k) != v or tiers.get(k) != v for k, v in expected.items())
        ):
            raise ValueError("Validation requires current pinned tier/grid provenance")
        index = WordIndex(tiers.get("records"), config)
        authored, digest = load_handmade(root, index)
        if previous.get("handmade_sha256") != digest:
            raise ValueError("Stale handmade input provenance")
        schemas = Schemas(root / "schema")
        counts: dict[str, int] = {}
        for key in ("automatic", "handmade"):
            levels = previous.get(key)
            if not isinstance(levels, list):
                raise ValueError("Malformed validation collection")
            seen: set[str | int] = set()
            for level in levels:
                validate_grid(level, index, schemas, key == "handmade")
                identity = level["slot" if key == "handmade" else "candidate_id"]
                if identity in seen:
                    raise ValueError("Duplicate grid identity")
                seen.add(identity)
            counts[key] = len(levels)
        authored_by_slot = {entry["slot"]: entry for entry in authored}
        if {level["slot"] for level in previous["handmade"]} != set(authored_by_slot):
            raise ValueError("Handmade slot membership changed")
        for level in previous["handmade"]:
            entry = authored_by_slot[level["slot"]]
            if any(level[k] != entry[k] for k in ("letters", "words", "bonus", "expect_bonus")):
                raise ValueError("Handmade intent changed")
            if "grid" in entry:
                explicit = normalize(
                    tuple((p["w"], p["x"], p["y"], p["dir"]) for p in entry["grid"])
                )
                actual = tuple(
                    sorted((p["w"], p["x"], p["y"], p["dir"]) for p in level["placements"])
                )
                if explicit != actual:
                    raise ValueError("Explicit handmade layout changed")
        return {
            **previous,
            "validation": {
                "counts": counts,
                "schema_sha256": {
                    name: hashlib.sha256(raw).hexdigest() for name, raw in schemas.raw.items()
                },
            },
        }

    return {"validate": validate}
