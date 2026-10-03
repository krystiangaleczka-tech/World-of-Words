from __future__ import annotations

import argparse
import fnmatch
import os
import re
import sys
from collections.abc import Sequence
from pathlib import Path

import tasks as task_tool

IGNORE_DIRS = {
    ".git",
    ".godot",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    ".venv",
    "__pycache__",
}
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*#*\s*$")
DECL_RE = re.compile(
    r"^(?:@[\w.]+(?:\([^)]*\))?\s+)*(?:class_name|class|signal|func|static\s+func|"
    r"const|var|enum|def|async\s+def)\b"
)


class ContextError(Exception):
    pass


def _files(root: Path) -> list[Path]:
    found: list[Path] = []
    for directory, dirs, names in os.walk(root):
        dirs[:] = sorted(name for name in dirs if name not in IGNORE_DIRS)
        for name in sorted(names):
            found.append(Path(directory) / name)
    return found


def _area_paths(root: Path) -> dict[str, tuple[str, ...]]:
    lines = (root / "docs" / "ARCHITECTURE.md").read_text(encoding="utf-8").splitlines()
    result: dict[str, tuple[str, ...]] = {}
    in_areas = False
    for line in lines:
        if line.strip() == "## Areas":
            in_areas = True
            continue
        if in_areas and line.startswith("## "):
            break
        if not in_areas or not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 2:
            continue
        names = re.findall(r"`([^`]+)`", cells[0])
        paths = re.findall(r"`([^`]+)`", cells[1])
        for area in names:
            suffix = area.split(".", 1)[-1]
            expanded = tuple(
                path.replace("<lang>", suffix).replace("<stage>", suffix) for path in paths
            )
            if expanded:
                result[area] = expanded
    if not result:
        raise ContextError("docs/ARCHITECTURE.md#areas contains no area paths")
    return result


def _selected_files(root: Path, area: str | None) -> list[Path]:
    files = _files(root)
    if area is None:
        return files
    areas = _area_paths(root)
    if area not in areas:
        raise ContextError(f"unknown area {area!r}")
    selected: list[Path] = []
    for path in files:
        rel = path.relative_to(root).as_posix()
        for spec in areas[area]:
            spec = spec.removeprefix("./")
            if (
                (spec.endswith("/") and rel.startswith(spec))
                or fnmatch.fnmatchcase(rel, spec)
                or (not any(char in spec for char in "*?[") and rel == spec)
            ):
                selected.append(path)
                break
    return selected


def _slug(title: str) -> str:
    clean = re.sub(r"[^\w\s-]", "", title.casefold()).strip()
    return re.sub(r"[\s_-]+", "-", clean).strip("-")


def _doc_section(root: Path, ref: str) -> tuple[str, str]:
    raw_path, has_anchor, anchor = ref.partition("#")
    path = (root / raw_path).resolve()
    try:
        path.relative_to(root.resolve())
    except ValueError as exc:
        raise ContextError(f"ref escapes repository: {ref}") from exc
    if not path.is_file():
        raise ContextError(f"ref file does not exist: {raw_path}")

    lines = path.read_text(encoding="utf-8").splitlines()
    if not has_anchor:
        return ref, "\n".join(lines).rstrip()
    for start, line in enumerate(lines):
        match = HEADING_RE.match(line)
        if not match or _slug(match.group(2)) != anchor.casefold():
            continue
        level = len(match.group(1))
        end = next(
            (
                index
                for index in range(start + 1, len(lines))
                if (next_match := HEADING_RE.match(lines[index]))
                and len(next_match.group(1)) <= level
            ),
            len(lines),
        )
        return ref, "\n".join(lines[start:end]).rstrip()
    raise ContextError(f"anchor not found: {ref}")


def _api_signatures(root: Path, files: Sequence[Path]) -> list[str]:
    signatures: list[str] = []
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
                if DECL_RE.match(candidate):
                    rel = path.relative_to(root).as_posix()
                    signatures.append(f"- `{rel}:{index + 1}` `{candidate}`")
                break
    return signatures


def _open_tasks(root: Path) -> list[str]:
    tasks, errors = task_tool.collect(root)
    if errors:
        raise ContextError("; ".join(sorted(errors)))
    return [
        f"- {task.id} [{task.status}] {task.area} — {task.title}"
        for task in tasks
        if task.status != "done"
    ]


def build(root: Path, area: str | None, refs: Sequence[str]) -> str:
    files = _selected_files(root, area)
    lines = ["# Context pack"]
    if area:
        lines.extend(["", f"Area: `{area}`"])
    lines.extend(["", "## Repo map"])
    lines.extend(f"- `{path.relative_to(root).as_posix()}`" for path in files)
    lines.extend(["", "## @api signatures"])
    lines.extend(_api_signatures(root, files) or ["(none)"])
    lines.extend(["", "## Requested docs"])
    for ref in refs:
        label, section = _doc_section(root, ref)
        lines.extend(["", f"### `{label}`", "", section])
    if not refs:
        lines.append("(none)")
    lines.extend(["", "## Open tasks"])
    lines.extend(_open_tasks(root) or ["(none)"])
    return "\n".join(lines).rstrip() + "\n"


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build deterministic repository context packs.")
    parser.add_argument("--area")
    parser.add_argument("--ref", action="append", default=[], dest="refs")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        print(build(args.root.resolve(), args.area, args.refs), end="")
    except (ContextError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
