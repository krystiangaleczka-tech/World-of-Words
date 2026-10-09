"""Immutable language rules; v0 accepts the JSON-compatible subset of YAML."""

import json
import math
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
class TierRules:
    base_min_arf: float = 10
    inflected_min_arf: float = 100
    banned_labels: tuple[str, ...] = ("wulg.",)
    excluded_level_labels: tuple[str, ...] = ("daw.", "przest.", "rzad.")

    @classmethod
    def from_dict(cls, data: object) -> "TierRules":
        expected = {"base_min_arf", "inflected_min_arf", "banned_labels", "excluded_level_labels"}
        if not isinstance(data, dict) or set(data) != expected:
            raise ValueError("Invalid tier rules fields")
        for name in ("base_min_arf", "inflected_min_arf"):
            value = data[name]
            if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
                raise ValueError("Tier ARF thresholds must be finite and nonnegative")
        for name in ("banned_labels", "excluded_level_labels"):
            values = data[name]
            if (
                not isinstance(values, list)
                or any(not isinstance(v, str) or not v for v in values)
                or len(set(values)) != len(values)
            ):
                raise ValueError("Tier labels must be distinct nonempty strings")
        return cls(
            data["base_min_arf"],
            data["inflected_min_arf"],
            tuple(data["banned_labels"]),
            tuple(data["excluded_level_labels"]),
        )


@dataclass(frozen=True)
class LanguageConfig:
    lang: str
    alphabet: str
    min_length: int
    max_length: int
    tier_rules: TierRules | None = None

    def to_dict(self) -> dict[str, object]:
        data = asdict(self)
        if self.tier_rules is None:
            del data["tier_rules"]
        return data


def load_config(root: Path, lang: str) -> LanguageConfig:
    if not re.fullmatch(r"[a-z]{2}", lang) or lang != "pl":
        raise ValueError(f"Unsupported language: {lang}")
    path = root / "config" / f"{lang}.yaml"
    try:
        data = parse_json(path.read_text(encoding="utf-8"))
    except ValueError as exc:
        raise ValueError(f"{path}: expected JSON-compatible YAML: {exc}") from exc
    required = {"lang", "alphabet", "min_length", "max_length"}
    if not isinstance(data, dict) or set(data) not in (required, required | {"tier_rules"}):
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
    rules = TierRules.from_dict(data["tier_rules"]) if "tier_rules" in data else None
    return LanguageConfig(lang, alphabet, data["min_length"], data["max_length"], rules)
