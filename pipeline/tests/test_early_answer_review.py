import copy
import json
from pathlib import Path

import pytest
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.familiarity_report import build_report, early_issues, main

PIPELINE = Path(__file__).parents[1]
CONTENT = PIPELINE.parent / "game/content"
CATALOG = PIPELINE / "reviews/pl/familiarity.csv"


def review(word: str, status: str = "reviewed", band: int | None = 1) -> dict:
    return {
        "word": word,
        "status": status,
        "band": band,
        "reviewer": "fixture",
        "rationale": "test",
    }


def sample_report() -> dict:
    return {
        "levels": [
            {
                "slot": 1,
                "id": "first",
                "required": [
                    review("EASY"),
                    review("PROPOSAL", "proposed"),
                    review("MISSING", "missing", None),
                    review("UNKNOWN", band=None),
                    review("HARD", band=3),
                    review("EASY_TWO", band=2),
                ],
                "bonus": [{"word": "OBSCURE", "band": 5}],
            },
            {"slot": 2, "id": "later", "required": [review("LATER_HARD", band=5)]},
        ]
    }


def test_reason_priority_order_and_input_unchanged() -> None:
    report = sample_report()
    before = copy.deepcopy(report)
    assert early_issues(report, slots=1) == [
        {"slot": 1, "id": "first", "word": "PROPOSAL", "reason": "proposed"},
        {"slot": 1, "id": "first", "word": "MISSING", "reason": "missing"},
        {"slot": 1, "id": "first", "word": "UNKNOWN", "reason": "unknown_band"},
        {"slot": 1, "id": "first", "word": "HARD", "reason": "above_max_band"},
    ]
    assert report == before
    report["levels"][0].pop("bonus")
    assert early_issues(report, slots=1) == early_issues(before, slots=1)
    assert early_issues(report, slots=2)[-1] == {
        "slot": 2,
        "id": "later",
        "word": "LATER_HARD",
        "reason": "above_max_band",
    }


@pytest.mark.parametrize("band", [1, 2, 3, 4, 5])
def test_reviewed_threshold_controls_pass(band: int) -> None:
    report = {"levels": [{"slot": 1, "id": "one", "required": [review("WORD", band=band)]}]}
    assert early_issues(report, 1, band) == []
    if band > 1:
        assert early_issues(report, 1, band - 1)[0]["reason"] == "above_max_band"


@pytest.mark.parametrize("band", [None, 0, 6, True, "1"])
def test_reviewed_unknown_or_invalid_band_never_passes(band: object) -> None:
    record = review("WORD")
    record["band"] = band
    report = {"levels": [{"slot": 1, "id": "one", "required": [record]}]}
    assert early_issues(report, 1)[0]["reason"] == "unknown_band"


@pytest.mark.parametrize(
    "status,band,reason",
    [
        ("proposed", 1, "proposed"),
        ("proposed", None, "proposed"),
        ("missing", None, "missing"),
    ],
)
def test_unreviewed_reason_precedes_band(status: str, band: int | None, reason: str) -> None:
    report = {"levels": [{"slot": 1, "id": "one", "required": [review("WORD", status, band)]}]}
    assert early_issues(report, 1)[0]["reason"] == reason


@pytest.mark.parametrize("slots", [0, 3, True, False, 1.0, "1", None])
def test_invalid_slots(slots: object) -> None:
    with pytest.raises(ValueError, match="early slots"):
        early_issues(sample_report(), slots)  # type: ignore[arg-type]


@pytest.mark.parametrize("band", [0, 6, True, False, 1.0, "1", None])
def test_invalid_threshold(band: object) -> None:
    with pytest.raises(ValueError, match="maximum band"):
        early_issues(sample_report(), 1, band)  # type: ignore[arg-type]


def test_unknown_status_is_rejected() -> None:
    report = {"levels": [{"slot": 1, "id": "one", "required": [review("WORD", "approved")]}]}
    with pytest.raises(ValueError, match="unknown review status"):
        early_issues(report, 1)


def arguments() -> list[str]:
    return ["--root", str(PIPELINE), "--content-root", str(CONTENT)]


def test_default_cli_retains_report_behavior(capsys: pytest.CaptureFixture) -> None:
    assert main(arguments()) == 0
    output = capsys.readouterr()
    assert output.err == ""
    report = build_report(PIPELINE, CONTENT, CATALOG)
    assert "early_check" not in report
    assert output.out.encode() == canonical_bytes(report)


def test_actual_catalog_is_expected_not_ready(capsys: pytest.CaptureFixture) -> None:
    before = CATALOG.read_bytes()
    assert main(arguments() + ["--check-early"]) == 1
    output = capsys.readouterr()
    assert output.err == ""
    report = json.loads(output.out)
    assert output.out.encode() == canonical_bytes(report)
    assert report["coverage"] == {"missing": 0, "proposed": 103, "reviewed": 0}
    assert report["early_check"]["slots"] == 15
    assert report["early_check"]["max_band"] == 2
    issues = report["early_check"]["issues"]
    assert len(issues) == 24 and all(issue["reason"] == "proposed" for issue in issues)
    assert issues == [
        {"slot": level["slot"], "id": level["id"], "word": record["word"], "reason": "proposed"}
        for level in report["levels"][:15]
        for record in level["required"]
    ]
    assert CATALOG.read_bytes() == before


def test_cli_reviewed_fixture_can_pass_or_fail_threshold(
    tmp_path: Path, capsys: pytest.CaptureFixture
) -> None:
    catalog = tmp_path / "fixture.csv"
    catalog.write_text(
        "word,band,status,reviewer,rationale\n"
        "KOT,2,reviewed,fixture-curator,explicit fixture judgment\n"
        "KUR,5,reviewed,fixture-curator,hard optional bonus\n",
        encoding="utf-8",
    )
    args = arguments() + ["--catalog", str(catalog), "--check-early", "--early-slots", "1"]
    assert main(args + ["--max-band", "2"]) == 0
    output = capsys.readouterr()
    assert not output.err
    assert json.loads(output.out)["early_check"] == {"slots": 1, "max_band": 2, "issues": []}
    assert main(args + ["--max-band", "1"]) == 1
    output = capsys.readouterr()
    assert json.loads(output.out)["early_check"]["issues"][0]["reason"] == "above_max_band"
    assert main(args + ["--early-slots", "2"]) == 1
    output = capsys.readouterr()
    assert json.loads(output.out)["early_check"]["issues"][0]["reason"] == "missing"


@pytest.mark.parametrize(
    "options",
    [
        ["--early-slots", "1"],
        ["--max-band", "2"],
        ["--check-early", "--early-slots", "0"],
        ["--check-early", "--early-slots", "66"],
        ["--check-early", "--max-band", "0"],
        ["--check-early", "--max-band", "6"],
    ],
)
def test_cli_invalid_options(options: list[str], capsys: pytest.CaptureFixture) -> None:
    assert main(arguments() + options) == 1
    output = capsys.readouterr()
    assert output.out == "" and "Familiarity report:" in output.err
