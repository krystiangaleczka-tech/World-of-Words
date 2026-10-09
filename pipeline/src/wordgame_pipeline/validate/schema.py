"""Offline assertions for the repository's finite schema vocabulary, not general Draft."""

import math
import re
from pathlib import Path
from urllib.parse import urldefrag

from ..config import parse_json

ANNOTATIONS = {"$schema", "$id", "$defs", "title", "description"}
KEYWORDS = {
    "type",
    "enum",
    "const",
    "required",
    "properties",
    "additionalProperties",
    "items",
    "minItems",
    "maxItems",
    "uniqueItems",
    "minLength",
    "maxLength",
    "pattern",
    "minimum",
    "maximum",
    "allOf",
    "if",
    "then",
}
TYPES = {"object", "array", "string", "integer", "number", "boolean", "null"}


def equal(left: object, right: object) -> bool:
    if type(left) is bool or type(right) is bool:
        return type(left) is type(right) and left == right
    if isinstance(left, dict) and isinstance(right, dict):
        return left.keys() == right.keys() and all(equal(left[k], right[k]) for k in left)
    if isinstance(left, list) and isinstance(right, list):
        return len(left) == len(right) and all(
            equal(a, b) for a, b in zip(left, right, strict=True)
        )
    return left == right


def schema_errors(value: object, schema: dict | bool, path: str = "$") -> list[str]:
    if type(schema) is bool:
        return [] if schema else [f"{path}: forbidden value"]
    numeric = type(value) is int or (type(value) is float and math.isfinite(value))
    matches = {
        "object": isinstance(value, dict),
        "array": isinstance(value, list),
        "string": isinstance(value, str),
        "number": numeric,
        "integer": numeric and (type(value) is int or value.is_integer()),
        "boolean": type(value) is bool,
        "null": value is None,
    }
    if "type" in schema and not matches[schema["type"]]:
        return [f"{path}: expected {schema['type']}"]
    errors: list[str] = []
    if "const" in schema and not equal(value, schema["const"]):
        errors.append(f"{path}: wrong constant")
    if "enum" in schema and not any(equal(value, v) for v in schema["enum"]):
        errors.append(f"{path}: value outside enum")
    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{path}.{key}: required")
        for key, item in value.items():
            child = schema.get("properties", {}).get(key, schema.get("additionalProperties", True))
            errors.extend(schema_errors(item, child, f"{path}.{key}"))
    if isinstance(value, list):
        if not schema.get("minItems", 0) <= len(value) <= schema.get("maxItems", math.inf):
            errors.append(f"{path}: array length out of bounds")
        if schema.get("uniqueItems") and any(
            any(equal(item, prior) for prior in value[:i]) for i, item in enumerate(value)
        ):
            errors.append(f"{path}: duplicate array item")
        for i, item in enumerate(value):
            errors.extend(schema_errors(item, schema.get("items", True), f"{path}[{i}]"))
    if isinstance(value, str):
        if not schema.get("minLength", 0) <= len(value) <= schema.get("maxLength", math.inf):
            errors.append(f"{path}: string length out of bounds")
        if "pattern" in schema and re.search(schema["pattern"], value) is None:
            errors.append(f"{path}: pattern mismatch")
    if numeric and not schema.get("minimum", -math.inf) <= value <= schema.get("maximum", math.inf):
        errors.append(f"{path}: number out of bounds")
    for child in schema.get("allOf", []):
        errors.extend(schema_errors(value, child, path))
    if "if" in schema and not schema_errors(value, schema["if"], path):
        errors.extend(schema_errors(value, schema.get("then", True), path))
    return errors


class Schemas:
    def __init__(self, directory: Path) -> None:
        raw = {
            name: (directory / f"{name}.schema.json").read_bytes()
            for name in ("level", "pack", "manifest")
        }
        self.raw = raw
        documents = {name: parse_json(data.decode("utf-8")) for name, data in raw.items()}
        if any(
            not isinstance(d, dict) or not isinstance(d.get("$id"), str) for d in documents.values()
        ):
            raise ValueError("Invalid registered schema document")
        registered = {d["$id"]: d for d in documents.values()}
        if len(registered) != len(documents):
            raise ValueError("Duplicate schema identifier")

        def resolve(node: object, document: dict, active: tuple[str, ...] = ()) -> dict | bool:
            if type(node) is bool:
                return node
            if not isinstance(node, dict):
                raise ValueError("Schema node must be an object or boolean")
            if "$ref" in node:
                reference = node["$ref"]
                if set(node) != {"$ref"} or not isinstance(reference, str):
                    raise ValueError("Unsupported reference shape")
                uri, fragment = urldefrag(reference)
                identity = (uri or document["$id"]) + "#" + fragment
                if identity in active or (fragment and not fragment.startswith("/")):
                    raise ValueError("Cyclic or unsupported schema reference")
                target_document = registered.get(uri) if uri else document
                if target_document is None:
                    raise ValueError("Unregistered schema reference")
                target = target_document
                try:
                    for part in fragment[1:].split("/") if fragment else ():
                        target = target[part.replace("~1", "/").replace("~0", "~")]
                except (KeyError, TypeError) as exc:
                    raise ValueError("Unresolved schema reference") from exc
                return resolve(target, target_document, (*active, identity))
            unknown = set(node) - KEYWORDS - ANNOTATIONS
            if unknown:
                raise ValueError(f"Unsupported schema keywords: {', '.join(sorted(unknown))}")
            if "type" in node and node["type"] not in TYPES:
                raise ValueError("Unsupported schema type")
            result = dict(node)
            for key in ("properties", "$defs"):
                if key in node:
                    result[key] = {k: resolve(v, document, active) for k, v in node[key].items()}
            for key in ("items", "additionalProperties", "if", "then"):
                if key in node:
                    result[key] = resolve(node[key], document, active)
            if "allOf" in node:
                result["allOf"] = [resolve(v, document, active) for v in node["allOf"]]
            return result

        self.documents = {name: resolve(d, d) for name, d in documents.items()}

    def validate(self, name: str, value: object) -> None:
        errors = schema_errors(value, self.documents[name])
        if errors:
            raise ValueError("Schema validation: " + "; ".join(errors))
