import csv
import io
import json
import shutil
from pathlib import Path
from types import SimpleNamespace

import pytest
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.content import digest
from wordgame_pipeline.review_comparison import compare_reviews

PIPELINE = Path(__file__).parents[1]
CONTENT = PIPELINE.parent / "game/content"
CATALOG = PIPELINE / "reviews/pl/familiarity.csv"


def rows() -> list[dict]:
    return list(csv.DictReader(io.StringIO(CATALOG.read_text(encoding="utf-8"))))


def write_rows(path: Path, entries: list[dict]) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(
            stream, ["word", "band", "status", "reviewer", "rationale"], lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(sorted(entries, key=lambda row: row["word"]))


def test_unchanged_comparison_is_readonly_and_reproducible(tmp_path: Path) -> None:
    draft = tmp_path / "candidate.csv"
    draft.write_bytes(CATALOG.read_bytes())
    before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in (CATALOG, draft)}
    result = compare_reviews(PIPELINE, CONTENT, CATALOG, draft)
    assert result == compare_reviews(PIPELINE, CONTENT, CATALOG, draft)
    assert result["schema_version"] == 1 and result["changes"] == []
    assert result["coverage"] == {"missing": 0, "proposed": 103, "reviewed": 0}
    assert result["inputs"]["baseline_sha256"] == result["inputs"]["candidate_sha256"]
    assert result["inputs"]["candidate_sha256"] == digest(draft.read_bytes())
    assert (
        result["inputs"]["tiers_sha256"]
        == json.loads((PIPELINE / "content-inputs/pl.json").read_bytes())["tiers_sha256"]
    )
    assert result["inputs"]["packs"] == {
        "packs/c-0001-0065.json": digest((CONTENT / "pl/packs/c-0001-0065.json").read_bytes())
    }
    assert len(result["early_check"]["issues"]) == 24
    assert all(issue["reason"] == "proposed" for issue in result["early_check"]["issues"])
    assert json.loads(canonical_bytes(result)) == result
    assert before == {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in before}
    assert list(tmp_path.iterdir()) == [draft]


def test_explicit_fixture_decisions_show_sorted_changes_and_early_effect(tmp_path: Path) -> None:
    entries = rows()
    for row in entries:
        if row["word"] in ("KOT", "RAK"):
            row.update(
                band="1" if row["word"] == "KOT" else "3",
                status="reviewed",
                reviewer="fixture-curator",
                rationale="explicit test decision",
            )
    draft = tmp_path / "candidate.csv"
    write_rows(draft, entries)
    result = compare_reviews(PIPELINE, CONTENT, CATALOG, draft)
    assert [c["word"] for c in result["changes"]] == ["KOT", "RAK"]
    for change in result["changes"]:
        assert (
            set(change["before"])
            == set(change["after"])
            == {"word", "band", "status", "reviewer", "rationale"}
        )
        assert change["before"]["status"] == "proposed"
        assert change["after"]["status"] == "reviewed"
    assert result["coverage"] == {"missing": 0, "proposed": 101, "reviewed": 2}
    assert result["inputs"]["baseline_sha256"] != result["inputs"]["candidate_sha256"]
    issues = result["early_check"]["issues"]
    assert len(issues) == 23 and issues[0]["word"] == "RAK"
    assert issues[0]["reason"] == "above_max_band"
    assert not any(issue["word"] == "KOT" for issue in issues)


@pytest.mark.parametrize("change", ["missing", "extra", "unknown", "malformed"])
def test_invalid_candidate_is_rejected(tmp_path: Path, change: str) -> None:
    entries = rows()
    draft = tmp_path / "candidate.csv"
    if change == "missing":
        entries.pop()
    elif change in ("extra", "unknown"):
        entries.append(
            {
                "word": "KUR" if change == "extra" else "XYZ",
                "band": "2",
                "status": "proposed",
                "reviewer": "fixture",
                "rationale": "test",
            }
        )
    write_rows(draft, entries)
    if change == "malformed":
        draft.write_text("bad CSV", encoding="utf-8")
    with pytest.raises(ValueError):
        compare_reviews(PIPELINE, CONTENT, CATALOG, draft)


def test_banned_candidate_tier_is_rejected(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    import wordgame_pipeline.review_comparison as module

    original = module.WordIndex

    def with_banned_fixture(records: object, config: object) -> SimpleNamespace:
        return SimpleNamespace(tiers={**original(records, config).tiers, "KOT": "banned"})

    monkeypatch.setattr(module, "WordIndex", with_banned_fixture)
    draft = tmp_path / "candidate.csv"
    draft.write_bytes(CATALOG.read_bytes())
    with pytest.raises(ValueError, match="ineligible native word 'KOT'"):
        compare_reviews(PIPELINE, CONTENT, CATALOG, draft)


def test_missing_baseline_annotation_remains_explicit_in_diff(tmp_path: Path) -> None:
    baseline = tmp_path / "baseline.csv"
    write_rows(baseline, [r for r in rows() if r["word"] != "KOT"])
    result = compare_reviews(PIPELINE, CONTENT, baseline, CATALOG)
    assert result["changes"] == [
        {
            "word": "KOT",
            "before": {
                "word": "KOT",
                "band": None,
                "status": "missing",
                "reviewer": "",
                "rationale": "",
            },
            "after": {
                "word": "KOT",
                "band": 1,
                "status": "proposed",
                "reviewer": "codex",
                "rationale": "Basic animal vocabulary.",
            },
        }
    ]


def test_tampered_content_rejected_and_workspace_not_written(tmp_path: Path) -> None:
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
    shutil.copy(PIPELINE.parent / "NOTICE", tmp_path)
    content = tmp_path / "game/content"
    shutil.copytree(CONTENT, content)
    catalog = root / "reviews/pl/familiarity.csv"
    before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in tmp_path.rglob("*") if p.is_file()}
    compare_reviews(root, content, catalog, catalog)
    assert before == {
        p: (p.read_bytes(), p.stat().st_mtime_ns) for p in tmp_path.rglob("*") if p.is_file()
    }
    pack = content / "pl/packs/c-0001-0065.json"
    value = json.loads(pack.read_bytes())
    value["levels"][-1]["seed"] += 1
    pack.write_bytes(canonical_bytes(value))
    with pytest.raises(ValueError):
        compare_reviews(root, content, catalog, catalog)
