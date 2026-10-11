import copy
import csv
import io
from pathlib import Path

import pytest
from wordgame_pipeline.candidates.core import WordIndex
from wordgame_pipeline.config import load_config
from wordgame_pipeline.familiarity import load_catalog
from wordgame_pipeline.familiarity_report import build_report
from wordgame_pipeline.p1 import read_json
from wordgame_pipeline.review_worksheet import export_worksheet


def test_actual_roundtrip_retains_all_103_proposals(tmp_path: Path) -> None:
    root = Path(__file__).parents[1]
    content = root.parent / "game/content"
    catalog = root / "reviews/pl/familiarity.csv"
    report = build_report(root, content, catalog)
    before = copy.deepcopy(report)
    output = export_worksheet(report)
    draft = tmp_path / "draft.csv"
    draft.write_text(output, encoding="utf-8")
    index = WordIndex(
        read_json(root / "content-inputs/pl.json")["records"], load_config(root, "pl")
    )
    assert load_catalog(draft, index.tiers) == load_catalog(catalog, index.tiers)
    assert len(load_catalog(draft, index.tiers)) == 103
    assert all(r.status == "proposed" for r in load_catalog(draft, index.tiers).values())
    assert "\r" not in output and output.endswith("\n")
    assert report == before and export_worksheet(report) == output


def sample() -> dict:
    reviewed = {
        "word": "ŻÓŁW",
        "band": 2,
        "status": "reviewed",
        "reviewer": "fixture curator",
        "rationale": 'Animal, reviewed\nwith a "quote"',
    }
    return {
        "levels": [
            {
                "required": [
                    reviewed,
                    {
                        "word": "KOT",
                        "band": None,
                        "status": "proposed",
                        "reviewer": "codex",
                        "rationale": "not decided",
                    },
                ]
            },
            {
                "required": [
                    copy.deepcopy(reviewed),
                    {
                        "word": "DOM",
                        "band": None,
                        "status": "missing",
                        "reviewer": "",
                        "rationale": "",
                    },
                ]
            },
        ]
    }


def test_draft_is_sorted_unique_and_preserves_quoted_unicode_fields(tmp_path: Path) -> None:
    report = sample()
    before = copy.deepcopy(report)
    output = export_worksheet(report)
    rows = list(csv.DictReader(io.StringIO(output)))
    assert [r["word"] for r in rows] == ["DOM", "KOT", "ŻÓŁW"]
    assert rows[0] == {
        "word": "DOM",
        "band": "",
        "status": "proposed",
        "reviewer": "unassigned",
        "rationale": "Awaiting curator review",
    }
    assert rows[1]["band"] == "" and rows[1]["status"] == "proposed"
    assert rows[2]["status"] == "reviewed" and rows[2]["reviewer"] == "fixture curator"
    assert rows[2]["rationale"] == 'Animal, reviewed\nwith a "quote"'
    draft = tmp_path / "draft.csv"
    draft.write_text(output, encoding="utf-8")
    loaded = load_catalog(draft, {w: "level_ok" for w in ("DOM", "KOT", "ŻÓŁW")})
    assert loaded["DOM"].band is None and loaded["DOM"].status == "proposed"
    assert loaded["ŻÓŁW"].rationale == rows[2]["rationale"]
    assert report == before


@pytest.mark.parametrize(
    "field,value",
    [("band", 3), ("status", "proposed"), ("reviewer", "other"), ("rationale", "different")],
)
def test_inconsistent_repeated_judgments_are_rejected(field: str, value: object) -> None:
    report = sample()
    report["levels"][1]["required"][0][field] = value
    with pytest.raises(ValueError, match="inconsistent repeated review: ŻÓŁW"):
        export_worksheet(report)
