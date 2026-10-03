from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "review_pack.py"


def _git(root: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=root, check=True, capture_output=True, text=True)


def _fixture(root: Path, *, ref: str = "docs/GUIDE.md#target-section") -> None:
    docs = root / "docs"
    tasks = root / "tasks"
    docs.mkdir()
    tasks.mkdir()
    (docs / "GUIDE.md").write_text(
        "# Guide\n\n## Target Section\nkeep this\n### Nested\nkeep nested\n"
        "## Other\ndo not include\n",
        encoding="utf-8",
    )
    (tasks / "T-0025-fixture.md").write_text(
        "---\nid: T-0025\ntitle: Fixture\n---\n\n"
        "## Goal\nBuild the review pack.\n\n"
        f"## Context\n- `{ref}`\n- `{ref}`\n\n"
        "## Specification\n### Behavior\n1. Emit a pack.\n",
        encoding="utf-8",
    )
    (root / "sample.txt").write_text("before\n", encoding="utf-8")

    _git(root, "init", "-b", "main")
    _git(root, "config", "user.email", "test@example.com")
    _git(root, "config", "user.name", "Review Pack Test")
    _git(root, "add", ".")
    _git(root, "commit", "-m", "base")
    _git(root, "checkout", "-b", "t/0025-review-pack")
    (root / "sample.txt").write_text("after\n", encoding="utf-8")
    _git(root, "add", ".")
    _git(root, "commit", "-m", "change")


def _run(root: Path, task_id: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root), task_id],
        text=True,
        capture_output=True,
        check=False,
    )


def test_review_pack_emits_task_diff_docs_and_checklist(tmp_path: Path) -> None:
    _fixture(tmp_path)
    result = _run(tmp_path, "T-0025")

    assert result.returncode == 0, result.stderr
    assert "## Task" in result.stdout
    assert "Build the review pack." in result.stdout
    assert "## Diff" in result.stdout
    assert "-before" in result.stdout
    assert "+after" in result.stdout
    assert result.stdout.count("### `docs/GUIDE.md#target-section`") == 1
    assert "## Target Section\nkeep this\n### Nested\nkeep nested" in result.stdout
    assert "do not include" not in result.stdout
    assert "## AI reviewer checklist" in result.stdout
    for index in range(1, 9):
        assert f"{index}. " in result.stdout


def test_review_pack_rejects_unknown_task(tmp_path: Path) -> None:
    _fixture(tmp_path)
    result = _run(tmp_path, "T-9999")

    assert result.returncode == 1
    assert "ERROR: task not found: T-9999" in result.stderr


def test_review_pack_rejects_missing_doc_anchor(tmp_path: Path) -> None:
    _fixture(tmp_path, ref="docs/GUIDE.md#missing")
    result = _run(tmp_path, "T-0025")

    assert result.returncode == 1
    assert "ERROR: anchor not found: docs/GUIDE.md#missing" in result.stderr
