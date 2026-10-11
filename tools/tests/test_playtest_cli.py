"""Subprocess checks with blank/synthetic records, never real playtest evidence."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

from tools.playtest_worksheet import build_worksheet, render_worksheet

SCRIPT = Path(__file__).resolve().parents[1] / "playtest_cli.py"


def run(root, *arguments):
    return subprocess.run(
        [sys.executable, str(SCRIPT), *map(str, arguments)],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )


def test_template_is_blank_valid_deterministic_and_writes_no_files(tmp_path):
    first = run(tmp_path, "template")
    assert first.returncode == 0 and first.stderr == ""
    assert first.stdout == render_worksheet() == run(tmp_path, "template").stdout
    assert json.loads(first.stdout) == build_worksheet()
    assert list(tmp_path.iterdir()) == []


def test_template_validate_report_roundtrip_preserves_original_bytes(tmp_path):
    path = tmp_path / "worksheet.json"
    path.write_text(run(tmp_path, "template").stdout, encoding="utf-8")
    before = path.read_bytes()
    validation = run(tmp_path, "validate", path)
    assert validation.returncode == 0 and validation.stderr == ""
    assert validation.stdout == "Valid worksheet format; observations and gates are unverified.\n"
    report = run(tmp_path, "report", path, "--format", "json")
    assert report.returncode == 0 and report.stderr == ""
    document = json.loads(report.stdout)
    assert document["totals"]["sessions_with_complete_protocol_record"] == 0
    assert document["totals"]["wants_continue_unknown"] == 5
    assert document["operator_supplied"] is True
    assert report.stdout == run(tmp_path, "report", path, "--format", "json").stdout
    assert path.read_bytes() == before
    assert list(tmp_path.iterdir()) == [path]


@pytest.mark.parametrize("format_name", ["json", "markdown"])
def test_unicode_partial_assisted_records_and_default_markdown(tmp_path, format_name):
    packet = build_worksheet()
    packet["sessions"][0].update(notes="synthetic Żółć | <tag>", help_given=True, active_seconds=10)
    path = tmp_path / "żółć.json"
    path.write_text(json.dumps(packet, ensure_ascii=False), encoding="utf-8")
    report = run(tmp_path, "report", path, "--format", format_name)
    assert report.returncode == 0 and report.stderr == ""
    assert "Żółć" in report.stdout
    if format_name == "json":
        row = json.loads(report.stdout)["sessions"][0]
        assert row["deviations"] == ["help_given", "under_20_active_minutes"]
        assert row["observations"]["notes"] == "synthetic Żółć | <tag>"
    else:
        assert report.stdout == run(tmp_path, "report", path).stdout
        assert "# Outsider playtest observations" in report.stdout
        assert "<tag>" not in report.stdout and "&lt;tag&gt;" in report.stdout


@pytest.mark.parametrize("command", ["validate", "report"])
@pytest.mark.parametrize(
    "kind", ["malformed", "duplicate", "wrong_type", "utf8", "missing", "directory"]
)
def test_bad_input_returns_one_no_partial_stdout_and_preserves_bytes(tmp_path, command, kind):
    path = tmp_path / "input.json"
    if kind == "directory":
        path.mkdir()
    elif kind != "missing":
        text = render_worksheet()
        if kind == "malformed":
            text = "{"
        elif kind == "duplicate":
            text = text.replace('"schema_version": 1', '"schema_version": 1, "schema_version": 1')
        elif kind == "wrong_type":
            text = text.replace('"active_seconds": null', '"active_seconds": true', 1)
        path.write_bytes(b"\xff" if kind == "utf8" else text.encode("utf-8"))
    before = path.read_bytes() if path.is_file() else None
    result = run(tmp_path, command, path)
    assert result.returncode == 1 and result.stdout == ""
    assert result.stderr.startswith("Playtest worksheet: ")
    if before is not None:
        assert path.read_bytes() == before


@pytest.mark.parametrize(
    "arguments",
    [
        [],
        ["unknown"],
        ["validate"],
        ["report"],
        ["template", "extra"],
        ["report", "file", "--format", "csv"],
    ],
)
def test_usage_errors_return_two_and_no_report(tmp_path, arguments):
    result = run(tmp_path, *arguments)
    assert result.returncode == 2 and result.stdout == ""
    assert "usage:" in result.stderr


def test_module_entry_point_also_works():
    root = SCRIPT.parent.parent
    result = subprocess.run(
        [sys.executable, "-m", "tools.playtest_cli", "template"],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == render_worksheet()
