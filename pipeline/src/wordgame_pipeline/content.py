"""Read-only shipped-content gates backed by compact generated tier evidence."""

import hashlib
import stat
from dataclasses import asdict
from pathlib import Path

from . import __version__
from .annotate.sources import load_pin as annotation_pin
from .candidates.core import WordIndex
from .candidates.handmade import load_handmade
from .config import LanguageConfig, TierRules, canonical_bytes, parse_json
from .ingest.source import load_pin as source_pin
from .stages import P1_STAGES, _write_atomic, read_artifact
from .validate import SchemaRegistry, validate_level


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def provenance(root: Path, config: LanguageConfig) -> dict:
    rules = parse_json(canonical_bytes(asdict(config.tier_rules or TierRules())).decode())
    return {
        "source": source_pin(root).to_dict(),
        "annotation_sources": annotation_pin(root),
        "tier_rules": rules,
        "tier_rules_sha256": digest(canonical_bytes(rules)),
        "overrides_sha256": digest((root / "overrides/pl.csv").read_bytes()),
        "config_sha256": digest(canonical_bytes(config.to_dict())),
    }


def bundle(directory: Path, registry: SchemaRegistry) -> tuple[list[dict], bytes]:
    paths = [directory, *directory.parents, *directory.rglob("*")]
    if any(p.is_symlink() for p in paths):
        raise ValueError("Content cannot use symlinks")
    for path in directory.rglob("*"):
        mode = path.stat().st_mode
        if not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)):
            raise ValueError("Unmanaged special content file")
    raw = (directory / "manifest.json").read_bytes()
    manifest = parse_json(raw.decode("utf-8"))
    registry.validate_schema("manifest", manifest)
    if canonical_bytes(manifest) != raw:
        raise ValueError("Manifest must be canonical JSON")
    expected = {"manifest.json"} | {p["file"] for p in manifest["packs"]}
    actual = {p.relative_to(directory).as_posix() for p in directory.rglob("*") if p.is_file()}
    if actual != expected or any(
        p.is_dir() and p.relative_to(directory).as_posix() != "packs" for p in directory.rglob("*")
    ):
        raise ValueError("Missing or unmanaged content files")
    levels: list[dict] = []
    next_slot = 1
    for entry in manifest["packs"]:
        first, last = entry["first"], entry["last"]
        if (
            first != next_slot
            or last < first
            or last > 9999
            or entry["file"] != f"packs/c-{first:04d}-{last:04d}.json"
        ):
            raise ValueError("Invalid campaign pack ranges")
        data = (directory / entry["file"]).read_bytes()
        if digest(data) != entry["sha256"].lower():
            raise ValueError("Pack hash mismatch")
        pack = parse_json(data.decode("utf-8"))
        registry.validate_schema("pack", pack)
        if canonical_bytes(pack) != data or pack["kind"] != "campaign":
            raise ValueError("Pack must be canonical campaign JSON")
        if len(pack["levels"]) != last - first + 1:
            raise ValueError("Pack level count mismatch")
        for level in pack["levels"]:
            if level["slot"] != next_slot or level["id"] != f"pl-c-{next_slot:06d}":
                raise ValueError("Campaign identity/slot mismatch")
            if level["pipeline"] != manifest["pipeline"]:
                raise ValueError("Manifest/level pipeline mismatch")
            next_slot += 1
            levels.append(level)
    if next_slot != manifest["slots"] + 1:
        raise ValueError("Manifest slot count mismatch")
    return levels, raw


def validate_levels(levels: list[dict], index: WordIndex, registry: SchemaRegistry) -> None:
    last: dict[str, int] = {}
    tiles = 3
    if len(levels) < 15:
        raise ValueError("P1 requires handmade onboarding slots 1–15")
    for level in levels:
        validate_level(level, index, registry)
        slot = level["slot"]
        if level["landmark"] != (level["source"] == "handmade" and len(level["letters"]) == 8):
            raise ValueError("P1 landmark requires exactly eight handmade tiles")
        if level["difficulty"] != 0.0:
            raise ValueError("P1 difficulty must be 0.0")
        if slot <= 15 and (level["source"] != "handmade" or level["landmark"]):
            raise ValueError("P1 onboarding must be handmade without landmarks")
        if level["source"] == "generated":
            count = len(level["letters"])
            if not tiles <= count <= 7 or level["landmark"]:
                raise ValueError("P1 automatic wheel size/order mismatch")
            tiles = count
        for placement in level["words"]:
            word = placement["w"]
            if slot - last.get(word, -100) < 100:
                raise ValueError(f"Crossword word spacing conflict at slot {slot}")
            last[word] = slot


def validate_content(
    root: Path, config: LanguageConfig, content_root: Path, *, prepare: bool = False
) -> int | None:
    directory = content_root / config.lang
    evidence_path = root / "content-evidence" / f"{config.lang}.json"
    if evidence_path.is_symlink() or any(p.is_symlink() for p in evidence_path.parents):
        raise ValueError("Evidence cannot use symlinks")
    if evidence_path.exists() and not evidence_path.is_file():
        raise ValueError("Evidence must be a regular file")
    if not directory.exists() and not directory.is_symlink() and not evidence_path.exists():
        if prepare:
            raise ValueError("Cannot prepare evidence without content")
        return None
    registry = SchemaRegistry(root)
    levels, manifest_raw = bundle(directory, registry)
    expected = provenance(root, config)
    if prepare:
        tiers, _raw = read_artifact(root, config, next(s for s in P1_STAGES if s.name == "tiers"))
        if not isinstance(tiers, dict) or any(
            tiers.get(k) != v for k, v in expected.items() if k != "config_sha256"
        ):
            raise ValueError("Stale tier provenance")
        full_index = WordIndex(tiers.get("records"), config)
        words = set()
        for level in levels:
            pools = full_index.pools(level["letters"])
            words.update(pools["level_ok"])
            words.update(pools["bonus_ok"])
        records = [{"word": w, "tier": full_index.tiers[w]} for w in sorted(words)]
        index = WordIndex(records, config)
        _authored, handmade_hash = load_handmade(root, full_index)
        evidence = {
            "schema_version": 1,
            "lang": config.lang,
            "pipeline": __version__,
            **expected,
            "handmade_sha256": handmade_hash,
            "manifest_sha256": digest(manifest_raw),
            "tiers_sha256": digest(_raw),
            "records": records,
        }
    else:
        if evidence_path.is_symlink() or any(p.is_symlink() for p in evidence_path.parents):
            raise ValueError("Evidence cannot use symlinks")
        evidence_raw = evidence_path.read_bytes()
        evidence = parse_json(evidence_raw.decode("utf-8"))
        keys = set(expected) | {
            "schema_version",
            "lang",
            "pipeline",
            "handmade_sha256",
            "manifest_sha256",
            "tiers_sha256",
            "records",
        }
        if not isinstance(evidence, dict) or set(evidence) != keys:
            raise ValueError("Invalid content evidence fields")
        if canonical_bytes(evidence) != evidence_raw:
            raise ValueError("Content evidence must be canonical JSON")
        if (
            type(evidence["schema_version"]) is not int
            or evidence["schema_version"] != 1
            or evidence["lang"] != config.lang
            or evidence["pipeline"] != __version__
            or any(evidence.get(k) != v for k, v in expected.items())
            or evidence["manifest_sha256"] != digest(manifest_raw)
        ):
            raise ValueError("Stale content evidence provenance")
        tier_hash = evidence["tiers_sha256"]
        if (
            not isinstance(tier_hash, str)
            or len(tier_hash) != 64
            or any(c not in "0123456789abcdef" for c in tier_hash)
        ):
            raise ValueError("Invalid tier artifact hash")
        index = WordIndex(evidence["records"], config)
        _authored, handmade_hash = load_handmade(root, index)
    authored_by_slot = {e["slot"]: e for e in _authored}
    shipped_handmade = {e["slot"]: e for e in levels if e["source"] == "handmade"}
    if set(authored_by_slot) != set(shipped_handmade):
        raise ValueError("Handmade slot membership changed")
    for slot, authored in authored_by_slot.items():
        level = shipped_handmade[slot]
        if (
            level["letters"] != authored["letters"]
            or level["bonus"] != authored["bonus"]
            or sorted(p["w"] for p in level["words"]) != authored["words"]
        ):
            raise ValueError("Handmade intent changed")
        if "grid" in authored:
            from .grid.geometry import normalize

            layout = normalize(tuple((p["w"], p["x"], p["y"], p["dir"]) for p in authored["grid"]))
            actual = tuple(sorted((p["w"], p["x"], p["y"], p["dir"]) for p in level["words"]))
            if layout != actual:
                raise ValueError("Explicit handmade layout changed")
    if evidence["handmade_sha256"] != handmade_hash:
        raise ValueError("Stale handmade evidence")
    validate_levels(levels, index, registry)
    if prepare:
        _write_atomic(evidence_path, canonical_bytes(evidence))
    return len(levels)
