import shlex
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize(
    ("output", "engine_status", "success"),
    [
        ("SCRIPT ERROR: Parse Error: invalid test", 0, False),
        ('ERROR: Failed to load script "res://tests/test_bad.gd"', 0, False),
        ("ERROR: asserted push_error fixture\nAll tests passed", 0, True),
        ("engine failed", 7, False),
    ],
)
def test_make_test_rejects_skipped_scripts(tmp_path, output, engine_status, success):
    (tmp_path / "game").mkdir()
    (tmp_path / "Makefile").write_text((ROOT / "Makefile").read_text())
    engine = tmp_path / "fake-godot"
    engine.write_text(f"#!/bin/sh\nprintf '%s\\n' {shlex.quote(output)}\nexit {engine_status}\n")
    engine.chmod(0o755)
    result = subprocess.run(
        ["make", "-o", "import", "test", f"GODOT={engine}"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
    )
    assert (result.returncode == 0) is success, result.stdout + result.stderr
