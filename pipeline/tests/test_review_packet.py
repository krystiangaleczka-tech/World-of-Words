import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.familiarity_report import build_report
from wordgame_pipeline.review_packet import main
from wordgame_pipeline.review_worksheet import export_worksheet

PIPELINE = Path(__file__).parents[1]
REPO = PIPELINE.parent
CONTENT = REPO / "game/content"
CATALOG = PIPELINE / "reviews/pl/familiarity.csv"


def arguments() -> list[str]:
    return ["--root", str(PIPELINE), "--content-root", str(CONTENT)]


def test_actual_default_html_and_csv(capsys: pytest.CaptureFixture) -> None:
    assert main(arguments()) == 0
    output = capsys.readouterr()
    assert not output.err and output.out.startswith('<!doctype html><html lang="pl">')
    assert output.out.count("<article ") == 65
    assert "Propozycje: 103" in output.out and "Ocenione: 0" in output.out
    assert "<script" not in output.out
    assert main(arguments() + ["--format", "csv", "--catalog", str(CATALOG)]) == 0
    output = capsys.readouterr()
    assert not output.err
    assert output.out == export_worksheet(build_report(PIPELINE, CONTENT, CATALOG))
    assert len(output.out.splitlines()) == 104


def test_comparison_output_is_canonical_and_not_approval(capsys: pytest.CaptureFixture) -> None:
    assert main(arguments() + ["--format", "comparison", "--candidate", str(CATALOG)]) == 0
    output = capsys.readouterr()
    assert not output.err
    data = json.loads(output.out)
    assert output.out.encode() == canonical_bytes(data)
    assert data["changes"] == [] and len(data["early_check"]["issues"]) == 24
    assert data["coverage"]["proposed"] == 103


@pytest.mark.parametrize(
    "options",
    [
        ["--format", "comparison"],
        ["--candidate", str(CATALOG)],
        ["--format", "csv", "--candidate", str(CATALOG)],
        ["--catalog", "does-not-exist.csv"],
        ["--format", "comparison", "--candidate", "does-not-exist.csv"],
    ],
)
def test_invalid_options_and_paths_have_stderr_only(
    options: list[str], capsys: pytest.CaptureFixture
) -> None:
    assert main(arguments() + options) == 1
    output = capsys.readouterr()
    assert output.out == "" and "Review packet:" in output.err


def test_malformed_catalog_is_rejected(tmp_path: Path, capsys: pytest.CaptureFixture) -> None:
    catalog = tmp_path / "draft.csv"
    catalog.write_text("invalid", encoding="utf-8")
    assert main(arguments() + ["--catalog", str(catalog)]) == 1
    output = capsys.readouterr()
    assert output.out == "" and "catalog row" in output.err


def test_copied_workspace_outputs_do_not_write_files(
    tmp_path: Path, capsys: pytest.CaptureFixture
) -> None:
    root = tmp_path / "pipeline"
    for folder in (
        "config",
        "sources",
        "schema",
        "overrides",
        "handmade",
        "content-inputs",
        "content-evidence",
        "reviews",
    ):
        shutil.copytree(PIPELINE / folder, root / folder)
    shutil.copy(REPO / "NOTICE", tmp_path)
    content = tmp_path / "game/content"
    shutil.copytree(CONTENT, content)
    before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in tmp_path.rglob("*") if p.is_file()}
    args = ["--root", str(root), "--content-root", str(content)]
    for fmt in ("html", "csv", "comparison"):
        options = (
            ["--candidate", str(root / "reviews/pl/familiarity.csv")] if fmt == "comparison" else []
        )
        assert main(args + ["--format", fmt] + options) == 0
        assert not capsys.readouterr().err
    assert before == {
        p: (p.read_bytes(), p.stat().st_mtime_ns) for p in tmp_path.rglob("*") if p.is_file()
    }
    manifest_path = content / "pl/manifest.json"
    manifest = json.loads(manifest_path.read_bytes())
    manifest["content_version"] += 1
    manifest_path.write_bytes(canonical_bytes(manifest))
    assert main(args) == 1
    output = capsys.readouterr()
    assert output.out == "" and "Review packet:" in output.err


def test_module_entrypoint_defaults() -> None:
    result = subprocess.run(
        [sys.executable, "-m", "wordgame_pipeline.review_packet"],
        cwd=REPO,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0 and not result.stderr
    assert result.stdout.startswith(b"<!doctype html>")
    assert result.stdout.count(b"<article ") == 65
