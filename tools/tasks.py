from __future__ import annotations

import argparse
import fnmatch
import re
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

TASK_RE = re.compile(r"^T-\d{4}-.+\.md$")
ID_RE = re.compile(r"^T-\d{4}$")
EPIC_RE = re.compile(r"^E\d{2}$")

REQUIRED = (
    "id",
    "title",
    "epic",
    "type",
    "area",
    "risk",
    "executor",
    "think",
    "ui",
    "status",
    "depends_on",
    "touch",
    "revision",
)
ENUMS = {
    "type": {"contract", "feat", "fix", "refactor", "test", "content", "infra", "spike", "docs"},
    "risk": {"low", "medium", "high", "med"},  # T-0017 on main uses legacy "med".
    "executor": {"cheap", "sol", "human"},
    "think": {"low", "med", "high", "xhigh", "none"},
    "ui": {"none", "low", "med", "high"},
    "status": {"draft", "ready", "in_progress", "review", "blocked", "done"},
}


@dataclass(frozen=True)
class Task:
    id: str
    title: str
    area: str
    status: str
    depends_on: tuple[str, ...]
    touch: tuple[str, ...]


def _value(raw: str) -> object:
    raw = raw.split(" #", 1)[0].strip()
    if raw.startswith("[") and raw.endswith("]"):
        body = raw[1:-1].strip()
        return [] if not body else [part.strip().strip("'\"") for part in body.split(",")]
    if raw.isdigit():
        return int(raw)
    return raw.strip("'\"")


def _front_matter(path: Path) -> dict[str, object]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        raise ValueError("missing opening front-matter delimiter")
    try:
        end = lines.index("---", 1)
    except ValueError as exc:
        raise ValueError("missing closing front-matter delimiter") from exc

    data: dict[str, object] = {}
    list_key: str | None = None
    for line in lines[1:end]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if line[:1].isspace():
            if list_key is None or not stripped.startswith("- "):
                raise ValueError(f"unsupported front-matter line: {line!r}")
            item = _value(stripped[2:])
            if not isinstance(item, str) or not item:
                raise ValueError(f"{list_key} entries must be non-empty strings")
            items = data[list_key]
            assert isinstance(items, list)
            items.append(item)
            continue
        if ":" not in line:
            raise ValueError(f"invalid front-matter line: {line!r}")
        key, raw = line.split(":", 1)
        if key in data:
            raise ValueError(f"duplicate field {key!r}")
        raw = raw.split(" #", 1)[0].strip()
        if raw:
            data[key] = _value(raw)
            list_key = None
        else:
            data[key] = []
            list_key = key
    return data


def _areas(path: Path) -> set[str]:
    areas: set[str] = set()
    in_section = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip() == "## Areas":
            in_section = True
            continue
        if in_section and line.startswith("## "):
            break
        if in_section and line.startswith("|"):
            cells = line.split("|")
            if len(cells) >= 3:
                areas.update(re.findall(r"\x60([^\x60]+)\x60", cells[1]))
    if not areas:
        raise ValueError("ARCHITECTURE.md#areas contains no areas")
    return areas


def _validate(
    path: Path,
    data: dict[str, object],
    areas: set[str],
) -> tuple[Task | None, list[str]]:
    errors: list[str] = []
    missing = sorted(set(REQUIRED) - data.keys())
    unknown = sorted(data.keys() - set(REQUIRED))
    if missing:
        errors.append(f"missing fields: {', '.join(missing)}")
    if unknown:
        errors.append(f"unknown fields: {', '.join(unknown)}")

    string_fields = (
        "id",
        "title",
        "epic",
        "type",
        "area",
        "risk",
        "executor",
        "think",
        "ui",
        "status",
    )
    for field in string_fields:
        if field in data and (not isinstance(data[field], str) or not data[field]):
            errors.append(f"{field} must be a non-empty string")
    for field, allowed in ENUMS.items():
        value = data.get(field)
        if isinstance(value, str) and value not in allowed:
            errors.append(f"{field} has invalid value {value!r}")

    task_id = data.get("id")
    epic = data.get("epic")
    area = data.get("area")
    depends = data.get("depends_on")
    touch = data.get("touch")
    revision = data.get("revision")

    if isinstance(task_id, str):
        if not ID_RE.fullmatch(task_id):
            errors.append("id must match T-NNNN")
        elif not path.name.startswith(f"{task_id}-"):
            errors.append(f"id {task_id} does not match filename {path.name}")
    if isinstance(epic, str) and not EPIC_RE.fullmatch(epic):
        errors.append("epic must match ENN")
    if isinstance(area, str) and area not in areas:
        errors.append(f"unknown area {area!r}")
    for field, value in (("depends_on", depends), ("touch", touch)):
        invalid_item = isinstance(value, list) and any(
            not isinstance(item, str) or not item for item in value
        )
        if not isinstance(value, list) or invalid_item:
            errors.append(f"{field} must be a list of strings")
    if isinstance(touch, list) and not touch:
        errors.append("touch must contain at least one path/glob")
    if not isinstance(revision, int) or isinstance(revision, bool) or revision < 1:
        errors.append("revision must be an integer >= 1")
    if isinstance(depends, list) and len(depends) != len(set(depends)):
        errors.append("depends_on contains duplicates")
    if isinstance(touch, list) and len(touch) != len(set(touch)):
        errors.append("touch contains duplicates")
    if isinstance(task_id, str) and isinstance(depends, list) and task_id in depends:
        errors.append("task cannot depend on itself")
    if errors:
        return None, errors

    assert all(isinstance(data[field], str) for field in ("id", "title", "area", "status"))
    assert isinstance(depends, list) and isinstance(touch, list)
    return (
        Task(
            id=data["id"],
            title=data["title"],
            area=data["area"],
            status=data["status"],
            depends_on=tuple(depends),
            touch=tuple(touch),
        ),
        [],
    )


def _dependency_errors(tasks: Sequence[Task]) -> list[str]:
    errors: list[str] = []
    by_id: dict[str, Task] = {}
    for task in tasks:
        if task.id in by_id:
            errors.append(f"duplicate task id {task.id}")
        by_id[task.id] = task
    for task in tasks:
        for dependency in task.depends_on:
            if dependency not in by_id:
                errors.append(f"{task.id}: unknown dependency {dependency}")

    state: dict[str, int] = {}
    stack: list[str] = []

    def visit(task_id: str) -> None:
        state[task_id] = 1
        stack.append(task_id)
        for dependency in by_id[task_id].depends_on:
            if dependency not in by_id:
                continue
            if state.get(dependency, 0) == 0:
                visit(dependency)
            elif state.get(dependency) == 1:
                cycle = stack[stack.index(dependency) :] + [dependency]
                message = f"dependency cycle: {' -> '.join(cycle)}"
                if message not in errors:
                    errors.append(message)
        stack.pop()
        state[task_id] = 2

    for task_id in sorted(by_id):
        if state.get(task_id, 0) == 0:
            visit(task_id)
    return errors


def collect(root: Path) -> tuple[list[Task], list[str]]:
    try:
        areas = _areas(root / "docs" / "ARCHITECTURE.md")
    except (OSError, ValueError) as exc:
        return [], [f"docs/ARCHITECTURE.md: {exc}"]

    tasks: list[Task] = []
    errors: list[str] = []
    for path in sorted((root / "tasks").glob("T-*.md")):
        if not TASK_RE.fullmatch(path.name):
            continue
        try:
            data = _front_matter(path)
        except (OSError, ValueError) as exc:
            errors.append(f"{path.relative_to(root)}: {exc}")
            continue
        task, task_errors = _validate(path, data, areas)
        errors.extend(f"{path.relative_to(root)}: {error}" for error in task_errors)
        if task:
            tasks.append(task)
    errors.extend(_dependency_errors(tasks))
    return sorted(tasks, key=lambda task: task.id), errors


def _segment_overlap(left: str, right: str) -> bool:
    left_magic = any(char in left for char in "*?[")
    right_magic = any(char in right for char in "*?[")
    if not left_magic and not right_magic:
        return left == right
    if not left_magic:
        return fnmatch.fnmatchcase(left, right)
    if not right_magic:
        return fnmatch.fnmatchcase(right, left)

    left_prefix = re.split(r"[*?[]", left, maxsplit=1)[0]
    right_prefix = re.split(r"[*?[]", right, maxsplit=1)[0]
    if left_prefix and right_prefix and not (
        left_prefix.startswith(right_prefix) or right_prefix.startswith(left_prefix)
    ):
        return False

    suffix_re = re.compile(r"([^*?\[\]]+)$")
    left_match = suffix_re.search(left)
    right_match = suffix_re.search(right)
    left_suffix = left_match.group(1) if left_match else ""
    right_suffix = right_match.group(1) if right_match else ""
    return not left_suffix or not right_suffix or (
        left_suffix.endswith(right_suffix) or right_suffix.endswith(left_suffix)
    )


def _glob_overlap(left: str, right: str) -> bool:
    a = tuple(part for part in left.removeprefix("./").split("/") if part)
    b = tuple(part for part in right.removeprefix("./").split("/") if part)
    memo: dict[tuple[int, int], bool] = {}

    def visit(i: int, j: int) -> bool:
        if (i, j) in memo:
            return memo[i, j]
        if i == len(a):
            result = all(part == "**" for part in b[j:])
        elif j == len(b):
            result = all(part == "**" for part in a[i:])
        elif a[i] == "**":
            result = visit(i + 1, j) or visit(i, j + 1)
        elif b[j] == "**":
            result = visit(i, j + 1) or visit(i + 1, j)
        else:
            result = _segment_overlap(a[i], b[j]) and visit(i + 1, j + 1)
        memo[i, j] = result
        return result

    return visit(0, 0)


def _conflict(left: Task, right: Task) -> bool:
    if left.area == right.area:
        return True
    return any(_glob_overlap(a, b) for a in left.touch for b in right.touch)


def plan(tasks: Sequence[Task]) -> list[Task]:
    by_id = {task.id: task for task in tasks}
    active = [task for task in tasks if task.status == "in_progress"]
    selected: list[Task] = []
    for task in tasks:
        if task.status != "ready":
            continue
        if any(by_id[dependency].status != "done" for dependency in task.depends_on):
            continue
        if any(_conflict(task, other) for other in (*active, *selected)):
            continue
        selected.append(task)
    return selected


def _errors(errors: Sequence[str]) -> None:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate and schedule World of Words tasks.")
    parser.add_argument("command", choices=("lint", "board", "plan"))
    parser.add_argument("--root", type=Path, default=Path.cwd(), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    tasks, errors = collect(args.root.resolve())
    if errors:
        _errors(errors)
        return 1

    if args.command == "lint":
        print(f"OK: {len(tasks)} task(s)")
    elif args.command == "board":
        print(f"{'ID':<7} {'STATUS':<11} {'AREA':<22} TITLE")
        for task in tasks:
            print(f"{task.id:<7} {task.status:<11} {task.area:<22} {task.title}")
    else:
        runnable = plan(tasks)
        if not runnable:
            print("No runnable tasks.")
        for task in runnable:
            print(f"{task.id}\t{task.area}\t{task.title}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
