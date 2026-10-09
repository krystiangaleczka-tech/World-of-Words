"""Crossword geometry checks independent of search and source evidence."""

Placement = tuple[str, int, int, str]
Point = tuple[int, int]


def cells_for(layout: tuple[Placement, ...]) -> dict[Point, str]:
    cells: dict[Point, str] = {}
    owners: set[tuple[Point, str]] = set()
    for word, x, y, direction in layout:
        dx, dy = (1, 0) if direction == "h" else (0, 1)
        for offset, char in enumerate(word):
            point = (x + dx * offset, y + dy * offset)
            if (point, direction) in owners or (point in cells and cells[point] != char):
                raise ValueError("Conflicting or same-axis overlapping words")
            owners.add((point, direction))
            cells[point] = char
    return cells


def bounds(cells: dict[Point, str]) -> tuple[int, int, int, int]:
    return (
        min(x for x, _ in cells),
        min(y for _, y in cells),
        max(x for x, _ in cells),
        max(y for _, y in cells),
    )


def normalize(layout: tuple[Placement, ...]) -> tuple[Placement, ...]:
    left, top, right, bottom = bounds(cells_for(layout))
    result = tuple((w, x - left, y - top, d) for w, x, y, d in layout)
    if right - left > bottom - top:
        result = tuple((w, y, x, "v" if d == "h" else "h") for w, x, y, d in result)
    return tuple(sorted(result))


def validate_geometry(layout: tuple[Placement, ...], words: tuple[str, ...]) -> dict[str, int]:
    if (
        not layout
        or not words
        or len(set(words)) != len(words)
        or any(not isinstance(p, tuple) or len(p) != 4 for p in layout)
    ):
        raise ValueError("Invalid grid layout shape")
    for word, x, y, direction in layout:
        if (
            not isinstance(word, str)
            or len(word) < 3
            or direction not in ("h", "v")
            or type(x) is not int
            or type(y) is not int
            or x < 0
            or y < 0
        ):
            raise ValueError("Invalid grid placement")
    if sorted(p[0] for p in layout) != sorted(words):
        raise ValueError("Grid must place each selected word once")
    cells = cells_for(layout)
    left, top, right, bottom = bounds(cells)
    width, height = right - left + 1, bottom - top + 1
    if left != 0 or top != 0 or not 1 <= width <= height <= 10:
        raise ValueError("Grid must have zero origin, portrait aspect and fit 10x10")
    seen = {next(iter(cells))}
    pending = list(seen)
    while pending:
        x, y = pending.pop()
        for point in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if point in cells and point not in seen:
                seen.add(point)
                pending.append(point)
    if len(seen) != len(cells):
        raise ValueError("Disconnected grid")
    runs: set[Placement] = set()
    for x, y in cells:
        for direction, dx, dy in (("h", 1, 0), ("v", 0, 1)):
            if (x - dx, y - dy) in cells:
                continue
            chars = []
            cx, cy = x, y
            while (cx, cy) in cells:
                chars.append(cells[(cx, cy)])
                cx, cy = cx + dx, cy + dy
            if len(chars) >= 2:
                runs.add(("".join(chars), x, y, direction))
    if runs != set(layout):
        raise ValueError("Accidental adjacency or unintended word run")
    return {"w": width, "h": height}
