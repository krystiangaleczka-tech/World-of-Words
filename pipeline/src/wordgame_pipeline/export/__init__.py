"""Deterministic P1 sequencing and schema-validated export documents."""

import hashlib
from pathlib import Path

from .. import __version__
from ..candidates.core import WordIndex
from ..config import LanguageConfig, canonical_bytes
from ..stages import P1_STAGES, StageHandler, read_artifact
from ..validate import SchemaRegistry, validate_level
from ..validate import handlers_for as validation_handlers


def assemble(
    previous: dict, slots: int, version: int, index: WordIndex, registry: SchemaRegistry
) -> dict:
    if type(slots) is not int or not 15 <= slots <= 9999:
        raise ValueError("Export slots must be an integer from 15 to 9999")
    if type(version) is not int or version < 1:
        raise ValueError("Export content version must be a positive integer")
    authored = {entry["slot"]: entry for entry in previous["handmade"]}
    if len(authored) != len(previous["handmade"]):
        raise ValueError("Duplicate handmade slot")
    if any(slot not in authored for slot in range(1, 16)):
        raise ValueError("Export requires handmade onboarding slots 1–15 (T-0130/T-0131)")
    if any(slot > slots for slot in authored):
        raise ValueError("Export would omit a handmade slot")
    if any(len(authored[slot]["letters"]) > 7 for slot in range(1, 16)):
        raise ValueError("Onboarding cannot contain landmarks")
    candidates = sorted(
        (entry for entry in previous["automatic"] if len(entry["letters"]) <= 7),
        key=lambda entry: (len(entry["letters"]), entry["candidate_id"]),
    )
    if len({e["candidate_id"] for e in previous["automatic"]}) != len(previous["automatic"]):
        raise ValueError("Duplicate automatic identity")
    last_word: dict[str, int] = {}
    used: set[str] = set()
    tile_count = 3
    levels: list[dict] = []

    def allowed(entry: dict, slot: int) -> bool:
        return all(slot - last_word.get(word, -100) >= 100 for word in entry["words"]) and all(
            not set(entry["words"]).intersection(future["words"])
            for pinned, future in authored.items()
            if slot < pinned < slot + 100
        )

    for slot in range(1, slots + 1):
        handmade = slot in authored
        if handmade:
            entry = authored[slot]
            if not allowed(entry, slot):
                raise ValueError(f"Handmade word spacing conflict at slot {slot}")
        else:
            entry = next(
                (
                    candidate
                    for candidate in candidates
                    if candidate["candidate_id"] not in used
                    and len(candidate["letters"]) >= tile_count
                    and allowed(candidate, slot)
                ),
                None,
            )
            if entry is None:
                raise ValueError(f"No eligible automatic candidate at slot {slot}")
            used.add(entry["candidate_id"])
            tile_count = len(entry["letters"])
        level = {
            "id": f"pl-c-{slot:06d}",
            "slot": slot,
            "letters": entry["letters"],
            "words": sorted(entry["placements"], key=lambda p: p["w"]),
            "bonus": entry["bonus"],
            "grid": entry["grid"],
            "difficulty": 0.0,
            "landmark": handmade and len(entry["letters"]) == 8,
            "source": "handmade" if handmade else "generated",
            "seed": entry["seed"],
            "pipeline": __version__,
        }
        validate_level(level, index, registry)
        levels.append(level)
        last_word.update(dict.fromkeys(entry["words"], slot))
    files: dict[str, dict] = {}
    packs: list[dict] = []
    for offset in range(0, slots, 100):
        first, last = offset + 1, min(offset + 100, slots)
        name = f"packs/c-{first:04d}-{last:04d}.json"
        pack = {
            "schema_version": 1,
            "lang": "pl",
            "kind": "campaign",
            "levels": levels[offset:last],
        }
        registry.validate_schema("pack", pack)
        files[name] = pack
        packs.append(
            {
                "file": name,
                "kind": "campaign",
                "first": first,
                "last": last,
                "sha256": hashlib.sha256(canonical_bytes(pack)).hexdigest(),
            }
        )
    manifest = {
        "schema_version": 1,
        "lang": "pl",
        "content_version": version,
        "pipeline": __version__,
        "slots": slots,
        "packs": packs,
    }
    registry.validate_schema("manifest", manifest)
    files["manifest.json"] = manifest
    return {"options": {"slots": slots, "content_version": version}, "files": files}


def handlers_for(root: Path, slots: int, version: int) -> dict[str, StageHandler]:
    def export(config: LanguageConfig, previous: object) -> object:
        checked = validation_handlers(root)["validate"](config, previous)
        if not isinstance(previous, dict) or previous.get("validation") != checked["validation"]:
            raise ValueError("Stale validation evidence; rebuild validate")
        tiers, _raw = read_artifact(root, config, next(s for s in P1_STAGES if s.name == "tiers"))
        return assemble(
            checked, slots, version, WordIndex(tiers["records"], config), SchemaRegistry(root)
        )

    return {"export": export}
