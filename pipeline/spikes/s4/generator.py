from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from random import Random

DEFAULT_WORDS = Path(__file__).with_name("words_pl.txt")
DEFAULT_SEED = 32032


@dataclass(frozen=True)
class Pool:
    wheel: str
    words: tuple[str, ...]


@dataclass(frozen=True)
class Placement:
    word: str
    x: int
    y: int
    horizontal: bool


@dataclass(frozen=True)
class Level:
    wheel: str
    words: tuple[str, ...]
    placements: tuple[Placement, ...]


def load_pools(path: Path = DEFAULT_WORDS) -> tuple[Pool, ...]:
    pools: list[Pool] = []
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            raise ValueError(f"{path}:{number}: expected WHEEL: WORD ...")
        wheel, raw_words = (part.strip().upper() for part in line.split(":", 1))
        words = tuple(raw_words.split())
        if not words or words[0] != wheel:
            raise ValueError(f"{path}:{number}: first word must equal wheel")
        wheel_letters = Counter(wheel)
        bad = [word for word in words if not Counter(word) <= wheel_letters]
        if bad:
            raise ValueError(f"{path}:{number}: words do not fit {wheel}: {bad}")
        pools.append(Pool(wheel, words))
    if not pools:
        raise ValueError(f"{path}: no pools")
    return tuple(pools)


def _cells(placements: tuple[Placement, ...]) -> dict[tuple[int, int], str]:
    cells: dict[tuple[int, int], str] = {}
    for placed in placements:
        dx, dy = (1, 0) if placed.horizontal else (0, 1)
        for index, char in enumerate(placed.word):
            point = (placed.x + index * dx, placed.y + index * dy)
            previous = cells.get(point)
            if previous is not None and previous != char:
                raise ValueError("conflicting placement")
            cells[point] = char
    return cells


def _bounds(cells: dict[tuple[int, int], str]) -> tuple[int, int, int, int]:
    xs = [point[0] for point in cells]
    ys = [point[1] for point in cells]
    return min(xs), min(ys), max(xs), max(ys)


def _can_place(
    word: str,
    x: int,
    y: int,
    horizontal: bool,
    cells: dict[tuple[int, int], str],
) -> tuple[bool, int]:
    dx, dy = (1, 0) if horizontal else (0, 1)
    if (x - dx, y - dy) in cells or (x + len(word) * dx, y + len(word) * dy) in cells:
        return False, 0

    overlaps = 0
    px, py = -dy, dx
    for index, char in enumerate(word):
        point = (x + index * dx, y + index * dy)
        previous = cells.get(point)
        if previous is not None:
            if previous != char:
                return False, 0
            overlaps += 1
            continue
        if (point[0] + px, point[1] + py) in cells:
            return False, 0
        if (point[0] - px, point[1] - py) in cells:
            return False, 0
    return overlaps > 0, overlaps


def _candidates(
    word: str,
    placements: tuple[Placement, ...],
    rng: Random,
) -> list[tuple[int, int, bool, int, int]]:
    cells = _cells(placements)
    candidates: list[tuple[int, int, bool, int, int]] = []
    for index, char in enumerate(word):
        for (cx, cy), existing in cells.items():
            if existing != char:
                continue
            for horizontal in (True, False):
                dx, dy = (1, 0) if horizontal else (0, 1)
                x, y = cx - index * dx, cy - index * dy
                allowed, overlaps = _can_place(word, x, y, horizontal, cells)
                if not allowed:
                    continue
                trial = dict(cells)
                for offset, new_char in enumerate(word):
                    trial[(x + offset * dx, y + offset * dy)] = new_char
                min_x, min_y, max_x, max_y = _bounds(trial)
                width = max_x - min_x + 1
                height = max_y - min_y + 1
                if width > 10 or height > 10:
                    continue
                area = width * height
                candidates.append((x, y, horizontal, overlaps, area))
    rng.shuffle(candidates)
    candidates.sort(key=lambda item: (-item[3], item[4]))
    return candidates


def _layout(words: tuple[str, ...], rng: Random) -> tuple[Placement, ...] | None:
    ordered = tuple(sorted(words, key=lambda word: (-len(word), word)))
    nodes = 0

    def place(index: int, current: tuple[Placement, ...]) -> tuple[Placement, ...] | None:
        nonlocal nodes
        nodes += 1
        if nodes > 10_000:
            return None
        if index == len(ordered):
            return current
        for x, y, horizontal, _overlaps, _area in _candidates(ordered[index], current, rng)[:20]:
            candidate = current + (Placement(ordered[index], x, y, horizontal),)
            result = place(index + 1, candidate)
            if result is not None:
                return result
        return None

    return place(1, (Placement(ordered[0], 0, 0, True),))


def generate_levels(
    pools: tuple[Pool, ...],
    count: int = 50,
    seed: int = DEFAULT_SEED,
) -> tuple[Level, ...]:
    if count < 1:
        raise ValueError("count must be positive")
    rng = Random(seed)
    seen: set[tuple[str, tuple[str, ...]]] = set()
    levels: list[Level] = []
    attempts = 0

    while len(levels) < count and attempts < count * 100:
        pool = pools[attempts % len(pools)]
        attempts += 1
        word_count = rng.randint(4, min(6, len(pool.words)))
        rest = list(pool.words[1:])
        rng.shuffle(rest)
        words = (pool.words[0], *rest[: word_count - 1])
        signature = (pool.wheel, tuple(sorted(words)))
        if signature in seen:
            continue
        layout = _layout(words, Random(rng.randrange(1 << 30)))
        if layout is None:
            continue
        seen.add(signature)
        levels.append(Level(pool.wheel, words, layout))

    if len(levels) != count:
        raise RuntimeError(f"generated {len(levels)} of {count} levels")
    return tuple(levels)


def render(level: Level) -> str:
    cells = _cells(level.placements)
    min_x, min_y, max_x, max_y = _bounds(cells)
    return "\n".join(
        "".join(cells.get((x, y), ".") for x in range(min_x, max_x + 1))
        for y in range(min_y, max_y + 1)
    )


def dimensions(level: Level) -> tuple[int, int]:
    cells = _cells(level.placements)
    min_x, min_y, max_x, max_y = _bounds(cells)
    return max_x - min_x + 1, max_y - min_y + 1


def main() -> int:
    parser = argparse.ArgumentParser(description="T-0032 S4 crossword-grid prototype")
    parser.add_argument("--count", type=int, default=50)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--words", type=Path, default=DEFAULT_WORDS)
    args = parser.parse_args()

    levels = generate_levels(load_pools(args.words), args.count, args.seed)
    for number, level in enumerate(levels, start=1):
        width, height = dimensions(level)
        words = ",".join(sorted(level.words))
        print(f"LEVEL {number:02d} wheel={level.wheel} words={words} size={width}x{height}")
        print(render(level))
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
