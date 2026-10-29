"""Read-only COMPACT grid fit calculation from canonical Godot design tokens."""

import math
import re
from dataclasses import dataclass
from pathlib import Path

TOKEN = re.compile(r"\tconst ([A-Z_]+): (int|float) = ([0-9]+(?:\.[0-9]+)?)")


@dataclass(frozen=True)
class CompactTokens:
    gap: int
    cell_min: int
    cell_max: int
    grid_min_ratio: float

    def __post_init__(self) -> None:
        if (
            type(self.gap) is not int
            or type(self.cell_min) is not int
            or type(self.cell_max) is not int
            or type(self.grid_min_ratio) is not float
            or self.gap < 0
            or self.cell_min <= 0
            or self.cell_max < self.cell_min
            or not 0 < self.grid_min_ratio <= 1
        ):
            raise ValueError("Invalid canonical COMPACT tokens")


def load_compact_tokens(path: Path) -> CompactTokens:
    """Read only Space.XS and three Layout constants; reject missing/duplicate tokens."""
    if not isinstance(path, Path) or path.is_symlink() or not path.is_file():
        raise ValueError("Expected a regular canonical tokens.gd file")
    needed = {
        ("Space", "XS"): ("int", "gap"),
        ("Layout", "CELL_MIN"): ("int", "cell_min"),
        ("Layout", "CELL_MAX"): ("int", "cell_max"),
        ("Layout", "GRID_MIN_RATIO"): ("float", "grid_min_ratio"),
    }
    found = {}
    section = ""
    try:
        raw = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise ValueError("Cannot read canonical layout tokens") from exc
    for line in raw.splitlines():
        if line.startswith("class "):
            section = line.removeprefix("class ").split(":", 1)[0]
        match = TOKEN.fullmatch(line)
        if not match:
            continue
        name, kind, value = match.groups()
        key = (section, name)
        if key not in needed:
            continue
        if key in found or kind != needed[key][0]:
            raise ValueError(f"Duplicate or mistyped canonical token {key}")
        found[key] = int(value) if kind == "int" else float(value)
    if set(found) != set(needed):
        raise ValueError("Missing canonical COMPACT layout token")
    return CompactTokens(**{field: found[key] for key, (_, field) in needed.items()})


def _size(value: object) -> float:
    if type(value) not in (int, float):
        raise ValueError("Expected finite positive layout size")
    try:
        size = float(value)
    except OverflowError as exc:
        raise ValueError("Unrepresentable layout size") from exc
    if not math.isfinite(size) or size <= 0:
        raise ValueError("Expected finite positive layout size")
    return size


def validate_compact_grid(
    grid: dict,
    *,
    area_width: float,
    area_height: float,
    body_height: float,
    tokens: CompactTokens,
) -> float:
    """Return clamped cell side or reject a COMPACT rectangle that cannot fit.

    The caller must supply measured safe-area/body/grid rectangles from the
    COMPACT reference; these are not guessed from resolution alone.
    """
    if (
        not isinstance(grid, dict)
        or set(grid) != {"w", "h"}
        or any(type(grid[k]) is not int or not 1 <= grid[k] <= 10 for k in ("w", "h"))
        or not isinstance(tokens, CompactTokens)
    ):
        raise ValueError("Expected validated 1..10 by 1..10 grid and canonical tokens")
    width, height, body = _size(area_width), _size(area_height), _size(body_height)
    if height > body or height < tokens.grid_min_ratio * body:
        raise ValueError("COMPACT grid area is below required body-height share")
    side = min(width / grid["w"], height / grid["h"]) - tokens.gap
    if side < tokens.cell_min:
        raise ValueError("COMPACT grid cell would fall below CELL_MIN")
    return min(side, tokens.cell_max)
