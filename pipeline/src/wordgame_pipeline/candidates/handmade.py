"""Safe authoring input with strict shapes and source-backed word membership."""

import hashlib
from pathlib import Path

import yaml
from yaml.events import AliasEvent

from ..config import canonical_bytes
from .core import WordIndex


class UniqueLoader(yaml.SafeLoader):
    def construct_mapping(self, node: yaml.MappingNode, deep: bool = False) -> dict:
        if not isinstance(node, yaml.MappingNode):
            raise ValueError("Expected YAML mapping")
        result = {}
        for key_node, value_node in node.value:
            key = self.construct_object(key_node, deep=deep)
            if not isinstance(key, str) or key in result:
                raise ValueError("Duplicate or non-string YAML key")
            result[key] = self.construct_object(value_node, deep=deep)
        return result


def word_list(value: object, allow_empty: bool = False) -> list[str]:
    if (
        not isinstance(value, list)
        or (not value and not allow_empty)
        or any(not isinstance(word, str) for word in value)
        or len(set(value)) != len(value)
    ):
        raise ValueError("Expected unique word list")
    return value


def placements(value: object, words: list[str]) -> list[dict[str, object]]:
    if not isinstance(value, list) or len(value) != len(words):
        raise ValueError("Grid must place every selected word")
    found = []
    for placement in value:
        if not isinstance(placement, dict) or set(placement) != {"w", "x", "y", "dir"}:
            raise ValueError("Invalid grid placement")
        if (
            placement["w"] not in words
            or placement["dir"] not in ("h", "v")
            or any(type(placement[c]) is not int or not 0 <= placement[c] <= 9 for c in ("x", "y"))
        ):
            raise ValueError("Invalid grid placement")
        found.append(placement["w"])
    if sorted(found) != sorted(words):
        raise ValueError("Grid must place every selected word once")
    return sorted(value, key=lambda p: p["w"])


def load_handmade(root: Path, index: WordIndex) -> tuple[list[dict[str, object]], str]:
    entries = []
    files = []
    slots: set[int] = set()
    for path in sorted((root / "handmade" / index.config.lang).glob("*.yaml")):
        raw = path.read_bytes()
        files.append({"path": path.relative_to(root).as_posix(), "bytes_hex": raw.hex()})
        try:
            text = raw.decode("utf-8")
            if any(isinstance(event, AliasEvent) for event in yaml.parse(text)):
                raise ValueError("YAML aliases are unsupported")
            values = yaml.load(text, Loader=UniqueLoader)
        except (yaml.YAMLError, UnicodeError) as exc:
            raise ValueError(f"Invalid handmade YAML: {path.name}") from exc
        if not isinstance(values, list):
            raise ValueError("Handmade file must contain a list")
        for value in values:
            if (
                not isinstance(value, dict)
                or not {"slot", "letters", "words"} <= set(value)
                or not set(value) <= {"slot", "letters", "words", "expect_bonus", "grid"}
            ):
                raise ValueError("Invalid handmade fields")
            slot = value["slot"]
            if type(slot) is not int or slot < 1 or slot in slots:
                raise ValueError("Handmade slots must be positive and unique")
            slots.add(slot)
            pools = index.pools(value["letters"])
            words = word_list(value["words"])
            expected = word_list(value.get("expect_bonus", []), allow_empty=True)
            if any(word not in pools["level_ok"] for word in words):
                raise ValueError("Handmade grid words must be formable level_ok words")
            bonus = sorted((set(pools["level_ok"]) | set(pools["bonus_ok"])) - set(words))
            if any(word not in bonus for word in expected):
                raise ValueError("Expected bonus must be an unselected eligible word")
            entry = {
                "slot": slot,
                "letters": value["letters"],
                "words": sorted(words),
                "bonus": bonus,
                "expect_bonus": sorted(expected),
            }
            if "grid" in value:
                entry["grid"] = placements(value["grid"], words)
            entries.append(entry)
    return sorted(entries, key=lambda e: e["slot"]), hashlib.sha256(
        canonical_bytes(files)
    ).hexdigest()
