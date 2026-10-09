"""Grid construction retains source identity and complete unselected bonuses."""

import hashlib
from collections import Counter
from dataclasses import asdict
from pathlib import Path

from ..annotate.sources import load_pin as annotation_pin
from ..config import LanguageConfig
from ..ingest.source import load_pin as source_pin
from ..stages import StageHandler
from ..tiers.core import valid_word
from .builder import SearchOptions, build_grid
from .geometry import Placement, normalize, validate_geometry


def make_level(entry: dict, config: LanguageConfig, handmade: bool) -> dict[str, object]:
    letters = entry.get("letters")
    if (
        not isinstance(letters, list)
        or not config.min_length <= len(letters) <= config.max_length
        or any(not isinstance(c, str) or len(c) != 1 or c not in config.alphabet for c in letters)
    ):
        raise ValueError("Invalid grid wheel")
    words = entry.get("words" if handmade else "level_ok")
    bonus = entry.get("bonus" if handmade else "bonus_ok")
    for pool in (words, bonus):
        if (
            not isinstance(pool, list)
            or any(not valid_word(w, config) for w in pool)
            or len(set(pool)) != len(pool)
            or any(not Counter(w) <= Counter(letters) for w in pool)
        ):
            raise ValueError("Malformed grid word pool")
    if not words or set(words) & set(bonus):
        raise ValueError("Invalid grid tier pools")
    identity = str(entry.get("slot")) if handmade else entry.get("id")
    if not isinstance(identity, str) or not identity:
        raise ValueError("Invalid candidate identity")
    seed = int.from_bytes(hashlib.sha256(identity.encode("utf-8")).digest()[:8], "big")
    if handmade:
        required = sorted(words)[0]
    else:
        seeds = entry.get("seeds")
        if not isinstance(seeds, list) or not seeds or any(w not in words for w in seeds):
            raise ValueError("Invalid candidate seed words")
        required = sorted(seeds)[0]
    if handmade and "grid" in entry:
        raw = entry["grid"]
        if not isinstance(raw, list) or any(
            not isinstance(p, dict) or set(p) != {"w", "x", "y", "dir"} for p in raw
        ):
            raise ValueError("Malformed explicit grid")
        layout: tuple[Placement, ...] = tuple((p["w"], p["x"], p["y"], p["dir"]) for p in raw)
        # Validate shapes before normalizing an authoring landscape.
        for w, x, y, d in layout:
            if (
                w not in words
                or type(x) is not int
                or type(y) is not int
                or not 0 <= x <= 9
                or not 0 <= y <= 9
                or d not in ("h", "v")
            ):
                raise ValueError("Malformed explicit placement")
        if not layout:
            raise ValueError("Empty explicit grid")
        layout = normalize(layout)
    else:
        layout = build_grid(tuple(words), required, seed, require_all=handmade)
    selected = sorted(p[0] for p in layout)
    dimensions = validate_geometry(layout, tuple(words if handmade else selected))
    result = {
        "letters": letters,
        "words": selected,
        "placements": [{"w": w, "x": x, "y": y, "dir": d} for w, x, y, d in layout],
        "grid": dimensions,
        "bonus": sorted((set(words) | set(bonus)) - set(selected)),
        "seed": seed,
    }
    if handmade:
        if type(entry.get("slot")) is not int or entry["slot"] < 1:
            raise ValueError("Invalid handmade slot")
        expected = entry.get("expect_bonus", [])
        if not isinstance(expected, list) or any(w not in result["bonus"] for w in expected):
            raise ValueError("Invalid handmade expected bonus")
        result.update(slot=entry["slot"], expect_bonus=expected)
    else:
        result["candidate_id"] = identity
    return result


def handlers_for(root: Path) -> dict[str, StageHandler]:
    def grid(config: LanguageConfig, previous: object) -> object:
        if (
            not isinstance(previous, dict)
            or previous.get("source") != source_pin(root).to_dict()
            or previous.get("annotation_sources") != annotation_pin(root)
        ):
            raise ValueError("Grid requires pinned candidate provenance")
        collections = {}
        for key in ("automatic", "handmade"):
            values = previous.get(key)
            if not isinstance(values, list) or any(not isinstance(v, dict) for v in values):
                raise ValueError("Malformed candidate collection")
            collections[key] = [make_level(v, config, key == "handmade") for v in values]
        return {
            **{
                key: previous[key]
                for key in (
                    "source",
                    "annotation_sources",
                    "tier_rules",
                    "tier_rules_sha256",
                    "overrides_sha256",
                    "handmade_sha256",
                )
            },
            "search_options": asdict(SearchOptions()),
            **collections,
        }

    return {"grid": grid}
