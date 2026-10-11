"""Faithful standalone curator QA pages, independent of the game's visual design."""

from collections.abc import Mapping
from html import escape

STYLE = """
:root{color-scheme:light;font-family:system-ui,sans-serif;background:#f5f4ef;color:#202b31}
body{max-width:1100px;margin:auto;padding:24px}a{color:#246454}nav{display:flex;flex-wrap:wrap;gap:8px}
nav a{padding:6px 10px;background:white;border-radius:8px}article{margin:24px 0;padding:20px;
background:white;border-radius:16px;break-inside:avoid}.layout{display:flex;gap:24px;flex-wrap:wrap}
.board{display:grid;gap:4px;width:max-content}.cell{width:32px;height:32px;display:grid;
place-items:center;border-radius:5px;background:#e7f0e9;font-weight:bold}.blank{background:transparent}
.annotations{flex:1;min-width:220px;overflow:auto}table{border-collapse:collapse;width:100%}
th,td{text-align:left;padding:8px;border-bottom:1px solid #ddd;vertical-align:top}
small{color:#53626a}code{overflow-wrap:anywhere}.notice{padding:16px;border-left:4px solid #b77820;
background:#fff0d8}details{margin:16px 0}summary{cursor:pointer}.wheel{letter-spacing:2px}
@media(max-width:600px){body{padding:12px}article{padding:12px}.layout{gap:12px}}
@media print{nav{display:none}body{padding:0}article{border:1px solid #ddd}details{display:block}}
"""


def _grid(level: dict) -> str:
    width, height = level["grid"]["w"], level["grid"]["h"]
    if any(type(v) is not int or not 1 <= v <= 10 for v in (width, height)):
        raise ValueError("invalid review grid dimensions")
    cells: dict[tuple[int, int], str] = {}
    for placement in level["words"]:
        direction, x, y = placement["dir"], placement["x"], placement["y"]
        if direction not in ("h", "v") or type(x) is not int or type(y) is not int:
            raise ValueError("invalid review placement")
        for offset, letter in enumerate(placement["w"]):
            position = (
                x + (offset if direction == "h" else 0),
                y + (offset if direction == "v" else 0),
            )
            if not 0 <= position[0] < width or not 0 <= position[1] < height:
                raise ValueError("review placement outside grid")
            if position in cells and cells[position] != letter:
                raise ValueError("conflicting review grid letters")
            cells[position] = letter
    tiles = []
    for row in range(height):
        for column in range(width):
            letter = cells.get((column, row), "")
            blank = " blank" if not letter else ""
            tiles.append(
                f'<span class="cell{blank}" data-x="{column}" data-y="{row}">'
                f"{escape(letter)}</span>"
            )
    return (
        f'<div class="board" aria-label="Plansza {width} na {height}" '
        f'style="grid-template-columns:repeat({width},32px)">' + "".join(tiles) + "</div>"
    )


def render_review(report: dict, levels: Mapping[int, dict]) -> str:
    """Render validated report annotations with matching committed level geometry."""
    if (
        len(levels) != len(report["levels"])
        or any(type(entry["slot"]) is not int or entry["slot"] < 1 for entry in report["levels"])
        or set(levels) != {entry["slot"] for entry in report["levels"]}
    ):
        raise ValueError("review slots do not match report")
    sections: list[str] = []
    statuses = {"missing": "Brak oceny", "proposed": "Propozycja", "reviewed": "Ocenione"}
    for entry in report["levels"]:
        slot = entry["slot"]
        level = levels[slot]
        if (
            level["slot"] != slot
            or level["id"] != entry["id"]
            or [p["w"] for p in level["words"]] != [p["word"] for p in entry["required"]]
        ):
            raise ValueError(f"review level {slot} identity/answers do not match report")
        rows: list[str] = []
        for annotation in entry["required"]:
            values = (
                annotation["word"],
                annotation["band"] if annotation["band"] is not None else "Nieznana",
                statuses[annotation["status"]],
                annotation["reviewer"],
                annotation["rationale"],
            )
            rows.append("<tr>" + "".join(f"<td>{escape(str(v))}</td>" for v in values) + "</tr>")
        wheel = escape(" · ".join(level["letters"]))
        sections.append(
            f'<article id="level-{slot}" data-slot="{slot}"><h2>Poziom {slot}</h2>'
            f'<small>{escape(entry["id"])}</small><div class="layout"><section>'
            f'<p class="wheel">Kafelki: {wheel}</p>{_grid(level)}</section>'
            '<div class="annotations"><table><thead><tr><th>Słowo</th><th>Ocena 1–5</th>'
            "<th>Status</th><th>Kurator</th><th>Uzasadnienie</th></tr></thead><tbody>"
            + "".join(rows)
            + "</tbody></table></div></div></article>"
        )
    links = " ".join(f'<a href="#level-{e["slot"]}">{e["slot"]}</a>' for e in report["levels"])
    coverage = {key: escape(str(value)) for key, value in report["coverage"].items()}
    hashes = {
        "catalog_sha256": report["inputs"]["catalog_sha256"],
        "tiers_sha256": report["inputs"]["tiers_sha256"],
        **report["inputs"]["packs"],
    }
    receipt = "".join(f"<p>{escape(k)}: <code>{escape(v)}</code></p>" for k, v in hashes.items())
    return (
        '<!doctype html><html lang="pl"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        f"<title>World of Words — przegląd słów</title><style>{STYLE}</style></head><body>"
        "<header><h1>World of Words — przegląd słów</h1>"
        f"<p>Wersja treści: {escape(str(report['content_version']))} · "
        f"Poziomy: {len(sections)}</p><p>Brak ocen: {coverage['missing']} · "
        f"Propozycje: {coverage['proposed']} · Ocenione: {coverage['reviewed']}</p>"
        '<p class="notice">Propozycja nie oznacza zatwierdzenia przez kuratora. '
        "Znajomość słowa jest oddzielna od wielkości planszy. "
        "To podgląd do przeglądu treści; słowa bonusowe nie podlegają tej ocenie.</p>"
        f"<details><summary>Sumy kontrolne źródeł</summary>{receipt}</details></header>"
        f'<nav aria-label="Poziomy">{links}</nav><main>'
        + "".join(sections)
        + "</main></body></html>\n"
    )
