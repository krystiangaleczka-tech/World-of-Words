"""Fail-closed publisher validation for T-0257 remote config v1.

The game runtime remains tolerant of unknown remote fields, but a hosted document
must contain only approved, valid overrides to prevent shipping silent mistakes.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

VERSION = 1
MAX_EXPERIMENTS = 32
MAX_VARIANTS = 100
MAX_BYTES = 65536
EXPERIMENT_ID = re.compile(r"[a-z][a-z0-9_]{0,39}\Z")


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def reject_constant(value: str) -> None:
    raise ValueError(f"non-JSON numeric constant: {value}")


def read_json(path: Path, limit: int = MAX_BYTES) -> Any:
    data = path.read_bytes()
    if len(data) > limit:
        raise ValueError(f"file exceeds {limit} bytes")
    return json.loads(
        data.decode("utf-8"),
        object_pairs_hook=unique_object,
        parse_constant=reject_constant,
    )


def load_definitions(directory: Path) -> dict[str, dict[str, Any]]:
    if not directory.is_dir():
        raise ValueError(f"missing config registry directory: {directory}")
    definitions: dict[str, dict[str, Any]] = {}
    files = sorted(directory.glob("*.json"))
    if not files:
        raise ValueError("no config registry JSON files")
    for path in files:
        document = read_json(path)
        if not isinstance(document, dict):
            raise ValueError(f"{path}: registry must be an object")
        for key, definition in document.items():
            if key in definitions:
                raise ValueError(f"duplicate registry key: {key}")
            if not isinstance(definition, dict):
                raise ValueError(f"{path}: invalid registry entry {key}")
            definitions[key] = definition
    return definitions


def _valid_value(value: Any, definition: dict[str, Any]) -> bool:
    kind = definition.get("type")
    expected = {
        "int": int,
        "float": float,
        "bool": bool,
        "string": str,
    }.get(kind)
    if expected is None or type(value) is not expected:
        return False
    bounds = definition.get("range")
    if kind in ("int", "float"):
        if not math.isfinite(value) or abs(value) > 9007199254740991:
            return False
        return isinstance(bounds, list) and len(bounds) == 2 and bounds[0] <= value <= bounds[1]
    return bounds is None


def validate_document(document: Any, definitions: dict[str, dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    if not isinstance(document, dict):
        return ["remote config must be an object"]
    fields = {"version", "values", "experiments"}
    if set(document) != fields:
        return ["remote config requires only version, values and experiments"]
    if type(document["version"]) is not int or document["version"] != VERSION:
        errors.append("version must equal integer 1")
    values = document["values"]
    if not isinstance(values, dict):
        errors.append("values must be an object")
    else:
        for key, value in values.items():
            definition = definitions.get(key)
            if definition is None:
                errors.append(f"unknown override: {key}")
            elif definition.get("remote") is not True:
                errors.append(f"key is not remotely tunable: {key}")
            elif not _valid_value(value, definition):
                errors.append(f"invalid type or range: {key}")
    experiments = document["experiments"]
    if not isinstance(experiments, list):
        errors.append("experiments must be an array")
        return errors
    if len(experiments) > MAX_EXPERIMENTS:
        errors.append(f"too many experiments: max {MAX_EXPERIMENTS}")
    experiment_ids: set[str] = set()
    for index, experiment in enumerate(experiments):
        label = f"experiments[{index}]"
        if not isinstance(experiment, dict) or set(experiment) != {"id", "variants"}:
            errors.append(f"{label}: expected id and variants")
            continue
        name = experiment["id"]
        if not isinstance(name, str) or EXPERIMENT_ID.fullmatch(name) is None:
            errors.append(f"{label}: invalid experiment id for analytics buckets")
        elif name in experiment_ids:
            errors.append(f"{label}: duplicate experiment id {name}")
        else:
            experiment_ids.add(name)
        variants = experiment["variants"]
        if not isinstance(variants, list) or not 1 <= len(variants) <= MAX_VARIANTS:
            errors.append(f"{label}: variants must be a 1..{MAX_VARIANTS} array")
            continue
        total = 0
        variant_ids: set[str] = set()
        for variant_index, variant in enumerate(variants):
            where = f"{label}.variants[{variant_index}]"
            if not isinstance(variant, dict) or set(variant) != {"id", "weight"}:
                errors.append(f"{where}: expected id and weight")
                continue
            variant_id = variant["id"]
            weight = variant["weight"]
            if not isinstance(variant_id, str) or not variant_id:
                errors.append(f"{where}: id must be a nonempty string")
            elif variant_id in variant_ids:
                errors.append(f"{where}: duplicate variant id {variant_id}")
            else:
                variant_ids.add(variant_id)
            if type(weight) is not int or not 1 <= weight <= 100:
                errors.append(f"{where}: weight must be an integer in 1..100")
            else:
                total += weight
        if total != 100:
            errors.append(f"{label}: variant weights must total 100, got {total}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("remote/config.json"))
    parser.add_argument("--registry-dir", type=Path, default=Path("game/data/config"))
    args = parser.parse_args(argv)
    try:
        document = read_json(args.config)
        definitions = load_definitions(args.registry_dir)
        errors = validate_document(document, definitions)
    except (OSError, UnicodeError, ValueError, TypeError) as exc:
        errors = [str(exc)]
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("OK: remote/config.json matches safe remote config v1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
