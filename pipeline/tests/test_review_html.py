import copy
from html.parser import HTMLParser
from pathlib import Path

import pytest
from wordgame_pipeline.familiarity_report import build_report
from wordgame_pipeline.p1 import read_json
from wordgame_pipeline.review_html import render_review


class Page(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.tags: list[tuple[str, dict]] = []
        self.text: list[str] = []

    def handle_starttag(self, tag: str, attrs: list) -> None:
        self.tags.append((tag, dict(attrs)))

    def handle_data(self, data: str) -> None:
        self.text.append(data)


def fixture() -> tuple[dict, dict]:
    report = {
        "content_version": 2,
        "coverage": {"missing": 1, "proposed": 1, "reviewed": 0},
        "inputs": {"catalog_sha256": "a", "tiers_sha256": "b", "packs": {"pack": "c"}},
        "levels": [
            {
                "slot": 1,
                "id": "one",
                "required": [
                    {
                        "word": "KOT",
                        "band": 1,
                        "status": "proposed",
                        "reviewer": "codex",
                        "rationale": "cat",
                    },
                    {
                        "word": "OSA",
                        "band": None,
                        "status": "missing",
                        "reviewer": "",
                        "rationale": "",
                    },
                ],
            }
        ],
    }
    levels = {
        1: {
            "slot": 1,
            "id": "one",
            "letters": ["K", "O", "T", "S", "A", "A"],
            "grid": {"w": 3, "h": 3},
            "words": [
                {"w": "KOT", "x": 0, "y": 0, "dir": "h"},
                {"w": "OSA", "x": 1, "y": 0, "dir": "v"},
            ],
        }
    }
    return report, levels


def test_faithful_grid_wheel_states_and_nonmutation() -> None:
    report, levels = fixture()
    before = copy.deepcopy((report, levels))
    html = render_review(report, levels)
    page = Page()
    page.feed(html)
    assert [attrs for tag, attrs in page.tags if tag == "article"] == [
        {"id": "level-1", "data-slot": "1"}
    ]
    assert html.count('class="cell') == 9
    assert html.count('class="cell blank"') == 4
    assert 'data-x="1" data-y="0">O</span>' in html
    assert 'data-x="1" data-y="2">A</span>' in html
    assert "K · O · T · S · A · A" in html
    assert all(text in html for text in ("Propozycja", "Brak oceny", "Nieznana"))
    assert 'href="#level-1"' in html
    assert "<style>" in html and "@media(max-width:600px)" in html
    assert not any(tag in ("script", "link", "iframe", "img") for tag, _ in page.tags)
    assert (report, levels) == before
    assert render_review(report, levels) == html


def test_actual_campaign_all_levels_words_and_receipts() -> None:
    root = Path(__file__).parents[1]
    content = root.parent / "game/content"
    report = build_report(root, content, root / "reviews/pl/familiarity.csv")
    manifest = read_json(content / "pl/manifest.json")
    levels = {
        level["slot"]: level
        for entry in manifest["packs"]
        for level in read_json(content / "pl" / entry["file"])["levels"]
    }
    html = render_review(report, levels)
    page = Page()
    page.feed(html)
    assert len([tag for tag, _ in page.tags if tag == "article"]) == 65
    assert html.count("<tbody>") == 65 and html.count("<tr>") == 168
    assert "Propozycje: 103" in html and "Ocenione: 0" in html
    for level in report["levels"]:
        for word in level["required"]:
            assert f"<td>{word['word']}</td>" in html
    assert report["inputs"]["catalog_sha256"] in html
    assert all(value in html for value in report["inputs"]["packs"].values())


def test_hostile_annotation_and_identity_are_escaped() -> None:
    report, levels = fixture()
    hostile = '</td><script>alert("x")</script>&'
    report["levels"][0]["id"] = levels[1]["id"] = hostile
    report["levels"][0]["required"][0]["reviewer"] = hostile
    report["levels"][0]["required"][0]["rationale"] = hostile
    report["coverage"] = {key: hostile for key in report["coverage"]}
    html = render_review(report, levels)
    assert hostile not in html and "&lt;script&gt;" in html and "&amp;" in html
    page = Page()
    page.feed(html)
    assert not any(tag == "script" for tag, _ in page.tags)
    assert hostile in "".join(page.text)


@pytest.mark.parametrize(
    "change", ["slots", "slot", "id", "words", "direction", "bounds", "conflict", "dimensions"]
)
def test_mismatch_and_bad_geometry_are_rejected(change: str) -> None:
    report, levels = fixture()
    if change == "slots":
        levels[2] = levels[1]
    elif change == "slot":
        levels[1]["slot"] = 2
    elif change == "id":
        levels[1]["id"] = "other"
    elif change == "words":
        levels[1]["words"].reverse()
    elif change == "direction":
        levels[1]["words"][0]["dir"] = "diagonal"
    elif change == "bounds":
        levels[1]["words"][0]["x"] = -1
    elif change == "conflict":
        levels[1]["words"][1]["x"] = 0
    else:
        levels[1]["grid"]["w"] = True
    with pytest.raises(ValueError):
        render_review(report, levels)
