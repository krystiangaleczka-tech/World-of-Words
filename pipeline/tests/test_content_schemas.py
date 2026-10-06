"""Contract cases for the shared schema vocabulary; no production content validator."""

from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
from typing import Any
from urllib.parse import urldefrag

import pytest

DIRECTORY = Path(__file__).resolve().parents[1] / "schema"
CHECKER_PATH = DIRECTORY.parents[1] / "tools/check_registries.py"
SPEC = importlib.util.spec_from_file_location("registry_contract_assertions", CHECKER_PATH)
assert SPEC is not None and SPEC.loader is not None
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)
ANNOTATIONS, KEYWORDS, schema_errors = CHECKER.ANNOTATIONS, CHECKER.KEYWORDS, CHECKER.schema_errors
SCHEMAS = {
    name: json.loads((DIRECTORY / f"{name}.schema.json").read_text(encoding="utf-8"))
    for name in ("level", "pack", "manifest")
}
REGISTERED = {schema["$id"]: schema for schema in SCHEMAS.values()}


def resolve(node: Any, document: dict[str, Any]) -> Any:
    """Expand only registered references; missing resources/keywords fail the suite."""
    if isinstance(node, list):
        return [resolve(item, document) for item in node]
    if not isinstance(node, dict):
        return node
    if "$ref" in node:
        assert set(node) == {"$ref"}, "This harness requires standalone references"
        uri, fragment = urldefrag(node["$ref"])
        target_document = REGISTERED[uri] if uri else document
        target: Any = target_document
        for part in fragment.lstrip("/").split("/") if fragment else []:
            target = target[part.replace("~1", "/").replace("~0", "~")]
        return resolve(target, target_document)
    result = {}
    for key, value in node.items():
        if key in ("properties", "$defs"):
            result[key] = {name: resolve(item, document) for name, item in value.items()}
        elif key in ("items", "if", "then", "additionalProperties", "propertyNames", "allOf"):
            result[key] = resolve(value, document)
        else:
            assert key in KEYWORDS | ANNOTATIONS | {"uniqueItems", "maxLength"}, (
                f"Unsupported keyword {key}"
            )
            result[key] = value
    return result


RESOLVED = {name: resolve(schema, schema) for name, schema in SCHEMAS.items()}


def json_numbers(value: Any) -> Any:
    # Draft const equality uses mathematical numbers; T-0039's evaluator is stricter.
    if type(value) is float and value.is_integer():
        return int(value)
    if isinstance(value, list):
        return [json_numbers(item) for item in value]
    if isinstance(value, dict):
        return {key: json_numbers(item) for key, item in value.items()}
    return value


def extra_errors(value: Any, schema: dict[str, Any]) -> list[str]:
    errors = []
    if isinstance(value, str) and len(value) > schema.get("maxLength", len(value)):
        errors.append("string too long")
    if isinstance(value, list):
        if schema.get("uniqueItems"):
            keys = [json.dumps(item, sort_keys=True, ensure_ascii=False) for item in value]
            if len(set(keys)) != len(keys):
                errors.append("duplicate array item")
        for item in value:
            errors.extend(extra_errors(item, schema.get("items", {})))
    if isinstance(value, dict):
        for key, item in value.items():
            child = schema.get("properties", {}).get(key, schema.get("additionalProperties", {}))
            if isinstance(child, dict):
                errors.extend(extra_errors(item, child))
    for child in schema.get("allOf", []):
        errors.extend(extra_errors(value, child))
    if "if" in schema and not schema_errors(value, schema["if"]):
        errors.extend(extra_errors(value, schema.get("then", {})))
    return errors


def errors(name: str, document: Any) -> list[str]:
    value = json_numbers(document)
    return schema_errors(value, RESOLVED[name]) + extra_errors(value, RESOLVED[name])


@pytest.fixture
def level() -> dict[str, Any]:
    return {
        "id": "pl-c-000001",
        "slot": 1,
        "letters": ["K", "O", "T"],
        "words": [{"w": "KOT", "x": 0, "y": 0, "dir": "h"}],
        "bonus": [],
        "grid": {"w": 3, "h": 1},
        "difficulty": 0,
        "landmark": False,
        "source": "handmade",
        "seed": 42,
        "pipeline": "0.1.0",
    }


@pytest.fixture
def manifest() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "lang": "pl",
        "content_version": 1,
        "pipeline": "0.1.0",
        "slots": 3,
        "packs": [
            {
                "file": "packs/c-0001-0003.json",
                "kind": "campaign",
                "first": 1,
                "last": 3,
                "sha256": "a" * 64,
            }
        ],
    }


def pack(level: dict[str, Any], kind: str = "campaign") -> dict[str, Any]:
    return {"schema_version": 1, "lang": "pl", "kind": kind, "levels": [level]}


def test_identifiers_dialect_and_offline_references() -> None:
    assert len(REGISTERED) == 3
    assert all(
        schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
        for schema in SCHEMAS.values()
    )
    assert SCHEMAS["pack"]["properties"]["levels"]["items"]["$ref"] == SCHEMAS["level"]["$id"]
    assert RESOLVED["pack"]["properties"]["levels"]["items"]["required"]
    with pytest.raises(KeyError):
        resolve({"$ref": "urn:missing"}, SCHEMAS["level"])


def test_campaign_daily_pack_and_minimal_manifest(level, manifest) -> None:
    assert not errors("level", level)
    assert not errors("pack", pack(level))
    assert not errors("manifest", manifest)
    manifest["daily"] = None
    assert not errors("manifest", manifest)
    level["id"] = "pl-d-000001"
    del level["slot"]
    assert not errors("level", level)
    assert not errors("pack", pack(level, "daily"))


def test_repeated_tiles_empty_bonus_and_integral_json_numbers(level) -> None:
    level.update(letters=["K", "O", "K"], slot=1.0, seed=-42, difficulty=0.5)
    assert not errors("level", level)
    document = pack(level)
    document["schema_version"] = 1.0
    assert not errors("pack", document)


@pytest.mark.parametrize(
    "version",
    ["0.0.0", "1.2.3", "1.0.0-alpha.1", "1.0.0-0", "1.0.0+build.001", "1.0.0-rc.2+build.01"],
)
def test_semver_release_prerelease_build(level, manifest, version) -> None:
    level["pipeline"] = manifest["pipeline"] = version
    assert not errors("level", level)
    assert not errors("manifest", manifest)


@pytest.mark.parametrize("version", ["v1.0.0", "1.0", "01.0.0", "1.0.0-01", "1.0.0-", "1.0.0+"])
def test_invalid_semver(level, version) -> None:
    level["pipeline"] = version
    assert errors("level", level)


@pytest.mark.parametrize(
    "field",
    [
        "id",
        "letters",
        "words",
        "bonus",
        "grid",
        "difficulty",
        "landmark",
        "source",
        "seed",
        "pipeline",
        "slot",
    ],
)
def test_required_level_fields(level, field) -> None:
    del level[field]
    assert errors("level", level)


@pytest.mark.parametrize("name", ["pl-x-000001", "en-c-000001", "pl-c-1", "pl-c-000001x"])
def test_level_id_kind_language_and_shape(level, name) -> None:
    level["id"] = name
    assert errors("level", level)


def test_daily_forbids_slot_and_level_forbids_version(level) -> None:
    level["id"] = "pl-d-000001"
    assert errors("level", level)
    del level["slot"]
    level["schema_version"] = 1
    assert errors("level", level)


@pytest.mark.parametrize(
    "field,value",
    [
        ("slot", 0),
        ("slot", True),
        ("slot", 1.5),
        ("letters", ["K", "O"]),
        ("letters", ["A"] * 9),
        ("letters", ["K", "O", "Q"]),
        ("letters", ["K", "o", "T"]),
        ("letters", ["K", "OT", "A"]),
        ("words", []),
        ("difficulty", "0"),
        ("difficulty", True),
        ("landmark", 1),
        ("source", "unknown"),
        ("seed", 1.5),
        ("seed", True),
        ("unknown", 1),
        ("bonus", ["KOT", "KOT"]),
        ("bonus", ["KO"]),
        ("bonus", ["kot"]),
    ],
)
def test_level_shape_and_primitive_boundaries(level, field, value) -> None:
    level[field] = value
    assert errors("level", level)


def test_landmark_eight_tile_boundary_and_polish_alphabet(level) -> None:
    level["letters"] = ["Ą", "Ć", "Ę", "Ł", "Ń", "Ó", "Ś", "Ź"]
    assert errors("level", level)
    level["landmark"] = True
    assert not errors("level", level)
    level["letters"][-1] = "Ż"
    assert not errors("level", level)


@pytest.mark.parametrize(
    "field,value",
    [
        ("w", "KO"),
        ("w", "kot"),
        ("w", "QAT"),
        ("w", "A" * 9),
        ("x", -1),
        ("x", 10),
        ("y", True),
        ("y", 1.5),
        ("dir", "diagonal"),
        ("extra", 0),
    ],
)
def test_placement_bounds_shape_and_unknown_fields(level, field, value) -> None:
    level["words"][0][field] = value
    assert errors("level", level)


@pytest.mark.parametrize("field", ["w", "x", "y", "dir"])
def test_required_placement_fields(level, field) -> None:
    del level["words"][0][field]
    assert errors("level", level)


@pytest.mark.parametrize(
    "grid",
    [
        {"w": 0, "h": 1},
        {"w": 11, "h": 1},
        {"w": 3, "h": True},
        {"w": 3},
        {"w": 3, "h": 1, "extra": 0},
    ],
)
def test_grid_bounds_and_shape(level, grid) -> None:
    level["grid"] = grid
    assert errors("level", level)


@pytest.mark.parametrize(
    "field,value",
    [
        ("schema_version", 2),
        ("schema_version", True),
        ("lang", "en"),
        ("kind", "other"),
        ("levels", []),
        ("extra", 0),
    ],
)
def test_pack_container_contract(level, field, value) -> None:
    document = pack(level)
    document[field] = value
    assert errors("pack", document)


@pytest.mark.parametrize("field", ["schema_version", "lang", "kind", "levels"])
def test_required_pack_fields(level, field) -> None:
    document = pack(level)
    del document[field]
    assert errors("pack", document)


def test_pack_kind_and_nested_level_validation(level) -> None:
    assert errors("pack", pack(level, "daily"))
    level["id"] = "pl-d-000001"
    del level["slot"]
    assert errors("pack", pack(level))
    level["grid"]["w"] = 0
    assert errors("pack", pack(level, "daily"))


@pytest.mark.parametrize(
    "field", ["schema_version", "lang", "content_version", "pipeline", "slots", "packs"]
)
def test_required_manifest_fields(manifest, field) -> None:
    del manifest[field]
    assert errors("manifest", manifest)


@pytest.mark.parametrize(
    "field,value",
    [
        ("schema_version", 0),
        ("schema_version", True),
        ("lang", "de"),
        ("content_version", 0),
        ("slots", 0),
        ("slots", True),
        ("slots", 1.5),
        ("packs", []),
        ("daily", {}),
        ("regions", []),
        ("locations", []),
        ("landmarks", []),
        ("extra", 1),
    ],
)
def test_manifest_version_types_and_p1_fields(manifest, field, value) -> None:
    manifest[field] = value
    assert errors("manifest", manifest)


@pytest.mark.parametrize(
    "field,value",
    [
        ("file", "../packs/c-0001-0003.json"),
        ("file", "/packs/c-0001-0003.json"),
        ("file", "packs/c-0001-0003.json/../../x"),
        ("file", "packs/d-0001-0003.json"),
        ("file", "packs\\c-0001-0003.json"),
        ("kind", "daily"),
        ("first", 0),
        ("last", True),
        ("sha256", "..."),
        ("sha256", "g" * 64),
        ("extra", 0),
    ],
)
def test_manifest_pack_paths_bounds_hashes(manifest, field, value) -> None:
    manifest["packs"][0][field] = value
    assert errors("manifest", manifest)


@pytest.mark.parametrize("field", ["file", "kind", "first", "last", "sha256"])
def test_required_manifest_pack_fields(manifest, field) -> None:
    del manifest["packs"][0][field]
    assert errors("manifest", manifest)


def test_schemas_do_not_claim_semantic_validation(level, manifest) -> None:
    # Valid shapes deliberately still require the future semantic content validator.
    level["words"][0].update(w="DOM", x=9)
    level["bonus"] = ["ODA", "DAM"]  # Neither formability nor sorting is a schema assertion.
    assert not errors("level", level)
    document = pack(level)
    document["levels"].append(copy.deepcopy(level))
    assert not errors("pack", document)  # Unique IDs/slots are semantic constraints.
    manifest["packs"][0].update(first=3, last=1)
    assert not errors("manifest", manifest)


def test_patterns_reject_trailing_newlines(level, manifest) -> None:
    for field in ("id", "pipeline"):
        invalid = copy.deepcopy(level)
        invalid[field] += "\n"
        assert errors("level", invalid)
    for field in ("file", "sha256"):
        invalid = copy.deepcopy(manifest)
        invalid["packs"][0][field] += "\n"
        assert errors("manifest", invalid)


@pytest.mark.parametrize("name", ["level", "pack", "manifest"])
@pytest.mark.parametrize("document", [None, [], True, 1])
def test_documents_require_object_roots(name, document) -> None:
    assert errors(name, document)
