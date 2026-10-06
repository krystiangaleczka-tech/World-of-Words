from __future__ import annotations

import os
import subprocess
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2] / "spikes" / "s2-swipe"


def test_s2_measurement_regressions() -> None:
    result = subprocess.run(
        [
            os.environ.get("GODOT", "godot"),
            "--headless",
            "--path",
            str(PROJECT),
            "--script",
            "res://tests/test_measurement.gd",
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=30,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0, output
    assert "S2 measurement: 6 regression tests passed" in output, output
    assert "SCRIPT ERROR" not in output and "ERROR:" not in output, output
