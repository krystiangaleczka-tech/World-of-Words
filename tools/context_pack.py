from __future__ import annotations

import argparse
import fnmatch
import os
import re
import sys
from collections.abc import Sequence
from pathlib import Path

import tasks as task_tool

IGNORE = {".git", ".godot", ".mypy_cache", ".pytest_cache", ".ruff_cache", ".venv", "__pycache__"}
HEADING = re.compile(r"^(#{1,6})\s+(.+?)\s*#*\s*$")
DECL = re.compile(
    r"^(?:@[\w.]+(?:\([^)]*\))?\s+)*(?:class_name|class|signal|func|static\s+func|"
    r"const|var|enum|def|async\s+def)\b"
)


def _files(root: Path) -> list[Path]:
    found: list[Path] = []
    for directory, dirs, names in os.walk(root):
        dirs[:] = sorted(name for name in dirs if name not in IGNORE)
        found.extend(Path(directory) / name for name in sorted(names))
    return found


def _areas(root: Path) -> dict[str, tuple[str, ...]]:
    lines = (root / "docs" / "ARCHITECTURE.md").read_text(encoding="utf-8").splitlines()
    result: dict[str, tuple[str, ...]] = {}
    active = False
    for line in lines:
        if line.strip() == "## Areas":
            active = True
            continue
        if active and line.startswith("## "):
            break
        if not active or not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 2:
            continue
        for area in re.findall(r"`([^`]+)`", cells[0]):
            suffix = area.split(".", 1)[-1]
            paths = re.findall(r"`([^`]+)`", cells[1])
            result[area] = tuple(
                path.replace("<lang>", suffix).replace("<stage>", suffix) for path in paths
            )
    if not result:
        raise ValueError("docs/ARCHITECTURE.md#areas contains no area paths")
    return result


def _selected(root: Path, area: str | None) -> list[Path]:
    files = _files(root)
    if area is None:
        return files
    areas = _areas(root)
    if area not in areas:
        raise ValueError(f"unknown area {area!r}")
    selected: list[Path] = []
    for path in files:
        rel = path.relative_to(root).as_posix()
        for spec in areas[area]:
            spec = spec.removeprefix("./")
            if (spec.endswith("/") and rel.startswith(spec)) or fnmatch.fnmatchcase(rel, spec):
                selected.append(path)
                break
    return selected


def _slug(title: str) -> str:
    return re.sub(r"[\s_-]+", "-", re.sub(r"[^\w\s-]", "", title.casefold()).strip()).strip("-")


def _section(root: Path, ref: str) -> str:
    raw, sep, anchor = ref.partition("#")
    path = (root / raw).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"ref escapes repository: {ref}")
    if not path.is_file():
        raise ValueError(f"ref file does not exist: {raw}")
    lines = path.read_text(encoding="utf-8").splitlines()
    if not sep:
        return "\n".join(lines).rstrip()
    for start, line in enumerate(lines):
        match = HEADING.match(line)
        if not match or _slug(match.group(2)) != anchor.casefold():
            continue
        level = len(match.group(1))
        for end in range(start + 1, len(lines)):
            next_match = HEADING.match(lines[end])
            if next_match and len(next_match.group(1)) <= level:
                return "\n".join(lines[start:end]).rstrip()
        return "\n".join(lines[start:]).rstrip()
    raise ValueError(f"anchor not found: {ref}")


def _apis(root: Path, files: Sequence[Path]) -> list[str]:
    found: list[str] = []
    for path in files:
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeDecodeError):
            continue
        for marker, line in enumerate(lines):
            if "## @api" not in line:
                continue
            for index in range(marker + 1, min(marker + 8, len(lines))):
                candidate = lines[index].strip()
                if not candidate or candidate.startswith("#"):
                    continue
                if DECL.match(candidate):
                    rel = path.relative_to(root).as_posix()
                    found.append(f"- `{rel}:{index + 1}` `{candidate}`")
                break
    return found


def build(root: Path, area: str | None, refs: Sequence[str]) -> str:
    files = _selected(root, area)
    tasks, errors = task_tool.collect(root)
    if errors:
        raise ValueError("; ".join(sorted(errors)))
    lines = ["# Context pack"]
    if area:
        lines += ["", f"Area: `{area}`"]
    lines += ["", "## Repo map", *(f"- `{p.relative_to(root).as_posix()}`" for p in files)]
    lines += ["", "## @api signatures", *(_apis(root, files) or ["(none)"])]
    lines += ["", "## Requested docs"]
    for ref in refs:
        lines += ["", f"### `{ref}`", "", _section(root, ref)]
    if not refs:
        lines.append("(none)")
    lines += ["", "## Open tasks"]
    lines += [
        f"- {task.id} [{task.status}] {task.area} — {task.title}"
        for task in tasks
        if task.status != "done"
    ] or ["(none)"]
    return "\n".join(lines).rstrip() + "\n"


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build deterministic repository context packs.")
    parser.add_argument("--area")
    parser.add_argument("--ref", action="append", default=[], dest="refs")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        print(build(args.root.resolve(), args.area, args.refs), end="")
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
