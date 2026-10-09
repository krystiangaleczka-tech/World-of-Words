"""Geometry properties and stage contracts do not require a native dictionary."""

import copy
import json
import shutil
from pathlib import Path

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st
from wordgame_pipeline.annotate.sources import load_pin as annotation_pin
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import load_config
from wordgame_pipeline.grid import handlers_for, make_level
from wordgame_pipeline.grid.builder import SearchOptions, build_grid, score
from wordgame_pipeline.grid.geometry import normalize, validate_geometry
from wordgame_pipeline.ingest.source import load_pin as source_pin
from wordgame_pipeline.stages import run_build

PIPELINE = Path(__file__).parents[2]


def workspace(root):
    for folder in ("config", "sources"):
        (root / folder).mkdir(parents=True)
    shutil.copyfile(PIPELINE / "config/pl.yaml", root / "config/pl.yaml")
    for name in ("annotation-pl.json", "sjp-pl.json"):
        shutil.copyfile(PIPELINE / "sources" / name, root / "sources" / name)
    return load_config(root, "pl")


def test_geometry_rejects_conflicts_and_accidental_runs():
    good = normalize((("KOT", 0, 0, "h"), ("TOK", 2, 0, "v")))
    assert validate_geometry(good, ("KOT", "TOK")) == {"w": 3, "h": 3}
    bad = [
        (("KOT", 0, 0, "h"), ("DOM", 1, 0, "v")),
        (("KOT", 0, 0, "v"), ("KOTY", 0, 0, "v")),
        (("KOT", 0, 0, "v"), ("TOK", 1, 0, "v")),
        (("KOT", 0, 0, "v"), ("TOK", 0, 3, "v")),
        (("KOT", 0, 0, "v"), ("DOM", 5, 5, "v")),
        (("KOT", 0, 0, "v"), ("KOT", 0, 0, "v")),
        (("KOT", 0, 9, "v"),),
        (("KOT", True, 0, "v"),),
        (("KOT", 0, 0, "diagonal"),),
        (("KOT", 0, 0, "h"),),
    ]
    for layout in bad:
        with pytest.raises(ValueError):
            validate_geometry(layout, tuple(p[0] for p in layout))
    with pytest.raises(ValueError):
        validate_geometry(good, ("KOT",))


def test_builder_backtracking_and_best_layout():
    words = ("KARTA", "KARA", "TARA", "RAK", "KAT", "TAK", "ART")
    original = copy.deepcopy(words)
    first = build_grid(words, "KARTA", 123, SearchOptions(restarts=1))
    best = build_grid(words, "KARTA", 123)
    assert words == original
    assert score(best) >= score(first)
    assert len(best) >= 3
    assert best == build_grid(tuple(reversed(words)), "KARTA", 123)
    assert best == build_grid(words, "KARTA", 123)
    assert "KARTA" in [p[0] for p in best]
    backtracking_pool = ("AKT", "KARTA", "KAT", "RAK", "TAK", "TAR", "TARA")
    greedy = build_grid(backtracking_pool, "AKT", 0, SearchOptions(restarts=1, nodes=1))
    searched = build_grid(backtracking_pool, "AKT", 0, SearchOptions(restarts=1))
    assert score(searched) > score(greedy)
    assert build_grid(("KOT", "AAA"), "KOT", 3) == (("KOT", 0, 0, "v"),)
    with pytest.raises(ValueError, match="Handmade"):
        build_grid(("KOT", "AAA"), "KOT", 3, require_all=True)
    for words, seed in ((("KOT", "KOT"), 1), (("kot",), 1), (("A1A",), 1), (("KOT",), True)):
        with pytest.raises(ValueError):
            build_grid(words, words[0], seed)
    with pytest.raises(ValueError):
        build_grid(("KOT",), "KOT", 1, SearchOptions(nodes=0))


@settings(max_examples=40, deadline=None, derandomize=True)
@given(
    st.lists(
        st.text(alphabet="KOTADÓŁ", min_size=3, max_size=6), min_size=1, max_size=7, unique=True
    ),
    st.integers(min_value=0, max_value=100000),
)
def test_grid_invariants_property(words, seed):
    pool = tuple(sorted(words))
    layout = build_grid(pool, pool[0], seed)
    dimensions = validate_geometry(layout, tuple(p[0] for p in layout))
    assert 1 <= dimensions["w"] <= dimensions["h"] <= 10
    assert pool[0] in [p[0] for p in layout]
    assert set(p[0] for p in layout) <= set(pool)
    assert layout == build_grid(pool, pool[0], seed)


def test_stage_atomicity_and_bonus(tmp_path, capsys):
    config = workspace(tmp_path)
    entry = {
        "id": "pl-auto-KOT",
        "letters": list("KOT"),
        "seeds": ["KOT"],
        "level_ok": ["KOT", "TOK"],
        "bonus_ok": [],
    }
    leftover = {
        "id": "pl-auto-AKKOTT",
        "letters": list("AKKOTT"),
        "seeds": ["KOT"],
        "level_ok": ["AAA", "KOT"],
        "bonus_ok": ["KAT"],
    }
    # Use a disconnected but formable word to force it into the bonus list.
    leftover["letters"] = list("AAAKOT")
    result = make_level(leftover, config, False)
    assert result["words"] == ["KOT"]
    assert result["bonus"] == ["AAA", "KAT"]
    multi = {
        "slot": 2,
        "letters": list("KOT"),
        "words": ["KOT", "TOK"],
        "bonus": [],
        "expect_bonus": [],
    }
    generated = make_level(multi, config, True)
    assert generated["words"] == ["KOT", "TOK"]
    validate_geometry(
        tuple((p["w"], p["x"], p["y"], p["dir"]) for p in generated["placements"]), ("KOT", "TOK")
    )
    single = make_level(entry, config, False)
    assert sorted(single["words"] + single["bonus"]) == ["KOT", "TOK"]
    handmade = {
        "slot": 1,
        "letters": list("KOT"),
        "words": ["KOT"],
        "bonus": ["TOK"],
        "expect_bonus": ["TOK"],
    }
    assert make_level(handmade, config, True)["bonus"] == ["TOK"]
    handmade["grid"] = [{"w": "KOT", "x": 2, "y": 3, "dir": "h"}]
    explicit = make_level(handmade, config, True)
    assert explicit["grid"] == {"w": 1, "h": 3}
    assert explicit["placements"] == [{"w": "KOT", "x": 0, "y": 0, "dir": "v"}]
    previous = {
        "source": source_pin(tmp_path).to_dict(),
        "annotation_sources": annotation_pin(tmp_path),
        "tier_rules": config.to_dict()["tier_rules"],
        "tier_rules_sha256": "a" * 64,
        "overrides_sha256": "b" * 64,
        "handmade_sha256": "c" * 64,
        "automatic": [entry],
        "handmade": [handmade],
    }
    fake = {
        name: lambda _cfg, _prior: previous
        for name in ("ingest", "normalize", "annotate", "tiers", "candidates")
    }
    run_build(tmp_path, config, fake, last="candidates")
    handlers = handlers_for(tmp_path)
    path = run_build(tmp_path, config, handlers, "grid", "grid")[0]
    original = path.read_bytes()
    run_build(tmp_path, config, handlers, "grid", "grid")
    assert path.read_bytes() == original
    payload = json.loads(original)["payload"]
    assert payload["search_options"]["restarts"] == 4
    assert payload["handmade"][0]["expect_bonus"] == ["TOK"]
    assert (
        main(["build", "--root", str(tmp_path), "--lang", "pl", "--from", "grid", "--to", "grid"])
        == 0
    )
    handmade["grid"][0]["dir"] = "diagonal"
    run_build(tmp_path, config, fake, last="candidates")
    with pytest.raises(ValueError):
        run_build(tmp_path, config, handlers, "grid", "grid")
    assert path.read_bytes() == original
    handmade["grid"][0]["dir"] = "h"
    previous["annotation_sources"]["morphology"]["version"] = "999"
    run_build(tmp_path, config, fake, last="candidates")
    with pytest.raises(ValueError, match="provenance"):
        run_build(tmp_path, config, handlers, "grid", "grid")
    assert path.read_bytes() == original
    assert main(["build", "--root", str(tmp_path), "--lang", "pl", "--to", "validate"]) == 1
    assert "validate is not implemented" in capsys.readouterr().err
