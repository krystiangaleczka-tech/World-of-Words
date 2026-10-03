from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from collections.abc import Sequence
from pathlib import Path

import context_pack

TASK_ID = re.compile(r"^T-\d{4}$")
DOC_REF = re.compile(r"docs/[A-Za-z0-9_./-]+\.md#[\w.-]+")
CHECKLIST = (
    "Does the implementation match every Behavior item point by point?",
    "Does every test from Tests exist, and would it fail if the implementation were reverted?",
    "Does anything extend beyond the Goal or otherwise broaden scope?",
    "Are Godot 4 pitfalls avoided, types explicit, and magic numbers replaced by tokens/config?",
    "Are there no new singletons and no direct platform/ calls from features/?",
    "Are there no allocations in the swipe input path or in _process?",
    "Do analytics event names and config keys match their registries?",
    "Are manually connected signals disconnected, previous tweens killed, and node leaks avoided?",
)


def _task_path(root: Path, task_id: str) -> Path:
    if not TASK_ID.fullmatch(task_id):
        raise ValueError(f"invalid task id {task_id!r}; expected T-NNNN")
    matches = sorted((root / "tasks").glob(f"{task_id}-*.md"))
    if not matches:
        raise ValueError(f"task not found: {task_id}")
    if len(matches) != 1:
        names = ", ".join(path.name for path in matches)
        raise ValueError(f"multiple task files for {task_id}: {names}")
    return matches[0]


def _doc_refs(task_text: str) -> list[str]:
    return list(dict.fromkeys(DOC_REF.findall(task_text)))


def _git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "git command failed"
        raise ValueError(detail)
    return result.stdout


def _has_ref(root: Path, ref: str) -> bool:
    result = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", ref],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    return result.returncode == 0


def _base_ref(root: Path) -> str:
    requested = os.environ.get("GITHUB_BASE_REF", "").strip()
    candidates: list[str] = []
    if requested:
        candidates.extend((f"origin/{requested}", requested))
    candidates.extend(("origin/main", "main"))
    for candidate in candidates:
        if _has_ref(root, candidate):
            return candidate
    raise ValueError("cannot resolve base branch; expected origin/main or main")


def _diff(root: Path, base: str | None) -> str:
    resolved = base or _base_ref(root)
    return _git(\n        root, "diff", "--no-ext-diff", "--find-renames", f"{resolved}...HEAD", "--"\n    ).rstrip()


def build(root: Path, task_id: str, base: str | None = None) -> str:
    task_path = _task_path(root, task_id)
    task_text = task_path.read_text(encoding="utf-8").rstrip()
    refs = _doc_refs(task_text)
    diff = _diff(root, base)

    lines = [
        "# Review pack",
        "",
        f"Task: `{task_id}`",
        "",
        "## Task",
        "",
        f"### `{task_path.relative_to(root).as_posix()}`",
        "",
        task_text,
        "",
        "## Diff",
        "",
    ]
    if diff:
        lines.extend(("~~~diff", diff, "~~~"))
    else:
        lines.append("(no changes)")

    lines.extend(("", "## Cited documentation"))
    if refs:
        for ref in refs:
            lines.extend(("", f"### `{ref}`", "", context_pack._section(root, ref)))
    else:
        lines.extend(("", "(none)"))

    lines.extend(("", "## AI reviewer checklist", ""))
    lines.extend(f"{index}. {item}" for index, item in enumerate(CHECKLIST, start=1))
    return "\n".join(lines).rstrip() + "\n"


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build a deterministic task review pack.")
    parser.add_argument("task_id")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help=argparse.SUPPRESS)
    parser.add_argument("--base", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        print(build(args.root.resolve(), args.task_id, args.base), end="")
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
