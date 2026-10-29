from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "check_scope.py"


def _git(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )


def _write_architecture(root: Path) -> None:
    path = root / "docs" / "ARCHITECTURE.md"
    path.parent.mkdir(parents=True)
    path.write_text(
        "# Architecture\n\n"
        "## Areas\n\n"
        "| Area | Paths | Notes |\n"
        "|---|---|---|\n"
        "| `tools` | `tools/` | Tooling |\n\n"
        "## Next\n",
        encoding="utf-8",
    )


def _write_task(root: Path, touch: tuple[str, ...]) -> Path:
    lines = [
        "---",
        "id: T-0020",
        "title: Scope fixture",
        "epic: E01",
        "type: infra",
        "area: tools",
        "risk: medium",
        "executor: sol",
        "think: med",
        "ui: none",
        "status: ready",
        "depends_on: []",
        "touch:",
    ]
    lines.extend(f"  - {item}" for item in touch)
    lines.extend(["revision: 1", "---", ""])
    path = root / "tasks" / "T-0020-scope-fixture.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def _init_repo(
    root: Path,
    *,
    branch: str = "t/0020-scope-check",
    base_files: dict[str, str] | None = None,
) -> None:
    result = _git(root, "init", "-b", "main")
    assert result.returncode == 0, result.stderr
    assert _git(root, "config", "user.email", "tests@example.invalid").returncode == 0
    assert _git(root, "config", "user.name", "Scope Tests").returncode == 0
    _write_architecture(root)
    for name, content in (base_files or {}).items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    assert _git(root, "add", ".").returncode == 0
    result = _git(root, "commit", "-m", "base")
    assert result.returncode == 0, result.stderr
    result = _git(root, "switch", "-c", branch)
    assert result.returncode == 0, result.stderr


def _commit(root: Path, message: str = "task changes") -> None:
    assert _git(root, "add", "-A").returncode == 0
    result = _git(root, "commit", "-m", message)
    assert result.returncode == 0, result.stderr


def _run(
    root: Path,
    *,
    env_overrides: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.pop("GITHUB_HEAD_REF", None)
    env.pop("GITHUB_BASE_REF", None)
    env.update(env_overrides or {})
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root), "--base", "main"],
        text=True,
        capture_output=True,
        check=False,
        env=env,
    )


def test_resolves_task_branch_and_allows_own_task_file(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_task(tmp_path, ("tools/check_scope.py",))
    _commit(tmp_path)

    result = _run(tmp_path)

    assert result.returncode == 0, result.stderr
    assert "OK: T-0020" in result.stdout


def test_accepts_exact_and_recursive_touch_paths(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_task(tmp_path, ("tools/check_scope.py", "tools/tests/**"))
    exact = tmp_path / "tools" / "check_scope.py"
    nested = tmp_path / "tools" / "tests" / "example.py"
    nested.parent.mkdir(parents=True)
    exact.write_text("# exact\n", encoding="utf-8")
    nested.write_text("# nested\n", encoding="utf-8")
    _commit(tmp_path)

    result = _run(tmp_path)

    assert result.returncode == 0, result.stderr


def test_rejects_out_of_scope_path_and_names_it(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_task(tmp_path, ("tools/**",))
    (tmp_path / "README.md").write_text("outside\n", encoding="utf-8")
    _commit(tmp_path)

    result = _run(tmp_path)

    assert result.returncode == 1
    assert "ERROR: README.md is outside T-0020 touch allowlist" in result.stderr


def test_rejects_non_task_branch(tmp_path: Path) -> None:
    _init_repo(tmp_path, branch="feature/not-a-task")
    _write_task(tmp_path, ("tools/**",))
    _commit(tmp_path)

    result = _run(tmp_path)

    assert result.returncode == 1
    assert "must match t/NNNN-*" in result.stderr


def test_uses_github_head_ref_when_checkout_is_detached(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_task(tmp_path, ("tools/**",))
    _commit(tmp_path)
    assert _git(tmp_path, "checkout", "--detach").returncode == 0

    result = _run(tmp_path, env_overrides={"GITHUB_HEAD_REF": "t/0020-scope-check"})

    assert result.returncode == 0, result.stderr


def test_single_star_does_not_cross_separator_but_double_star_does(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    task_path = _write_task(tmp_path, ("tools/*.py",))
    nested = tmp_path / "tools" / "tests" / "example.py"
    nested.parent.mkdir(parents=True)
    nested.write_text("# nested\n", encoding="utf-8")
    _commit(tmp_path)

    result = _run(tmp_path)
    assert result.returncode == 1
    assert "tools/tests/example.py" in result.stderr

    task_path.write_text(
        task_path.read_text(encoding="utf-8").replace("tools/*.py", "tools/**"),
        encoding="utf-8",
    )
    _commit(tmp_path, "widen fixture scope")

    result = _run(tmp_path)
    assert result.returncode == 0, result.stderr


def test_rename_keeps_old_path_in_scope_check(tmp_path: Path) -> None:
    _init_repo(tmp_path, base_files={"docs/secret.txt": "secret\n"})
    _write_task(tmp_path, ("tools/**",))
    target = tmp_path / "tools" / "secret.txt"
    target.parent.mkdir(parents=True)
    result = _git(tmp_path, "mv", "docs/secret.txt", "tools/secret.txt")
    assert result.returncode == 0, result.stderr
    _commit(tmp_path)

    result = _run(tmp_path)

    assert result.returncode == 1
    assert "docs/secret.txt" in result.stderr


def test_planner_accepts_only_docs_roadmap_epics_and_task_markdown(tmp_path: Path) -> None:
    _init_repo(tmp_path, branch="plan/e22-wave1")
    _write_task(tmp_path, ("tools/**",))
    doc = tmp_path / "docs" / "PRODUCT.md"
    doc.write_text("# Reviewed product goals\\n", encoding="utf-8")
    roadmap = tmp_path / "tasks" / "ROADMAP.md"
    roadmap.write_text("# Replanned pipeline\\n", encoding="utf-8")
    epic = tmp_path / "tasks" / "epics" / "E22-content.md"
    epic.parent.mkdir(parents=True)
    epic.write_text("# Content wave\\n", encoding="utf-8")
    _commit(tmp_path)

    result = _run(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "OK: planner scope" in result.stdout


def test_planner_rejects_executable_and_unknown_document(tmp_path: Path) -> None:
    _init_repo(tmp_path, branch="plan/e22-no-code")
    _write_task(tmp_path, ("tools/**",))
    executable = tmp_path / "tools" / "bad.py"
    executable.parent.mkdir(parents=True, exist_ok=True)
    executable.write_text("print('changed')\\n", encoding="utf-8")
    other = tmp_path / "docs" / "private.txt"
    other.write_text("not in planner allowlist\\n", encoding="utf-8")
    _commit(tmp_path)

    result = _run(tmp_path)
    assert result.returncode == 1
    assert "ERROR: tools/bad.py is outside planner touch allowlist" in result.stderr
    assert "ERROR: docs/private.txt is outside planner touch allowlist" in result.stderr


def test_planner_rejects_rename_from_disallowed_old_path(tmp_path: Path) -> None:
    _init_repo(
        tmp_path,
        branch="plan/e22-rename",
        base_files={"tools/private.py": "# private\\n"},
    )
    dest = tmp_path / "docs" / "PRODUCT.md"
    assert _git(tmp_path, "mv", "tools/private.py", str(dest.relative_to(tmp_path))).returncode == 0
    _commit(tmp_path)

    result = _run(tmp_path)
    assert result.returncode == 1
    assert "tools/private.py is outside planner touch allowlist" in result.stderr


def test_planner_rejects_nested_branch_or_no_changes(tmp_path: Path) -> None:
    _init_repo(tmp_path, branch="plan/e22")
    assert _run(tmp_path).returncode == 1
    _write_task(tmp_path, ("tools/**",))
    _commit(tmp_path)
    assert _run(tmp_path).returncode == 0

    assert _git(tmp_path, "switch", "-c", "plan/e22/nested").returncode == 0
    result = _run(tmp_path)
    assert result.returncode == 1
    assert "must match t/NNNN-*" in result.stderr
