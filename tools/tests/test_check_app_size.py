"""Real artifact bytes and CLI integration, including exact NFR-05 boundaries."""

import hashlib
import json
from pathlib import Path

import pytest

from tools.check_app_size import BUDGET_BYTES, WARNING_BYTES, main, measure


@pytest.mark.parametrize(
    ("size", "warning", "over"),
    [
        (WARNING_BYTES - 1, False, False),
        (WARNING_BYTES, True, False),
        (BUDGET_BYTES, True, False),
        (BUDGET_BYTES + 1, True, True),
    ],
)
def test_thresholds(tmp_path, size, warning, over):
    artifact = tmp_path / "artifact.apk"
    with artifact.open("wb") as output:
        output.truncate(size)
    result = measure(artifact, "debug-apk")
    assert result["size_bytes"] == size
    assert result["budget_bytes"] == 80_000_000
    assert result["warning_bytes"] == 72_000_000
    assert result["warning"] is warning
    assert result["over_budget"] is over


@pytest.mark.parametrize("with_summary", [False, True])
def test_cli_reports_actual_bytes(tmp_path, monkeypatch, capsys, with_summary):
    artifact = tmp_path / "artifact.apk"
    payload = b"real artifact bytes\x00\xff"
    artifact.write_bytes(payload)
    report = tmp_path / "reports/size.json"
    summary = tmp_path / "summary.md"
    monkeypatch.delenv("GITHUB_STEP_SUMMARY", raising=False)
    if with_summary:
        summary.write_text("Existing summary\n")
        monkeypatch.setenv("GITHUB_STEP_SUMMARY", str(summary))
    assert main([str(artifact), "--measurement", "debug-apk", "--report", str(report)]) == 0
    result = json.loads(report.read_text())
    assert result["sha256"] == hashlib.sha256(payload).hexdigest()
    assert result["size_bytes"] == len(payload)
    assert result["artifact"] == "artifact.apk"
    assert result["measurement"] == "debug-apk"
    assert result["schema_version"] == 1
    assert result["budget_percent"] == len(payload) * 100 / 80_000_000
    stdout = capsys.readouterr().out
    assert "growth proxies" in stdout and "debug-apk" in stdout
    assert "::warning" not in stdout
    if with_summary:
        assert summary.read_text().startswith("Existing summary\nApp size")
        assert "release gate" in summary.read_text()
    else:
        assert not summary.exists()


def test_large_artifact_warns_without_failing(tmp_path, monkeypatch, capsys):
    monkeypatch.delenv("GITHUB_STEP_SUMMARY", raising=False)
    artifact = tmp_path / "artifact.apk"
    with artifact.open("wb") as output:
        output.truncate(BUDGET_BYTES + 1)
    report = tmp_path / "report.json"
    assert main([str(artifact), "--measurement", "release-aab", "--report", str(report)]) == 0
    assert "::warning title=App size budget::" in capsys.readouterr().out
    assert json.loads(report.read_text())["over_budget"] is True


@pytest.mark.parametrize(
    "kind", ["missing", "empty", "directory", "report-directory", "same-file", "hardlink"]
)
def test_invalid_io_fails_without_success(tmp_path, monkeypatch, capsys, kind):
    monkeypatch.delenv("GITHUB_STEP_SUMMARY", raising=False)
    artifact = tmp_path / "artifact.apk"
    report = tmp_path / "report.json"
    if kind != "missing":
        artifact.write_bytes(b"" if kind == "empty" else b"artifact")
    if kind == "directory":
        artifact.unlink()
        artifact.mkdir()
    if kind == "report-directory":
        report.mkdir()
    if kind == "hardlink":
        report.hardlink_to(artifact)
    if kind == "same-file":
        report = artifact
    assert main([str(artifact), "--measurement", "debug-apk", "--report", str(report)]) == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert "App size check failed" in captured.err
    assert "Traceback" not in captured.err
    if kind in ("same-file", "hardlink"):
        assert artifact.read_bytes() == b"artifact"


def test_ci_measures_after_build_and_uploads_report():
    workflow = (Path(__file__).resolve().parents[2] / ".github/workflows/ci.yml").read_text()
    android = workflow.split("  android-build:\n")[1].split("  release-inspection:\n")[0]
    assert android.index("tools/android_debug_build.py") < android.index("tools/check_app_size.py")
    assert android.index("tools/check_app_size.py") < android.index("actions/upload-artifact@v4")
    assert "--measurement debug-apk --report builds/android-debug-size.json" in android
    upload = android.split("actions/upload-artifact@v4")[1]
    assert "builds/android-debug-size.json" in upload
