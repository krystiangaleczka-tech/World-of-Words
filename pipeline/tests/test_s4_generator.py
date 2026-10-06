from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

GENERATOR = Path(__file__).parents[1] / "spikes" / "s4" / "generator.py"
LEVEL_RE = re.compile(r"^LEVEL \d+ .* size=(\d+)x(\d+)$", re.MULTILINE)


def _run() -> str:
    result = subprocess.run(
        [sys.executable, str(GENERATOR), "--count", "50", "--seed", "32032"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def test_s4_generates_50_levels_deterministically() -> None:
    first = _run()
    second = _run()
    assert first == second
    assert first.count("LEVEL ") == 50


def test_s4_levels_are_phone_sized_and_ascii_rendered() -> None:
    output = _run()
    sizes = [(int(width), int(height)) for width, height in LEVEL_RE.findall(output)]
    assert len(sizes) == 50
    assert all(width <= 10 and height <= 10 for width, height in sizes)

    grid_lines = [line for line in output.splitlines() if line and not line.startswith("LEVEL ")]
    assert grid_lines
    assert all(re.fullmatch(r"[A-Z.]+", line) for line in grid_lines)
