from __future__ import annotations

import argparse
import ast
import json
import os
import re
import subprocess
import sys
from collections.abc import Sequence
from pathlib import Path

TEST_ROOTS = ("game/tests", "pipeline/tests", "tools/tests")
EXCEPTION_LABEL = "test-count-exception"
GDSCRIPT_TEST_RE = re.compile(r"^\s*func\s+test_[A-Za-z0-9_]*\s*\(", re.MULTILINE)


class TestCountError(Exception):
    pass


def _git(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )


def _ref(root: Path, requested: str) -> str:
    candidates = [requested]
    if not requested.startswith("origin/"):
        candidates.append(f"origin/{requested}")
    for candidate in candidates:
        result = _git(root, "rev-parse", "--verify", "--quiet", f"{candidate}^{{commit}}")
        if result.returncode == 0:
            return candidate
    raise TestCountError(f"ref {requested!r} does not exist locally or under origin/")


def _test_paths(root: Path, ref: str) -> list[str]:
    result = _git(root, "ls-tree", "-r", "--name-only", ref, "--", *TEST_ROOTS)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown git error"
        raise TestCountError(f"cannot list tests at {ref}: {detail}")
    return sorted(path for path in result.stdout.splitlines() if path.endswith((".py", ".gd")))


def _source_at(root: Path, ref: str, path: str) -> str:
    result = _git(root, "show", f"{ref}:{path}")
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown git error"
        raise TestCountError(f"cannot read {path} at {ref}: {detail}")
    return result.stdout


def _python_test_count(source: str, path: str) -> int:
    try:
        tree = ast.parse(source, filename=path)
    except SyntaxError as exc:
        line = exc.lineno or "?"
        raise TestCountError(f"cannot parse Python test {path}:{line}: {exc.msg}") from exc

    count = 0
    for node in tree.body:
        if (
            isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
            and node.name.startswith("test_")
        ):
            count += 1
        elif isinstance(node, ast.ClassDef) and node.name.startswith("Test"):
            count += sum(
                isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef))
                and item.name.startswith("test_")
                for item in node.body
            )
    return count


def _count_source(source: str, path: str) -> int:
    if path.endswith(".py"):
        return _python_test_count(source, path)
    if path.endswith(".gd"):
        return len(GDSCRIPT_TEST_RE.findall(source))
    return 0


def _count_at(root: Path, ref: str) -> int:
    total = 0
    for path in _test_paths(root, ref):
        total += _count_source(_source_at(root, ref, path), path)
    return total


def _event_labels() -> set[str]:
    raw_path = os.environ.get("GITHUB_EVENT_PATH", "").strip()
    if not raw_path:
        return set()

    path = Path(raw_path)
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise TestCountError(f"cannot read GitHub event payload {path}: {exc}") from exc

    pull_request = payload.get("pull_request")
    if not isinstance(pull_request, dict):
        return set()
    labels = pull_request.get("labels", [])
    if not isinstance(labels, list):
        return set()

    names: set[str] = set()
    for label in labels:
        if isinstance(label, dict):
            name = label.get("name")
            if isinstance(name, str):
                names.add(name)
    return names


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Fail when the committed test count drops relative to the base branch."
    )
    parser.add_argument("--base", default=None, help="Base branch/ref (default: CI base or main).")
    parser.add_argument("--head", default="HEAD", help=argparse.SUPPRESS)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    root = args.root.resolve()
    try:
        requested_base = args.base or os.environ.get("GITHUB_BASE_REF", "").strip() or "main"
        base = _ref(root, requested_base)
        head = _ref(root, args.head)
        base_count = _count_at(root, base)
        head_count = _count_at(root, head)
        labels = _event_labels()
    except (OSError, TestCountError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if head_count < base_count:
        drop = base_count - head_count
        if EXCEPTION_LABEL in labels:
            print(
                f"OK: test count {head_count} vs {base_count} on {base}; "
                f"drop {drop} allowed by {EXCEPTION_LABEL}"
            )
            return 0
        print(
            f"ERROR: test count dropped by {drop}: {head_count} vs {base_count} on {base}; "
            f"add PR label {EXCEPTION_LABEL} only when the reduction is intentional",
            file=sys.stderr,
        )
        return 1

    print(f"OK: test count {head_count} vs {base_count} on {base}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
