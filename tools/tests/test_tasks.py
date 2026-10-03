from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "tasks.py"\nREPO_ROOT = SCRIPT.parents[1]


def _arch(root: Path, *areas: str) -> None:
    body = "\n".join(f"| \x60{area}\x60 | \x60x/\x60 | |" for area in areas)
    path = root / "docs" / "ARCHITECTURE.md"
    path.parent.mkdir(parents=True)
    architecture = (
        "# Architecture\n\n## Areas\n\n"
        "| Area | Paths | Notes |\n|---|---|---|\n"
        f"{body}\n\n## Next\n"
    )
    path.write_text(architecture, encoding="utf-8")


def _task(
    root: Path,
    task_id: str,
    *,
    area: str = "tools",
    status: str = "ready",
    depends: str = "[]",
    touch: tuple[str, ...] = ("tools/**",),
    risk: str = "low",
    omit: str | None = None,
) -> None:
    fields = [
        ("id", task_id),
        ("title", f"Task {task_id}"),
        ("epic", "E01"),
        ("type", "infra"),
        ("area", area),
        ("risk", risk),
        ("executor", "sol"),
        ("think", "high"),
        ("ui", "none"),
        ("status", status),
        ("depends_on", depends),
    ]
    lines = ["---"]
    lines.extend(f"{key}: {value}" for key, value in fields if key != omit)
    if omit != "touch":
        lines.append("touch:")
        lines.extend(f"  - {item}" for item in touch)
    if omit != "revision":
        lines.append("revision: 1")
    lines.extend(["---", ""])
    path = root / "tasks" / f"{task_id}-fixture.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def _run(root: Path, command: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), command, "--root", str(root)],
        text=True,
        capture_output=True,
        check=False,
    )


def test_current_repository_lints() -> None:
    result = _run(REPO_ROOT, "lint")

    assert result.returncode == 0, result.stderr


def test_lint_accepts_valid_tasks_and_ignores_non_task_files(tmp_path: Path) -> None:
    _arch(tmp_path, "tools")
    _task(tmp_path, "T-0001", status="done")
    (tmp_path / "tasks" / "ROADMAP.md").write_text("---\nbroken", encoding="utf-8")
    (tmp_path / "tasks" / "TEMPLATE.md").write_text("---\nbroken", encoding="utf-8")
    epic = tmp_path / "tasks" / "epics" / "T-9999-broken.md"
    epic.parent.mkdir()
    epic.write_text("---\nbroken", encoding="utf-8")

    result = _run(tmp_path, "lint")

    assert result.returncode == 0
    assert result.stdout.strip() == "OK: 1 task(s)"


def test_lint_validates_schema_and_area(tmp_path: Path) -> None:
    _arch(tmp_path, "tools")
    _task(tmp_path, "T-0001", area="not.real", omit="revision")

    result = _run(tmp_path, "lint")

    assert result.returncode == 1
    assert "missing fields: revision" in result.stderr
    assert "unknown area 'not.real'" in result.stderr


def test_lint_rejects_unknown_dependency(tmp_path: Path) -> None:
    _arch(tmp_path, "tools")
    _task(tmp_path, "T-0001", depends="[T-9999]")

    result = _run(tmp_path, "lint")

    assert result.returncode == 1
    assert "T-0001: unknown dependency T-9999" in result.stderr


def test_lint_rejects_dependency_cycle(tmp_path: Path) -> None:
    _arch(tmp_path, "tools")
    _task(tmp_path, "T-0001", depends="[T-0002]")
    _task(tmp_path, "T-0002", depends="[T-0001]", touch=("tools/other/**",))

    result = _run(tmp_path, "lint")

    assert result.returncode == 1
    assert "dependency cycle:" in result.stderr
    assert "T-0001" in result.stderr
    assert "T-0002" in result.stderr


def test_lint_accepts_legacy_med_risk(tmp_path: Path) -> None:
    _arch(tmp_path, "tools")
    _task(tmp_path, "T-0001", risk="med")

    result = _run(tmp_path, "lint")

    assert result.returncode == 0


def test_board_is_sorted_and_shows_status_area_and_title(tmp_path: Path) -> None:
    _arch(tmp_path, "tools", "docs")
    _task(tmp_path, "T-0002", area="docs", status="review", touch=("docs/**",))
    _task(tmp_path, "T-0001", status="done")

    result = _run(tmp_path, "board")

    assert result.returncode == 0
    lines = result.stdout.splitlines()
    assert lines[1].split(maxsplit=3)[:3] == ["T-0001", "done", "tools"]
    assert lines[2].split(maxsplit=3)[:3] == ["T-0002", "review", "docs"]
    assert "Task T-0002" in lines[2]


def test_plan_requires_ready_with_done_dependencies(tmp_path: Path) -> None:
    _arch(tmp_path, "tools", "docs", "ci")
    _task(tmp_path, "T-0001", status="done")
    _task(tmp_path, "T-0002", area="docs", depends="[T-0001]", touch=("docs/**",))
    _task(tmp_path, "T-0003", area="ci", depends="[T-0002]", touch=(".github/**",))

    result = _run(tmp_path, "plan")

    assert result.returncode == 0
    assert "T-0002" in result.stdout
    assert "T-0003" not in result.stdout


def test_plan_blocks_area_or_touch_conflicts_with_in_progress(tmp_path: Path) -> None:
    _arch(tmp_path, "tools", "docs", "ci", "store")
    _task(tmp_path, "T-0001", status="in_progress", touch=("tools/**",))
    _task(tmp_path, "T-0002", area="tools", touch=("other/**",))
    _task(tmp_path, "T-0003", area="docs", touch=("tools/tests/**",))
    _task(tmp_path, "T-0004", area="ci", touch=(".github/**",))

    result = _run(tmp_path, "plan")

    assert result.returncode == 0
    assert "T-0002" not in result.stdout
    assert "T-0003" not in result.stdout
    assert "T-0004" in result.stdout


def test_plan_returns_mutually_disjoint_ready_tasks(tmp_path: Path) -> None:
    _arch(tmp_path, "tools", "docs", "ci")
    _task(tmp_path, "T-0001", area="tools", touch=("shared/*.md",))
    _task(tmp_path, "T-0002", area="docs", touch=("shared/T-*.md",))
    _task(tmp_path, "T-0003", area="ci", touch=("ci/**",))

    result = _run(tmp_path, "plan")

    assert result.returncode == 0
    assert "T-0001" in result.stdout
    assert "T-0002" not in result.stdout
    assert "T-0003" in result.stdout
