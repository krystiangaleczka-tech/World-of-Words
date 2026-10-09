"""Build the reviewed P1 campaign; replay compact native inputs offline in CI."""

import argparse
import csv
import sys
from pathlib import Path

from . import __version__
from .candidates import handlers_for as candidate_handlers
from .candidates.core import WordIndex
from .candidates.handmade import load_handmade
from .config import LanguageConfig, canonical_bytes, load_config, parse_json
from .content import digest, provenance, validate_content
from .export import assemble
from .export import handlers_for as export_handlers
from .export.publish import publish
from .grid import handlers_for as grid_handlers
from .stages import P1_STAGES, _write_atomic, read_artifact, run_build
from .validate import SchemaRegistry, validate_grid_entry
from .validate import handlers_for as validation_handlers


def read_json(path: Path) -> dict:
    raw = path.read_bytes()
    data = parse_json(raw.decode("utf-8"))
    if not isinstance(data, dict) or raw != canonical_bytes(data):
        raise ValueError(f"Expected canonical JSON object: {path}")
    return data


def plan_for(root: Path) -> dict:
    plan = read_json(root / "config/p1-pl.json")
    if (
        set(plan) != {"slots", "content_version", "selection"}
        or type(plan["slots"]) is not int
        or not 45 <= plan["slots"] <= 65
        or type(plan["content_version"]) is not int
        or plan["content_version"] < 1
        or plan["selection"] != "reviewed_answers"
    ):
        raise ValueError("Invalid P1 campaign plan")
    return plan


def reviewed_answers(root: Path, authored: list[dict]) -> set[str]:
    with (root / "reviews/pl/T-0129-words.csv").open(encoding="utf-8", newline="") as stream:
        approved = {row["word"] for row in csv.DictReader(stream) if row["decision"] == "level_ok"}
    return approved | {word for entry in authored for word in entry["words"]}


def inputs_identity(
    root: Path, config: LanguageConfig, plan: dict, registry: SchemaRegistry
) -> dict:
    return {
        "schema_version": 1,
        "pipeline": __version__,
        **provenance(root, config),
        "plan_sha256": digest(canonical_bytes(plan)),
        "review_sha256": digest((root / "reviews/pl/T-0129-words.csv").read_bytes()),
        "schema_sha256": {name: digest(raw) for name, raw in registry.raw.items()},
    }


def replay(root: Path, receipt: dict) -> dict:
    """Rebuild actual grids/export from generated source extracts, never game JSON."""
    config = load_config(root, "pl")
    plan = plan_for(root)
    registry = SchemaRegistry(root)
    expected = inputs_identity(root, config, plan, registry)
    if set(receipt) != set(expected) | {"tiers_sha256", "records", "candidates"} or any(
        receipt.get(k) != v for k, v in expected.items()
    ):
        raise ValueError("Stale P1 input provenance")
    evidence = read_json(root / "content-evidence/pl.json")
    if receipt["tiers_sha256"] != evidence["tiers_sha256"]:
        raise ValueError("P1 input/evidence tier hashes differ")
    index = WordIndex(receipt["records"], config)
    authored, handmade_hash = load_handmade(root, index)
    candidates = receipt["candidates"]
    metadata = {k: v for k, v in provenance(root, config).items() if k != "config_sha256"}
    metadata["handmade_sha256"] = handmade_hash
    if (
        not isinstance(candidates, dict)
        or set(candidates) != set(metadata) | {"automatic", "handmade"}
        or any(candidates.get(k) != v for k, v in metadata.items())
        or candidates["handmade"] != authored
        or not isinstance(candidates["automatic"], list)
    ):
        raise ValueError("Stale P1 candidate inputs")
    approved = reviewed_answers(root, authored)
    ids = []
    for entry in candidates["automatic"]:
        if not isinstance(entry, dict) or set(entry) != {
            "id",
            "letters",
            "seeds",
            "level_ok",
            "bonus_ok",
        }:
            raise ValueError("Invalid P1 candidate")
        letters = entry["letters"]
        pools = index.pools(letters)
        identity = "pl-auto-" + "".join(sorted(letters))
        seeds = [w for w in pools["level_ok"] if sorted(w) == letters]
        if (
            letters != sorted(letters)
            or len(letters) > 7
            or entry["id"] != identity
            or not seeds
            or entry["seeds"] != seeds
            or any(entry[k] != v for k, v in pools.items())
            or not set(pools["level_ok"]) <= approved
        ):
            raise ValueError("Invalid reviewed candidate pools")
        ids.append(identity)
    if ids != sorted(set(ids)):
        raise ValueError("P1 candidate identities must be sorted and unique")
    grids = grid_handlers(root)["grid"](config, candidates)
    for key in ("automatic", "handmade"):
        for entry in grids[key]:
            validate_grid_entry(entry, index, registry, key == "handmade")
    return assemble(grids, plan["slots"], plan["content_version"], index, registry)


def check(root: Path, content: Path) -> int:
    receipt = read_json(root / "content-inputs/pl.json")
    payload = replay(root, receipt)
    publish(payload, content / "pl", SchemaRegistry(root), check=True)
    if (content / "NOTICE").read_bytes() != (root.parent / "NOTICE").read_bytes():
        raise ValueError("Generated source attribution differs")
    count = validate_content(root, load_config(root, "pl"), content)
    if count != payload["options"]["slots"]:
        raise ValueError("Campaign missing")
    return count


def build(root: Path, content: Path) -> int:
    config = load_config(root, "pl")
    plan = plan_for(root)

    def candidates(current_config: LanguageConfig, previous: object) -> dict:
        result = candidate_handlers(root)["candidates"](current_config, previous)
        approved = reviewed_answers(root, result["handmade"])
        result["automatic"] = [
            entry
            for entry in result["automatic"]
            if len(entry["letters"]) <= 7 and set(entry["level_ok"]) <= approved
        ]
        return result

    handlers = {
        "candidates": candidates,
        **grid_handlers(root),
        **validation_handlers(root),
        **export_handlers(root, plan["slots"], plan["content_version"]),
    }
    paths = run_build(root, config, handlers, "candidates", "export")
    payload, _ = read_artifact(root, config, P1_STAGES[-1])
    registry = SchemaRegistry(root)
    # Native runner already revalidates full tiers before publication.
    publish(payload, content / "pl", registry)
    validate_content(root, config, content, prepare=True)
    source_candidates, _ = read_artifact(
        root, config, next(s for s in P1_STAGES if s.name == "candidates")
    )
    tiers, raw = read_artifact(root, config, next(s for s in P1_STAGES if s.name == "tiers"))
    index = WordIndex(tiers["records"], config)
    words = set()
    for key in ("automatic", "handmade"):
        for entry in source_candidates[key]:
            pools = index.pools(entry["letters"])
            words.update(pools["level_ok"])
            words.update(pools["bonus_ok"])
    receipt = {
        **inputs_identity(root, config, plan, registry),
        "tiers_sha256": digest(raw),
        "records": [{"word": w, "tier": index.tiers[w]} for w in sorted(words)],
        "candidates": source_candidates,
    }
    # All compact inputs are extracted from real canonical native artifacts.
    _write_atomic(root / "content-inputs/pl.json", canonical_bytes(receipt))
    _write_atomic(content / "NOTICE", (root.parent / "NOTICE").read_bytes())
    count = check(root, content)
    print("Native stages: " + ", ".join(str(p.relative_to(root)) for p in paths))
    return count


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("pipeline"))
    parser.add_argument("--content-root", type=Path, default=Path("game/content"))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    try:
        count = (check if args.check else build)(args.root, args.content_root)
    except (ValueError, OSError, KeyError) as exc:
        print(f"P1 campaign: {exc}", file=sys.stderr)
        return 1
    print(f"OK: {count} PL levels; deterministic P1 campaign")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
