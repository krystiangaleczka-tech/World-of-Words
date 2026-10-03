from __future__ import annotations

import argparse
import fnmatch
import os
import re
import subprocess
import sys
from collections.abc import Sequence
from pathlib import Path

import tasks as task_tool

BRANCH_RE = re.compile(r"^t/(?P<number>\d{4})-[A-Za-z0-9][A-Za-z0-9._-]*$")


class ScopeError(Exception):
    pass


def _git(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )


def _branch_name(root: Path) -> str:
    github_head = os.environ.get("GITHUB_HEAD_REF", "").strip()
    if github_head:
        return github_head

    result = _git(root, "branch", "--show-current")
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown git error"
        raise ScopeError(f"cannot determine current branch: {detail}")
    branch = result.stdout.strip()
    if not branch:
        raise ScopeError(
            "cannot determine task branch (detached HEAD and GITHUB_HEAD_REF is empty)"
        )
    return branch


def _task_number(branch: str) -> str:
    match = BRANCH_RE.fullmatch(branch)
    if not match:
        raise ScopeError(f"branch {branch!r} must match t/NNNN-*")
    return match.group("number")


def _task_for_branch(root: Path, branch: str) -> tuple[task_tool.Task, Path]:
    number = _task_number(branch)
    task_id = f"T-{number}"
    matches = sorted((root / "tasks").glob(f"{task_id}-*.md"))
    if len(matches) != 1:
        raise ScopeError(
            f"{task_id}: expected exactly one tasks/{task_id}-*.md file, found {len(matches)}"
        )

    tasks, errors = task_tool.collect(root)
    if errors:
        joined = "; ".join(sorted(errors))
        raise ScopeError(f"task metadata is invalid: {joined}")
    for task in tasks:
        if task.id == task_id:
            return task, matches[0]
    raise ScopeError(f"{task_id}: matching task file was not accepted by task metadata validation")


def _base_ref(root: Path, requested: str) -> str:
    candidates = [requested]
    if not requested.startswith("origin/"):
        candidates.append(f"origin/{requested}")
    for candidate in candidates:
        result = _git(root, "rev-parse", "--verify", "--quiet", f"{candidate}^{{commit}}")
        if result.returncode == 0:
            return candidate
    raise ScopeError(f"base ref {requested!r} does not exist locally or under origin/")


def _changed_files(root: Path, base: str) -> list[str]:
    result = _git(root, "diff", "--name-status", "--find-renames", f"{base}...HEAD")
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown git error"
        raise ScopeError(f"cannot diff {base}...HEAD: {detail}")

    changed: set[str] = set()
    for line in result.stdout.splitlines():
        if not line:
            continue
        fields = line.split("\t")
        status = fields[0]
        if status.startswith(("R", "C")):
            if len(fields) != 3:
                raise ScopeError(f"cannot parse git diff entry: {line!r}")
            changed.update(fields[1:3])
        else:
            if len(fields) != 2:
                raise ScopeError(f"cannot parse git diff entry: {line!r}")
            changed.add(fields[1])
    return sorted(changed)


def _parts(value: str) -> tuple[str, ...]:
    normalized = value.replace("\\", "/").removeprefix("./")
    return tuple(part for part in normalized.split("/") if part)


def _path_matches(path: str, pattern: str) -> bool:
    path_parts = _parts(path)
    pattern_parts = _parts(pattern)
    memo: dict[tuple[int, int], bool] = {}

    def visit(pattern_index: int, path_index: int) -> bool:
        key = (pattern_index, path_index)
        if key in memo:
            return memo[key]

        if pattern_index == len(pattern_parts):
            result = path_index == len(path_parts)
        elif pattern_parts[pattern_index] == "**":
            result = visit(pattern_index + 1, path_index) or (
                path_index < len(path_parts) and visit(pattern_index, path_index + 1)
            )
        elif path_index == len(path_parts):
            result = False
        else:
            matches_segment = fnmatch.fnmatchcase(
                path_parts[path_index], pattern_parts[pattern_index]
            )
            result = matches_segment and visit(
                pattern_index + 1,
                path_index + 1,
            )
        memo[key] = result
        return result

    return visit(0, 0)


def _outside_scope(changed: Sequence[str], touch: Sequence[str], task_file: str) -> list[str]:
    return [
        path
        for path in changed
        if path != task_file and not any(_path_matches(path, pattern) for pattern in touch)
    ]


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check changed files against the current task scope."
    )
    parser.add_argument("--base", default=None, help="Base branch/ref (default: CI base or main).")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    root = args.root.resolve()
    try:
        branch = _branch_name(root)
        task, task_path = _task_for_branch(root, branch)
        requested_base = args.base or os.environ.get("GITHUB_BASE_REF", "").strip() or "main"
        base = _base_ref(root, requested_base)
        changed = _changed_files(root, base)
        task_file = task_path.relative_to(root).as_posix()
        outside = _outside_scope(changed, task.touch, task_file)
    except (OSError, ScopeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if outside:
        for path in outside:
            print(f"ERROR: {path} is outside {task.id} touch allowlist", file=sys.stderr)
        return 1

    print(f"OK: {task.id} scope contains {len(changed)} changed file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
