from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "context_pack.py"


def _fixture(root: Path) -> None:
    docs = root / "docs"
    tools = root / "tools"
    tasks = root / "tasks"
    docs.mkdir()
    tools.mkdir()
    tasks.mkdir()
    (docs / "ARCHITECTURE.md").write_text(
        "# Architecture\n\n## Areas\n\n| Area | Paths | Notes |\n|---|---|---|\n"
        "| `tools` | `tools/` | tooling |\n\n## Next\n",
        encoding="utf-8",
    )
    (docs / "GUIDE.md").write_text(
        "# Guide\n\n## Target Section\nkeep this\n### Nested\nkeep nested\n"
        "## Other\ndo not include\n",
        encoding="utf-8",
    )
    (tools / "api.gd").write_text(
        "## @api\nfunc build_pack(area: String) -> String:\n    return area\n",
        encoding="utf-8",
    )
    (tools / "z.py").write_text("VALUE = 1\n", encoding="utf-8")
    cache = tools / "__pycache__"
    cache.mkdir()
    (cache / "junk.pyc").write_bytes(b"x")
    for number, status in ((1, "done"), (2, "ready")):
        task_id = f"T-{number:04d}"
        (tasks / f"{task_id}-fixture.md").write_text(
            f"---\nid: {task_id}\ntitle: Fixture {task_id}\nepic: E01\ntype: infra\n"
            f"area: tools\nrisk: low\nexecutor: sol\nthink: med\nui: none\nstatus: {status}\n"
            "depends_on: []\ntouch:\n  - tools/**\nrevision: 1\n---\n",
            encoding="utf-8",
        )


def _run(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root), *args],
        text=True,
        capture_output=True,
        check=False,
    )


def test_context_pack_emits_area_api_docs_and_open_tasks(tmp_path: Path) -> None:
    _fixture(tmp_path)
    result = _run(
        tmp_path, "--area", "tools", "--ref", "docs/GUIDE.md#target-section"
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
