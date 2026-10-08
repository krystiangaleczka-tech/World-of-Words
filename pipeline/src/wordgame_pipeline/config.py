"""Immutable language rules; v0 accepts the JSON-compatible subset of YAML."""

import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path


def _unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate key: {key}")
        result[key] = value
    return result


def parse_json(text: str) -> object:
    def reject_constant(value: str) -> None:
        raise ValueError(f"Non-finite JSON number: {value}")

    return json.loads(text, object_pairs_hook=_unique_object, parse_constant=reject_constant)


def canonical_bytes(value: object) -> bytes:
    if isinstance(value, dict):
        if any(not isinstance(key, str) for key in value):
            raise ValueError("JSON object keys must be strings")
        for item in value.values():
            canonical_bytes(item)
    elif isinstance(value, (list, tuple)):
        for item in value:
            canonical_bytes(item)
    return (
        json.dumps(
            value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False
        )
        + "\n"
    ).encode("utf-8")


@dataclass(frozen=True)
class LanguageConfig:
    lang: str
    alphabet: str
    min_length: int
    max_length: int

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


def load_config(root: Path, lang: str) -> LanguageConfig:
    if not re.fullmatch(r"[a-z]{2}", lang) or lang != "pl":
        raise ValueError(f"Unsupported language: {lang}")
    path = root / "config" / f"{lang}.yaml"
    try:
        data = parse_json(path.read_text(encoding="utf-8"))
    except ValueError as exc:
        raise ValueError(f"{path}: expected JSON-compatible YAML: {exc}") from exc
    if not isinstance(data, dict) or set(data) != {"lang", "alphabet", "min_length", "max_length"}:
        raise ValueError("Language config must contain lang, alphabet, min_length, max_length")
    alphabet = data["alphabet"]
    if data["lang"] != lang or not isinstance(alphabet, str):
        raise ValueError("Language config identity/alphabet mismatch")
    if len(alphabet) != 32 or len(set(alphabet)) != 32 or alphabet != alphabet.upper():
        raise ValueError("PL requires 32 distinct uppercase letters")
    if set(alphabet) != set("AĄBCĆDEĘFGHIJKLŁMNŃOÓPRSŚTUWYZŹŻ"):
        raise ValueError("PL alphabet must match decision 0004")
    if type(data["min_length"]) is not int or type(data["max_length"]) is not int:
        raise ValueError("Word length limits must be integers")
    if data["min_length"] != 3 or not 3 <= data["max_length"] <= 8:
        raise ValueError("Word lengths must use minimum 3 and maximum within 3..8")
    return LanguageConfig(lang, alphabet, data["min_length"], data["max_length"])
