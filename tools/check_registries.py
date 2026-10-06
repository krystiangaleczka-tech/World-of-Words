"""Validate shipped registries and literal autoload calls without running Godot.

The schema evaluator supports the repository's v1 schema vocabulary only; new
assertion keywords fail closed rather than silently weakening validation.
"""

from __future__ import annotations

import argparse
import ast
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

from gdtoolkit.parser import parser as gd_parser
from lark import Tree
from lark.exceptions import LarkError

ANNOTATIONS = {"$schema", "$id", "description", "title"}
KEYWORDS = {
    "type",
    "const",
    "enum",
    "properties",
    "required",
    "additionalProperties",
    "propertyNames",
    "minProperties",
    "minLength",
    "pattern",
    "minimum",
    "maximum",
    "items",
    "minItems",
    "maxItems",
    "allOf",
    "if",
    "then",
}
TYPES = {"get_int": "int", "get_float": "float", "get_bool": "bool", "get_string": "string"}


def schema_errors(value: Any, schema: dict[str, Any], location: str = "$") -> list[str]:
    """Evaluate the assertions present in the checked-in v1 schemas."""
    errors: list[str] = []
    numeric = type(value) in (int, float) and math.isfinite(value)
    matches = {
        "object": isinstance(value, dict),
        "array": isinstance(value, list),
        "string": isinstance(value, str),
        "boolean": type(value) is bool,
        "null": value is None,
        "number": numeric,
        "integer": numeric and int(value) == value,
    }
    if "type" in schema and not matches.get(schema["type"], False):
        return [f"{location}: expected {schema['type']}"]
    if "const" in schema and (type(value) is not type(schema["const"]) or value != schema["const"]):
        errors.append(f"{location}: expected {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{location}: value outside enum")
    if isinstance(value, dict):
        if len(value) < schema.get("minProperties", 0):
            errors.append(f"{location}: too few properties")
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{location}: missing {key}")
        properties = schema.get("properties", {})
        additional = schema.get("additionalProperties", True)
        for key, item in value.items():
            if "propertyNames" in schema:
                errors.extend(schema_errors(key, schema["propertyNames"], f"{location}.{key}"))
            child = properties.get(key, additional)
            if child is False:
                errors.append(f"{location}.{key}: unknown property")
            elif isinstance(child, dict):
                errors.extend(schema_errors(item, child, f"{location}.{key}"))
    if isinstance(value, list):
        if not schema.get("minItems", 0) <= len(value) <= schema.get("maxItems", math.inf):
            errors.append(f"{location}: invalid array length")
        for index, item in enumerate(value):
            errors.extend(schema_errors(item, schema.get("items", {}), f"{location}[{index}]"))
    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0):
            errors.append(f"{location}: string too short")
        if "pattern" in schema and re.search(schema["pattern"], value) is None:
            errors.append(f"{location}: invalid name or blank text")
    if numeric and not schema.get("minimum", -math.inf) <= value <= schema.get("maximum", math.inf):
        errors.append(f"{location}: number outside bounds")
    for child in schema.get("allOf", []):
        errors.extend(schema_errors(value, child, location))
    if "if" in schema and not schema_errors(value, schema["if"], location):
        errors.extend(schema_errors(value, schema.get("then", {}), location))
    return errors


def check_schema(schema: Any) -> None:
    if not isinstance(schema, dict):
        raise ValueError("schema must be an object")
    unknown = schema.keys() - KEYWORDS - ANNOTATIONS
    if unknown:
        raise ValueError(f"unsupported schema keywords: {', '.join(sorted(unknown))}")
    children = list(schema.get("properties", {}).values())
    children.extend(schema.get("allOf", []))
    for key in ("additionalProperties", "propertyNames", "items", "if", "then"):
        if isinstance(schema.get(key), dict):
            children.append(schema[key])
    for child in children:
        check_schema(child)


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def reject_constant(value: str) -> None:
    raise ValueError(f"non-JSON numeric constant {value}")


def read_json(path: Path) -> Any:
    return json.loads(
        path.read_text(encoding="utf-8"),
        object_pairs_hook=unique_object,
        parse_constant=reject_constant,
    )


def load_registry(root: Path, area: str) -> tuple[dict[str, Any], list[str]]:
    registry: dict[str, Any] = {}
    errors: list[str] = []
    schema_path = root / "game/services" / area / "registry.schema.json"
    try:
        schema = read_json(schema_path)
        check_schema(schema)
    except (OSError, ValueError, TypeError) as exc:
        return {}, [f"{schema_path.relative_to(root)}: {exc}"]
    files = sorted((root / "game/data" / area).glob("*.json"))
    if not files:
        errors.append(f"game/data/{area}: no registry JSON files")
    for path in files:
        label = path.relative_to(root).as_posix()
        try:
            document = read_json(path)
            invalid = schema_errors(document, schema)
            if invalid:
                errors.extend(f"{label}: {error}" for error in invalid)
                continue
            for name, entry in document.items():
                if name in registry:
                    errors.append(f"{label}: duplicate registry name {name!r}")
                if area == "config":
                    if name.split(".")[0] != path.stem:
                        errors.append(f"{label}: {name!r} has wrong filename prefix")
                    for field in ("owner", "description"):
                        if not entry[field].strip():
                            errors.append(f"{label}: {name}.{field} is blank")
                    if entry["type"] in ("int", "float"):
                        low, high = entry["range"]
                        if not low <= entry["default"] <= high:
                            errors.append(f"{label}: {name} default outside ordered range")
                    if name.split(".")[0] in ("unlocks", "consent") and entry["remote"]:
                        errors.append(f"{label}: {name} cannot be remote")
                registry[name] = entry
        except (OSError, ValueError, TypeError, OverflowError) as exc:
            errors.append(f"{label}: {exc}")
    return registry, errors


def literal(node: Any) -> str | None:
    if isinstance(node, Tree) and node.data in ("expr", "string_name") and len(node.children) == 1:
        return literal(node.children[0])
    if isinstance(node, Tree) and node.data == "string":
        value = ast.literal_eval(str(node.children[0]))
        return value if isinstance(value, str) else None
    return None


def scan_calls(
    root: Path, config: dict[str, Any], analytics: dict[str, Any]
) -> tuple[list[str], int]:
    errors: list[str] = []
    dynamic = 0
    for path in sorted((root / "game").rglob("*.gd")):
        if set(path.relative_to(root / "game").parts[:-1]) & {"addons", "tests", ".godot"}:
            continue
        label = path.relative_to(root).as_posix()
        try:
            tree = gd_parser.parse(path.read_text(encoding="utf-8"), gather_metadata=True)
            for call in tree.find_data("getattr_call"):
                target = call.children[0]
                if not isinstance(target, Tree) or target.data != "getattr":
                    continue
                parts = [str(item) for item in target.children]
                if len(parts) != 3:
                    continue
                service, _, method = parts
                if not (
                    (service == "Config" and method in TYPES)
                    or (service == "Analytics" and method == "track")
                ):
                    continue
                name = literal(call.children[1]) if len(call.children) > 1 else None
                if name is None:
                    dynamic += 1
                    continue
                entries = config if service == "Config" else analytics
                location = f"{label}:{call.meta.line}"
                if name not in entries:
                    errors.append(f"{location}: unregistered {service}.{method} literal {name!r}")
                elif service == "Config" and entries[name]["type"] != TYPES[method]:
                    errors.append(f"{location}: {name!r} has wrong type for Config.{method}")
        except (OSError, ValueError, SyntaxError, LarkError) as exc:
            errors.append(f"{label}: cannot parse source: {exc}")
    return errors, dynamic


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args(argv)
    root = args.root.resolve()
    config, config_errors = load_registry(root, "config")
    analytics, analytics_errors = load_registry(root, "analytics")
    errors = config_errors + analytics_errors
    dynamic = 0
    if not errors:
        call_errors, dynamic = scan_calls(root, config, analytics)
        errors.extend(call_errors)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(
        f"OK: registries: {len(config)} config keys, {len(analytics)} events; "
        f"{dynamic} dynamic calls checked at runtime"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
