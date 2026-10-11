import csv
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.content import digest
from wordgame_pipeline.familiarity_report import build_report, main

PIPELINE = Path(__file__).parents[1]
REPO = PIPELINE.parent


@pytest.fixture
def workspace(tmp_path: Path) -> tuple[Path, Path, Path]:
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
    shutil.copytree(REPO / "game/content", content)
    return root, content, root / "reviews/pl/familiarity.csv"


def test_actual_report_is_deterministic_and_read_only(workspace: tuple, tmp_path: Path) -> None:
    root, content, catalog = workspace
    before = {
        p.relative_to(tmp_path): (p.read_bytes(), p.stat().st_mtime_ns)
        for p in tmp_path.rglob("*")
        if p.is_file()
    }
    report = build_report(root, content, catalog)
    assert report == build_report(root, content, catalog)
    assert report["schema_version"] == 1
    assert report["language"] == "pl"
    assert report["content_version"] == 2
    assert report["coverage"] == {"missing": 0, "proposed": 103, "reviewed": 0}
    manifest = json.loads((content / "pl/manifest.json").read_bytes())
    pack_rows = []
    assert report["inputs"]["catalog_sha256"] == digest(catalog.read_bytes())
    assert (
        report["inputs"]["tiers_sha256"]
        == json.loads((root / "content-inputs/pl.json").read_bytes())["tiers_sha256"]
    )
    assert report["inputs"]["packs"] == {
        entry["file"]: digest((content / "pl" / entry["file"]).read_bytes())
        for entry in manifest["packs"]
    }
    for entry in manifest["packs"]:
        pack_rows.extend(json.loads((content / "pl" / entry["file"]).read_bytes())["levels"])
    assert [row["slot"] for row in report["levels"]] == list(range(1, 66))
    for row, actual in zip(
        report["levels"], sorted(pack_rows, key=lambda row: row["slot"]), strict=True
    ):
        assert row["id"] == actual["id"]
        assert [r["word"] for r in row["required"]] == [w["w"] for w in actual["words"]]
        assert all(r["status"] == "proposed" and r["reviewer"] == "codex" for r in row["required"])
        assert "bonus" not in row
    assert before == {
        p.relative_to(tmp_path): (p.read_bytes(), p.stat().st_mtime_ns)
        for p in tmp_path.rglob("*")
        if p.is_file()
    }
    assert not (root / "build").exists()


def test_incomplete_catalog_reports_missing_and_ignores_extra_bonus(workspace: tuple) -> None:
    root, content, catalog = workspace
    catalog.write_text(
        "word,band,status,reviewer,rationale\n"
        "KOT,1,reviewed,fixture-curator,fixture judgment\n"
        "KUR,5,reviewed,fixture-curator,hard optional bonus\n",
        encoding="utf-8",
    )
    report = build_report(root, content, catalog)
    assert report["coverage"] == {"missing": 102, "proposed": 0, "reviewed": 1}
    assert report["levels"][0]["required"] == [
        {
            "word": "KOT",
            "band": 1,
            "status": "reviewed",
            "reviewer": "fixture-curator",
            "rationale": "fixture judgment",
        }
    ]
    assert report["levels"][1]["required"] == [
        {"word": "RAK", "band": None, "status": "missing", "reviewer": "", "rationale": ""}
    ]
    assert not any(r["word"] == "KUR" for level in report["levels"] for r in level["required"])


def test_catalog_changes_receipt_and_annotation(workspace: tuple) -> None:
    root, content, catalog = workspace
    before = build_report(root, content, catalog)
    with catalog.open(encoding="utf-8", newline="") as stream:
        rows = list(csv.reader(stream))
    row = next(row for row in rows[1:] if row[0] == "KOT")
    row[1:5] = ["2", "reviewed", "fixture-curator", "explicit fixture decision"]
    with catalog.open("w", encoding="utf-8", newline="") as stream:
        csv.writer(stream, lineterminator="\n").writerows(rows)
    after = build_report(root, content, catalog)
    assert before["inputs"]["catalog_sha256"] != after["inputs"]["catalog_sha256"]
    assert before["inputs"]["packs"] == after["inputs"]["packs"]
    assert after["coverage"] == {"missing": 0, "proposed": 102, "reviewed": 1}
    assert after["levels"][0]["required"][0]["band"] == 2


@pytest.mark.parametrize(
    "body", ["invalid", "word,band,status,reviewer,rationale\nXYZ,1,proposed,codex,note\n"]
)
def test_malformed_or_unknown_catalog_is_rejected(workspace: tuple, body: str) -> None:
    root, content, catalog = workspace
    catalog.write_text(body, encoding="utf-8")
    with pytest.raises(ValueError, match="catalog row"):
        build_report(root, content, catalog)


def test_replay_rejects_pack_tampering_even_with_matching_manifest(workspace: tuple) -> None:
    root, content, catalog = workspace
    pack_path = content / "pl/packs/c-0001-0065.json"
    pack = json.loads(pack_path.read_bytes())
    pack["levels"][-1]["seed"] += 1
    pack_path.write_bytes(canonical_bytes(pack))
    manifest_path = content / "pl/manifest.json"
    manifest = json.loads(manifest_path.read_bytes())
    manifest["packs"][0]["sha256"] = digest(pack_path.read_bytes())
    manifest_path.write_bytes(canonical_bytes(manifest))
    with pytest.raises(ValueError):
        build_report(root, content, catalog)


def test_cli_canonical_stdout_and_errors(workspace: tuple, capsys: pytest.CaptureFixture) -> None:
    root, content, catalog = workspace
    args = ["--root", str(root), "--content-root", str(content)]
    assert main(args) == 0
    output = capsys.readouterr()
    assert output.err == ""
    assert output.out.encode() == canonical_bytes(build_report(root, content, catalog))
    assert main(args + ["--catalog", str(catalog.with_name("missing.csv"))]) == 1
    output = capsys.readouterr()
    assert output.out == "" and "Familiarity report:" in output.err
    catalog.write_text("invalid", encoding="utf-8")
    assert main(args + ["--catalog", str(catalog)]) == 1
    output = capsys.readouterr()
    assert output.out == "" and "catalog row" in output.err


def test_module_entrypoint() -> None:
    result = subprocess.run(
        [sys.executable, "-m", "wordgame_pipeline.familiarity_report"],
        cwd=REPO,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0 and not result.stderr
    report = json.loads(result.stdout)
    assert result.stdout == canonical_bytes(report)
    assert report["coverage"] == {"missing": 0, "proposed": 103, "reviewed": 0}


def test_coverage_counts_repeated_required_words_once(
    workspace: tuple, monkeypatch: pytest.MonkeyPatch
) -> None:
    # Isolate the report aggregation from replay: a future valid campaign may
    # reuse a required form across levels, while coverage counts unique words.
    import wordgame_pipeline.familiarity_report as module

    root, content, catalog = workspace
    original_read = module.read_json

    def read_with_repeated_answer(path: Path) -> dict:
        data = original_read(path)
        if path.name == "c-0001-0065.json":
            data["levels"] = [
                {"slot": 2, "id": "second", "words": [{"w": "KOT"}]},
                {"slot": 1, "id": "first", "words": [{"w": "KOT"}]},
            ]
        return data

    monkeypatch.setattr(module, "check", lambda root, content: 2)
    monkeypatch.setattr(module, "read_json", read_with_repeated_answer)
    report = build_report(root, content, catalog)
    assert report["coverage"] == {"missing": 0, "proposed": 1, "reviewed": 0}
    assert [row["slot"] for row in report["levels"]] == [1, 2]
    assert [row["required"][0]["word"] for row in report["levels"]] == ["KOT", "KOT"]
