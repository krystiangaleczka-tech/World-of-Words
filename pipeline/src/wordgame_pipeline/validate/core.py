"""Hard word and geometry gates, shared by pre-export candidates and final levels."""

from collections import Counter

from ..candidates.core import WordIndex
from ..grid.geometry import validate_geometry
from ..tiers.core import valid_word
from .schema import Schemas, schema_errors


def semantics(level: dict, selected: list[str], index: WordIndex) -> None:
    letters, bonus = level["letters"], level["bonus"]
    if not selected or len(set(selected)) != len(selected):
        raise ValueError("Selected words must be nonempty and unique")
    for word in [*selected, *bonus]:
        if not valid_word(word, index.config) or not Counter(word) <= Counter(letters):
            raise ValueError("Word is not normalized or formable from wheel tiles")
    if any(index.tiers.get(word) != "level_ok" for word in selected):
        raise ValueError("Selected words must be level_ok")
    if any(index.tiers.get(word) not in ("level_ok", "bonus_ok") for word in bonus):
        raise ValueError("Bonus word is unknown or banned")
    pools = index.pools(letters)
    expected = sorted((set(pools["level_ok"]) | set(pools["bonus_ok"])) - set(selected))
    if bonus != expected:
        raise ValueError("Bonus must be sorted, unique and complete")
    layout = tuple((p["w"], int(p["x"]), int(p["y"]), p["dir"]) for p in level["placements"])
    if level["grid"] != validate_geometry(layout, tuple(selected)):
        raise ValueError("Declared grid dimensions do not match placements")


def validate_level(level: object, index: WordIndex, schemas: Schemas) -> None:
    schemas.validate("level", level)
    if level["id"].startswith("pl-c-") and int(level["id"][-6:]) != level["slot"]:
        raise ValueError("Campaign ID must match slot")
    prepared = {**level, "placements": level["words"]}
    semantics(prepared, [p["w"] for p in level["words"]], index)


def validate_grid(level: object, index: WordIndex, schemas: Schemas, handmade: bool) -> None:
    common = {"letters", "words", "placements", "grid", "bonus", "seed"}
    identity = {"slot", "expect_bonus"} if handmade else {"candidate_id"}
    if not isinstance(level, dict) or set(level) != common | identity:
        raise ValueError("Invalid pre-export grid fields")
    properties = schemas.documents["level"]["properties"]
    for key in ("letters", "placements", "grid", "bonus", "seed"):
        errors = schema_errors(level[key], properties["words" if key == "placements" else key])
        if errors:
            raise ValueError(f"Grid schema {key}: {'; '.join(errors)}")
    words = level["words"]
    if not isinstance(words, list) or any(not isinstance(w, str) for w in words):
        raise ValueError("Invalid selected word list")
    semantics(level, words, index)
    if handmade:
        if type(level["slot"]) is not int or level["slot"] < 1:
            raise ValueError("Invalid handmade slot")
        expected = level["expect_bonus"]
        if not isinstance(expected, list) or any(
            not isinstance(w, str) or w not in level["bonus"] for w in expected
        ):
            raise ValueError("Expected handmade bonuses are missing")
        if expected != sorted(set(expected)):
            raise ValueError("Expected handmade bonuses must be sorted and unique")
    elif not isinstance(level["candidate_id"], str) or level[
        "candidate_id"
    ] != "pl-auto-" + "".join(sorted(level["letters"])):
        raise ValueError("Candidate identity does not match wheel")
