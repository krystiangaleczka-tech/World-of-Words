from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "context_pack.py"


def _task(root: Path, task_id: str, status: str) -> None:
    path = root / "tasks" / f"{task_id}-fixture.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"""---
id: {task_id}
title: Fixture {task_id}
epic: E01
type: infra
area: tools
risk: low
executor: sol
think: med
ui: none
status: {status}
depends_on: []
touch:
  - tools/**
revision: 1
---
""",
        encoding="utf-8",
    )


def _fixture(root: Path) -> None:
    arch = root / "docs" / "ARCHITECTURE.md"
    arch.parent.mkdir(parents=True)
    arch.write_text(
        """# Architecture

## Areas

| Area | Paths | Notes |
|---|---|---|
| `tools` | `tools/` | tooling |

## Next
""",
        encoding="utf-8",
    )
    (root / "docs" / "GUIDE.md").write_text(
        """# Guide

## Target Section
keep this
### Nested
keep nested
## Other
do not include
""",
        encoding="utf-8",
    )
    tools = root / "tools"
    tools.mkdir()
    (tools / "api.gd").write_text(
        """## @api
func build_pack(area: String) -> String:
    return area
""",
        encoding="utf-8",
    )
    (tools / "z.py").write_text("VALUE = 1\n", encoding="utf-8")
    cache = tools / "__pycache__"
    cache.mkdir()
    (cache / "junk.pyc").write_bytes(b"x")
    _task(root, "T-0001", "done")
    _task(root, "T-0002", "ready")


def _run(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root), *args],
        text=True,
        capture_output=True,
        check=False,
    )


def test_context_pack_emits_area_map_api_docs_and_open_tasks(tmp_path: Path) -> None:
    _fixture(tmp_path)

    result = _run(
        tmp_path,
        "--area",
        "tools",
        "--ref",
        "docs/GUIDE.md#target-section",
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout.index("`tools/api.gd`") < result.stdout.index("`tools/z.py`")
    assert "`tools/api.gd:2` `func build_pack(area: String) -> String:`" in result.stdout
    assert "## Target Section\nkeep this\n### Nested\nkeep nested" in result.stdout
    assert "do not include" not in result.stdout
    assert "T-0002 [ready] tools" in result.stdout
    assert "T-0001 [done]" not in result.stdout
    assert "__pycache__" not in result.stdout


def test_context_pack_rejects_unknown_area(tmp_path: Path) -> None:
    _fixture(tmp_path)

    result = _run(tmp_path, "--area", "missing")

    assert result.returncode == 1
    assert "ERROR: unknown area 'missing'" in result.stderr


def test_context_pack_rejects_missing_anchor(tmp_path: Path) -> None:
    _fixture(tmp_path)

    result = _run(tmp_path, "--ref", "docs/GUIDE.md#missing")

    assert result.returncode == 1
    assert "ERROR: anchor not found: docs/GUIDE.md#missing" in result.stderr
