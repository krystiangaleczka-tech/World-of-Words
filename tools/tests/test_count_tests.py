from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "count_tests.py"


def _git(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )


def _write(root: Path, path: str, content: str) -> None:
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def _commit(root: Path, message: str) -> None:
    assert _git(root, "add", "-A").returncode == 0
    result = _git(root, "commit", "-m", message)
    assert result.returncode == 0, result.stderr


def _init_repo(root: Path) -> None:
    result = _git(root, "init", "-b", "main")
    assert result.returncode == 0, result.stderr
    assert _git(root, "config", "user.email", "tests@example.invalid").returncode == 0
    assert _git(root, "config", "user.name", "Test Count Tests").returncode == 0


def _run(
    root: Path,
    *,
    event_path: Path | None = None,
    base: str = "main",
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.pop("GITHUB_BASE_REF", None)
    env.pop("GITHUB_EVENT_PATH", None)
    if event_path is not None:
        env["GITHUB_EVENT_PATH"] = str(event_path)
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root), "--base", base],
        text=True,
        capture_output=True,
        check=False,
        env=env,
    )


def test_accepts_equal_or_higher_count_and_counts_python_and_gut(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write(
        tmp_path,
        "pipeline/tests/test_pipeline.py",
        "def test_one():\n    pass\n\nclass TestGroup:\n    def test_two(self):\n        pass\n",
    )
    _write(tmp_path, "game/tests/unit/test_words.gd", "func test_word():\n\tpass\n")
    _commit(tmp_path, "base")
    assert _git(tmp_path, "switch", "-c", "task").returncode == 0
    _write(tmp_path, "tools/tests/test_more.py", "async def test_three():\n    pass\n")
    _commit(tmp_path, "add test")

    result = _run(tmp_path)

    assert result.returncode == 0, result.stderr
    assert "OK: test count 4 vs 3 on main" in result.stdout


def test_rejects_drop_and_reports_counts(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write(
        tmp_path,
        "tools/tests/test_sample.py",
        "def test_one():\n    pass\n\ndef test_two():\n    pass\n",
    )
    _commit(tmp_path, "base")
    assert _git(tmp_path, "switch", "-c", "task").returncode == 0
    _write(tmp_path, "tools/tests/test_sample.py", "def test_one():\n    pass\n")
    _commit(tmp_path, "remove test")

    result = _run(tmp_path)

    assert result.returncode == 1
    assert "ERROR: test count dropped by 1: 1 vs 2 on main" in result.stderr
    assert "test-count-exception" in result.stderr


def test_pr_label_allows_intentional_drop(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write(tmp_path, "tools/tests/test_sample.py", "def test_one():\n    pass\n")
    _commit(tmp_path, "base")
    assert _git(tmp_path, "switch", "-c", "task").returncode == 0
    _write(tmp_path, "tools/tests/test_sample.py", "# intentionally removed\n")
    _commit(tmp_path, "remove test")
    event_path = tmp_path / "event.json"
    event_path.write_text(
        json.dumps({"pull_request": {"labels": [{"name": "test-count-exception"}]}}),
        encoding="utf-8",
    )

    result = _run(tmp_path, event_path=event_path)

    assert result.returncode == 0, result.stderr
    assert "drop 1 allowed by test-count-exception" in result.stdout


def test_non_exception_label_does_not_allow_drop(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write(tmp_path, "tools/tests/test_sample.py", "def test_one():\n    pass\n")
    _commit(tmp_path, "base")
    assert _git(tmp_path, "switch", "-c", "task").returncode == 0
    _write(tmp_path, "tools/tests/test_sample.py", "# removed\n")
    _commit(tmp_path, "remove test")
    event_path = tmp_path / "event.json"
    event_path.write_text(
        json.dumps({"pull_request": {"labels": [{"name": "risk/low"}]}}),
        encoding="utf-8",
    )

    result = _run(tmp_path, event_path=event_path)

    assert result.returncode == 1


def test_origin_base_is_used_when_local_base_branch_is_missing(tmp_path: Path) -> None:
    remote = tmp_path / "remote.git"
    work = tmp_path / "work"
    assert _git(tmp_path, "init", "--bare", str(remote)).returncode == 0
    work.mkdir()
    _init_repo(work)
    _write(work, "tools/tests/test_sample.py", "def test_one():\n    pass\n")
    _commit(work, "base")
    assert _git(work, "remote", "add", "origin", str(remote)).returncode == 0
    assert _git(work, "push", "-u", "origin", "main").returncode == 0
    assert _git(work, "switch", "-c", "task").returncode == 0
    assert _git(work, "branch", "-D", "main").returncode == 0
    _write(work, "tools/tests/test_more.py", "def test_two():\n    pass\n")
    _commit(work, "add test")

    result = _run(work)

    assert result.returncode == 0, result.stderr
    assert "on origin/main" in result.stdout


def test_invalid_github_event_payload_fails_clearly(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write(tmp_path, "tools/tests/test_sample.py", "def test_one():\n    pass\n")
    _commit(tmp_path, "base")
    assert _git(tmp_path, "switch", "-c", "task").returncode == 0
    event_path = tmp_path / "event.json"
    event_path.write_text("not json", encoding="utf-8")

    result = _run(tmp_path, event_path=event_path)

    assert result.returncode == 1
    assert "ERROR: cannot read GitHub event payload" in result.stderr
