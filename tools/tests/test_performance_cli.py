"""Synthetic subprocess fixtures, not phone data or phase acceptance."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

from tools.tests.test_performance_validation import report

SCRIPT = Path(__file__).resolve().parents[1] / "performance_cli.py"


def run(root, *arguments):
    return subprocess.run(
        [sys.executable, str(SCRIPT), *map(str, arguments)],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )


def write(root, name, packet):
    path = root / name
    path.write_text(json.dumps(packet, ensure_ascii=False), encoding="utf-8")
    return path


def test_report_reads_original_capture_json_and_preserves_files(tmp_path):
    path = write(tmp_path, "żółć.json", report())
    before = path.read_bytes()
    result = run(tmp_path, "report", path)
    assert result.returncode == 0 and result.stderr == ""
    assert "# Diagnostic performance report" in result.stdout and "Żółć" in result.stdout
    assert "## Window 1: background" in result.stdout
    assert result.stdout == run(tmp_path, "report", path).stdout
    assert path.read_bytes() == before and list(tmp_path.iterdir()) == [path]


@pytest.mark.parametrize("format_name", ["json", "markdown"])
def test_comparison_formats_deltas_default_and_input_preservation(tmp_path, format_name):
    baseline = write(tmp_path, "baseline.json", report())
    candidate = write(tmp_path, "candidate.json", report(pending=0))
    before = (baseline.read_bytes(), candidate.read_bytes())
    result = run(tmp_path, "compare", baseline, candidate, "--format", format_name)
    assert result.returncode == 0 and result.stderr == "" and "Żółć" in result.stdout
    assert (
        result.stdout
        == run(tmp_path, "compare", baseline, candidate, "--format", format_name).stdout
    )
    if format_name == "json":
        packet = json.loads(result.stdout)
        assert packet["operator_supplied"] is True
        assert packet["deltas"]["pending"] == -1
        assert packet["baseline"]["windows"][0]["stats"]["pending"] == 1
        assert packet["candidate"]["windows"][0]["stats"]["pending"] == 0
    else:
        assert result.stdout == run(tmp_path, "compare", baseline, candidate).stdout
        assert "| `pending` | 1 count | 0 count | -1 count |" in result.stdout
    assert (baseline.read_bytes(), candidate.read_bytes()) == before
    assert set(tmp_path.iterdir()) == {baseline, candidate}


@pytest.mark.parametrize("command", ["report", "compare"])
@pytest.mark.parametrize(
    "kind", ["malformed", "duplicate", "tampered", "utf8", "missing", "directory"]
)
def test_errors_return_one_no_partial_output_or_input_mutation(tmp_path, command, kind):
    good = write(tmp_path, "good.json", report())
    path = tmp_path / "bad.json"
    if kind == "directory":
        path.mkdir()
    elif kind != "missing":
        packet = report()
        if kind == "tampered":
            packet["summary"]["samples"] += 1
        text = json.dumps(packet, ensure_ascii=False)
        if kind == "malformed":
            text = "{"
        elif kind == "duplicate":
            text = text.replace(
                '"schema_version": 1', '"schema_version": 1, "schema_version": 1', 1
            )
        path.write_bytes(b"\xff" if kind == "utf8" else text.encode("utf-8"))
    original = path.read_bytes() if path.is_file() else None
    args = (path,) if command == "report" else (good, path)
    result = run(tmp_path, command, *args)
    assert result.returncode == 1 and result.stdout == ""
    assert result.stderr.startswith("Performance analysis: ")
    if original is not None:
        assert path.read_bytes() == original
    assert json.loads(good.read_text())["summary"]["samples"] == 2


@pytest.mark.parametrize(
    "arguments",
    [
        [],
        ["unknown"],
        ["report"],
        ["compare", "one"],
        ["compare", "one", "two", "--format", "csv"],
        ["report", "file", "--format", "json"],
    ],
)
def test_usage_errors_return_two_without_a_report(tmp_path, arguments):
    result = run(tmp_path, *arguments)
    assert result.returncode == 2 and result.stdout == "" and "usage:" in result.stderr


def test_package_entrypoint_works_for_report(tmp_path):
    path = write(tmp_path, "input.json", report())
    result = subprocess.run(
        [sys.executable, "-m", "tools.performance_cli", "report", str(path)],
        cwd=SCRIPT.parent.parent,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0 and result.stderr == ""
    assert "# Diagnostic performance report" in result.stdout
