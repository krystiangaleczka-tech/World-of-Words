"""Full Draft 2020-12 validation with registered local resources only."""

import math
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError
from referencing import Registry, Resource
from referencing.exceptions import NoSuchResource, Unresolvable

from ..config import parse_json

DIALECT = "https://json-schema.org/draft/2020-12/schema"


def json_value(value: object, path: str = "$", active: frozenset[int] = frozenset()) -> None:
    """Programmatic callers must supply finite JSON values, including in unknown fields."""
    if value is None or type(value) in (bool, int, str):
        return
    if type(value) is float and math.isfinite(value):
        return
    if type(value) not in (dict, list):
        raise ValueError(f"{path}: expected a finite JSON value")
    if id(value) in active:
        raise ValueError(f"{path}: cyclic JSON container")
    nested = active | {id(value)}
    if isinstance(value, dict):
        if any(not isinstance(key, str) for key in value):
            raise ValueError(f"{path}: JSON object keys must be strings")
        children = value.items()
    else:
        children = enumerate(value)
    for key, item in children:
        json_value(item, f"{path}/{key}", nested)


def local_only(uri: str) -> Resource:
    raise NoSuchResource(ref=uri)


def validate_with(validator: Draft202012Validator, value: object, prefix: str = "$") -> None:
    json_value(value, prefix)
    try:
        errors = sorted(
            validator.iter_errors(value),
            key=lambda error: (tuple(str(p) for p in error.absolute_path), error.message),
        )
    except (Unresolvable, RecursionError) as exc:
        raise ValueError(f"{prefix}: unresolved or cyclic local schema reference") from exc
    if errors:
        error = errors[0]
        path = prefix + "".join(f"/{part}" for part in error.absolute_path)
        raise ValueError(f"Schema validation {path}: {error.message}")


class SchemaRegistry:
    def __init__(self, root: Path) -> None:
        self.raw = {
            name: (root / "schema" / f"{name}.schema.json").read_bytes()
            for name in ("level", "pack", "manifest")
        }
        self.documents = {name: parse_json(raw.decode("utf-8")) for name, raw in self.raw.items()}
        identifiers: set[str] = set()
        for name, document in self.documents.items():
            json_value(document)
            if (
                not isinstance(document, dict)
                or document.get("$schema") != DIALECT
                or not isinstance(document.get("$id"), str)
                or document["$id"] in identifiers
            ):
                raise ValueError(f"{name}: invalid or duplicate schema identity/dialect")
            identifiers.add(document["$id"])
            try:
                Draft202012Validator.check_schema(document)
            except SchemaError as exc:
                raise ValueError(f"{name}: invalid Draft 2020-12 schema: {exc.message}") from exc
        registry = Registry(retrieve=local_only).with_resources(
            (document["$id"], Resource.from_contents(document))
            for document in self.documents.values()
        )
        self.validators = {
            name: Draft202012Validator(document, registry=registry)
            for name, document in self.documents.items()
        }

    def validate_schema(self, name: str, document: object) -> None:
        if name not in self.validators:
            raise ValueError(f"Unknown registered schema: {name}")
        validate_with(self.validators[name], document)

    def validate_fragment(self, name: str, field: str, document: object) -> None:
        if name not in self.validators or field not in self.documents[name]["properties"]:
            raise ValueError("Unknown registered schema property")
        # Evolving the validator retains its local root resource and reference resolver.
        validator = self.validators[name].evolve(schema=self.documents[name]["properties"][field])
        validate_with(validator, document, f"$/{field}")
