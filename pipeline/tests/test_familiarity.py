import csv
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.familiarity import WordReview, load_catalog

HEADER = "word,band,status,reviewer,rationale\n"
TIERS = {word: "level_ok" for word in ("ALA", "DOM", "KOT", "LAS", "MAK", "RAK", "ŻÓŁW")}
TIERS.update({"BON": "bonus_ok", "BAN": "banned"})


def test_valid_catalog_is_typed_immutable_and_read_only(tmp_path: Path) -> None:
    path = tmp_path / "reviews.csv"
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["word", "band", "status", "reviewer", "rationale"])
        for band, word in enumerate(("ALA", "DOM", "KOT", "LAS", "MAK"), 1):
            writer.writerow([word, band, "reviewed", "curator", "human judgment"])
        writer.writerow(["RAK", "", "proposed", "codex", "needs review"])
        writer.writerow(["ŻÓŁW", 2, "proposed", "codex", "familiar animal, Polish diacritics"])
    before = path.read_bytes()
    records = load_catalog(path, TIERS)
    assert [records[word].band for word in ("ALA", "DOM", "KOT", "LAS", "MAK")] == list(range(1, 6))
    assert records["RAK"].band is None
    assert records["ŻÓŁW"] == WordReview(
        "ŻÓŁW", 2, "proposed", "codex", "familiar animal, Polish diacritics"
    )
    with pytest.raises(FrozenInstanceError):
        records["KOT"].band = 1  # type: ignore[misc]
    assert path.read_bytes() == before
    assert list(tmp_path.iterdir()) == [path]


@pytest.mark.parametrize(
    "body",
    [
        "KOT,1,proposed,codex,note\nKOT,2,proposed,codex,note\n",
        "LAS,1,proposed,codex,note\nKOT,2,proposed,codex,note\n",
        "Z\u0307ÓŁW,1,proposed,codex,note\n",
        "kot,1,proposed,codex,note\n",
        " KOT,1,proposed,codex,note\n",
        "KOT,1,proposed,codex\n",
        "KOT,1,proposed,codex,note,extra\n",
        "KOT,01,proposed,codex,note\n",
        "KOT,6,proposed,codex,note\n",
        "KOT, 1,proposed,codex,note\n",
        "KOT,1,approved,codex,note\n",
        "KOT,1,proposed,,note\n",
        "KOT,1,proposed,codex,\n",
        "KOT,1,proposed, codex,note\n",
        "KOT,1,proposed,codex,note \n",
        "KOT,,reviewed,curator,note\n",
        "XYZ,1,proposed,codex,note\n",
        "BAN,1,proposed,codex,note\n",
        'KOT,1,proposed,codex,"unterminated\n',
        "\n",
        "",
    ],
)
def test_invalid_rows_have_context(tmp_path: Path, body: str) -> None:
    path = tmp_path / "reviews.csv"
    path.write_text(HEADER + body, encoding="utf-8")
    with pytest.raises(ValueError, match="catalog row"):
        load_catalog(path, TIERS)


@pytest.mark.parametrize("header", ["", "word,band,status,reviewer\n", HEADER.strip() + ",extra\n"])
def test_invalid_header(tmp_path: Path, header: str) -> None:
    path = tmp_path / "reviews.csv"
    path.write_text(header, encoding="utf-8")
    with pytest.raises(ValueError, match="row 1"):
        load_catalog(path, TIERS)


def test_invalid_encoding_and_missing_file(tmp_path: Path) -> None:
    path = tmp_path / "reviews.csv"
    path.write_bytes(HEADER.encode() + b"\xff")
    with pytest.raises(ValueError, match="UTF-8"):
        load_catalog(path, TIERS)
    with pytest.raises(FileNotFoundError):
        load_catalog(tmp_path / "absent.csv", TIERS)


def test_bonus_eligible_word_is_accepted(tmp_path: Path) -> None:
    path = tmp_path / "reviews.csv"
    path.write_text(HEADER + "BON,2,proposed,codex,note\n", encoding="utf-8")
    assert load_catalog(path, TIERS)["BON"].status == "proposed"
