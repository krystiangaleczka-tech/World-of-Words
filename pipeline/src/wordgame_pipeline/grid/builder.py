"""Bounded greedy and backtracking search with reproducible restart seeds."""

from dataclasses import dataclass
from random import Random
from unicodedata import normalize as unicode_normalize

from .geometry import Placement, bounds, cells_for, normalize, validate_geometry


@dataclass(frozen=True)
class SearchOptions:
    restarts: int = 4
    nodes: int = 128
    branches: int = 3
    considered: int = 16
    selected: int = 6

    def validate(self) -> None:
        if any(type(v) is not int or v < 1 for v in vars(self).values()):
            raise ValueError("Search options must be positive integers")


def score(layout: tuple[Placement, ...]) -> tuple[int, int, int]:
    cells = cells_for(layout)
    x, y, right, bottom = bounds(cells)
    return (
        len(layout),
        sum(len(w) for w, *_ in layout) - len(cells),
        -(right - x + 1) * (bottom - y + 1),
    )


def candidates(word: str, layout: tuple[Placement, ...]) -> list[Placement]:
    cells = cells_for(layout)
    owners = set()
    for w, x, y, direction in layout:
        dx, dy = (1, 0) if direction == "h" else (0, 1)
        owners.update(((x + n * dx, y + n * dy), direction) for n in range(len(w)))
    choices: set[Placement] = set()
    for offset, char in enumerate(word):
        for (cx, cy), existing in cells.items():
            if char != existing:
                continue
            for direction, dx, dy in (("h", 1, 0), ("v", 0, 1)):
                x, y = cx - offset * dx, cy - offset * dy
                if (x - dx, y - dy) in cells or (x + len(word) * dx, y + len(word) * dy) in cells:
                    continue
                allowed = True
                for n, letter in enumerate(word):
                    point = (x + n * dx, y + n * dy)
                    if point in cells:
                        if cells[point] != letter or (point, direction) in owners:
                            allowed = False
                            break
                    elif (point[0] - dy, point[1] + dx) in cells or (
                        point[0] + dy,
                        point[1] - dx,
                    ) in cells:
                        allowed = False
                        break
                if allowed:
                    trial = layout + ((word, x, y, direction),)
                    left, top, right, bottom = bounds(cells_for(trial))
                    if right - left < 10 and bottom - top < 10:
                        choices.add((word, x, y, direction))
    return sorted(choices)


def build_grid(
    words: tuple[str, ...],
    required: str,
    seed: int,
    options: SearchOptions | None = None,
    require_all: bool = False,
) -> tuple[Placement, ...]:
    options = options or SearchOptions()
    options.validate()
    if (
        type(seed) is not int
        or not words
        or required not in words
        or any(
            not isinstance(w, str)
            or not 3 <= len(w) <= 8
            or not w.isupper()
            or not w.isalpha()
            or unicode_normalize("NFC", w) != w
            for w in words
        )
        or len(set(words)) != len(words)
    ):
        raise ValueError("Invalid grid word pool or seed")
    best = ((required, 0, 0, "v"),)
    scores: dict[tuple[Placement, ...], tuple[int, int, int]] = {}
    choices_cache: dict[tuple[str, tuple[Placement, ...]], list[Placement]] = {}

    def evaluate(layout: tuple[Placement, ...]) -> tuple[int, int, int]:
        if layout not in scores:
            scores[layout] = score(layout)
        return scores[layout]

    def choose(word: str, layout: tuple[Placement, ...], rng: Random) -> list[Placement]:
        key = (word, layout)
        if key not in choices_cache:
            choices_cache[key] = candidates(word, layout)
        choices = choices_cache[key].copy()
        rng.shuffle(choices)
        choices.sort(key=lambda p: evaluate(layout + (p,)), reverse=True)
        return choices

    def remember(layout: tuple[Placement, ...]) -> None:
        nonlocal best
        trial_score, best_score = evaluate(layout), evaluate(best)
        if trial_score >= best_score:
            normalized = normalize(layout)
            if trial_score > best_score or normalized < best:
                best = normalized

    for restart in range(options.restarts):
        rng = Random(seed + restart)
        rest = sorted(set(words) - {required})
        rng.shuffle(rest)
        if restart == 0:
            rest.sort(key=lambda w: -len(w))
        if not require_all:
            rest = rest[: max(0, options.considered - 1)]
        limit = len(words) if require_all else options.selected
        greedy = ((required, 0, 0, "v"),)
        for word in rest:
            choices = choose(word, greedy, rng)
            if choices and len(greedy) < limit:
                greedy += (choices[0],)
        remember(greedy)
        visited = 0

        def search(
            index: int,
            layout: tuple[Placement, ...],
            rest: tuple[str, ...] = tuple(rest),
            limit: int = limit,
            rng: Random = rng,
        ) -> None:
            nonlocal visited
            if visited >= options.nodes:
                return
            visited += 1
            remember(layout)
            if index == len(rest) or len(layout) >= limit:
                return
            for placement in choose(rest[index], layout, rng)[: options.branches]:
                search(index + 1, layout + (placement,))
            search(index + 1, layout)

        search(0, ((required, 0, 0, "v"),))
    if require_all and len(best) != len(words):
        raise ValueError("Handmade words cannot all fit within the search budget")
    validate_geometry(best, tuple(p[0] for p in best))
    return best
