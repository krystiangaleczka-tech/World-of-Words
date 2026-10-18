"""Validate bilingual source copy before Godot import; never rewrite inputs."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KEY = re.compile(r"[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\Z")
TOKEN = re.compile(r"%[-+0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?([sdoxXfvc])")


def signature(text: str) -> tuple[str, ...]:
    """Ordered consumed arguments, not wording or display width."""
    result: list[str] = []
    index = 0
    raw_percent = False
    while index < len(text):
        if text[index] != "%":
            index += 1
            continue
        if text[index : index + 2] == "%%":
            index += 2
            continue
        token = TOKEN.match(text, index)
        if token:
            result.extend("int" for _ in range(token.group().count("*")))
            result.append(token[1])
            index = token.end()
            continue
        following = text[index + 1 : index + 2]
        if index and text[index - 1].isdigit() and (not following or not following.isalpha()):
            raw_percent = True
            index += 1
            continue
        raise ValueError(f"invalid percent format at column {index + 1}")
    if raw_percent and result:
        raise ValueError("literal percent in formatted copy must use %%")
    return tuple(result)


def load_catalog(root: Path) -> dict[str, dict[str, str]]:
    catalog: dict[str, dict[str, str]] = {}
    errors: list[str] = []
    paths = sorted((root / "game/locale").glob("*.csv"))
    if not paths:
        raise ValueError("game/locale: missing locale CSV catalog")
    for path in paths:
        label = path.relative_to(root).as_posix()
        reader = None
        count = 0
        try:
            with path.open(encoding="utf-8", newline="") as stream:
                reader = csv.reader(stream, strict=True)
                if next(reader, None) != ["keys", "pl", "en"]:
                    raise ValueError("expected exact keys,pl,en header")
                for row in reader:
                    if not row:
                        continue
                    count += 1
                    try:
                        if len(row) != 3:
                            raise ValueError("expected three cells")
                        key, pl, en = row
                        if not KEY.fullmatch(key) or not key.startswith(path.stem + "."):
                            raise ValueError(f"invalid area.screen.element key {key!r}")
                        if key in catalog:
                            raise ValueError(f"duplicate key {key!r}")
                        for language, text in [("pl", pl), ("en", en)]:
                            if not text or text != text.strip():
                                raise ValueError(f"{key}: {language} copy empty or untrimmed")
                            if any(ord(c) < 32 and c not in "\n\t" for c in text):
                                raise ValueError(f"{key}: {language} contains control character")
                        if signature(pl) != signature(en):
                            raise ValueError(f"{key}: PL/EN format arguments differ")
                        catalog[key] = {"pl": pl, "en": en}
                    except ValueError as exc:
                        errors.append(f"{label}:{reader.line_num}: {exc}")
                if not count:
                    raise ValueError("empty area catalog")
        except (OSError, UnicodeError, csv.Error, ValueError) as exc:
            line = reader.line_num if reader is not None else 1
            errors.append(f"{label}:{max(line, 1)}: {exc}")
    if errors:
        raise ValueError("\n".join(sorted(errors)))
    return dict(sorted(catalog.items()))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    try:
        catalog = load_catalog(parser.parse_args(argv).root.resolve())
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(f"OK: {len(catalog)} bilingual locale keys and format signatures")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
