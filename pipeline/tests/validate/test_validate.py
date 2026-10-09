"""Hard validation gates tested with authored content and offline source pins."""

import copy
import hashlib
import json
import shutil
from dataclasses import asdict
from pathlib import Path

import pytest
from wordgame_pipeline.candidates.core import WordIndex
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import TierRules, canonical_bytes, load_config
from wordgame_pipeline.stages import run_build
from wordgame_pipeline.validate import Schemas, handlers_for, validate_grid, validate_level

PIPELINE = Path(__file__).parents[2]


def index():
    config = load_config(PIPELINE, "pl")
    records = [
        {"word": "AAA", "tier": "level_ok"},
        {"word": "DOM", "tier": "banned"},
        {"word": "KOT", "tier": "level_ok"},
        {"word": "KOTY", "tier": "level_ok"},
        {"word": "TOK", "tier": "bonus_ok"},
    ]
    return WordIndex(records, config)


def level():
    return {
        "id": "pl-c-000001",
        "slot": 1,
        "letters": list("KOT"),
        "words": [{"w": "KOT", "x": 0, "y": 0, "dir": "v"}],
        "bonus": ["TOK"],
        "grid": {"w": 1, "h": 3},
        "difficulty": 0.0,
        "landmark": False,
        "source": "generated",
        "seed": -1,
        "pipeline": "0.1.0",
    }


def grid():
    source = level()
    return {
        "letters": source["letters"],
        "words": ["KOT"],
        "placements": source["words"],
        "bonus": source["bonus"],
        "grid": source["grid"],
        "seed": source["seed"],
        "candidate_id": "pl-auto-KOT",
    }


def test_schema_vocabulary_and_fail_closed(tmp_path):
    schemas = Schemas(PIPELINE / "schema")
    good = level()
    schemas.validate("level", good)
    good["slot"] = 1.0
    good["words"][0]["x"] = 0.0
    validate_level(good, index(), schemas)
    good["seed"] = 10**400
    validate_level(good, index(), schemas)
    pack = {"schema_version": 1.0, "lang": "pl", "kind": "campaign", "levels": [good]}
    schemas.validate("pack", pack)
    schemas.validate(
        "manifest",
        {
            "schema_version": 1,
            "lang": "pl",
            "content_version": 1,
            "pipeline": "0.1.0",
            "slots": 1,
            "packs": [
                {
                    "file": "packs/c-0001-0001.json",
                    "kind": "campaign",
                    "first": 1,
                    "last": 1,
                    "sha256": "a" * 64,
                }
            ],
        },
    )
    daily = copy.deepcopy(good)
    daily["id"] = "pl-d-000001"
    with pytest.raises(ValueError):
        schemas.validate("level", daily)
    del daily["slot"]
    schemas.validate("level", daily)
    with pytest.raises(ValueError):
        schemas.validate("pack", {**pack, "levels": [daily]})
    for field, value in (
        ("slot", True),
        ("seed", 1.5),
        ("difficulty", float("inf")),
        ("bonus", ["TOK", "TOK"]),
        ("extra", 1),
        ("id", "pl-c-000001\n"),
    ):
        with pytest.raises(ValueError):
            schemas.validate("level", {**level(), field: value})
    for field in good:
        invalid = level()
        del invalid[field]
        with pytest.raises(ValueError):
            schemas.validate("level", invalid)
    eight = {**level(), "letters": list("AAAKOTYZ")}
    with pytest.raises(ValueError):
        schemas.validate("level", eight)
    schemas.validate("level", {**eight, "landmark": True})
    shutil.copytree(PIPELINE / "schema", tmp_path / "schema")
    path = tmp_path / "schema/level.schema.json"
    original = path.read_text()
    for update in (
        {"not": {}},
        {"properties": {"letters": {"$ref": "https://invalid/schema"}}},
        {"properties": {"letters": {"$ref": "#/$defs/missing"}}},
        {"properties": {"letters": {"$ref": "#"}}},
    ):
        path.write_text(json.dumps(json.loads(original) | update))
        with pytest.raises(ValueError):
            Schemas(tmp_path / "schema")
    path.write_text(original)
    modified = json.loads(original)
    modified["properties"]["bonus"]["maxItems"] = 0
    path.write_text(json.dumps(modified))
    with pytest.raises(ValueError):
        Schemas(tmp_path / "schema").validate("level", level())


def test_semantic_validation_rejects_invalid_content():
    schemas = Schemas(PIPELINE / "schema")
    words = index()
    good = level()
    before = copy.deepcopy(good)
    validate_level(good, words, schemas)
    assert good == before
    bad = [
        {"letters": list("KOO")},
        {
            "letters": list("KOT"),
            "words": [{"w": "TOK", "x": 0, "y": 0, "dir": "v"}],
            "bonus": ["KOT"],
        },
        {"letters": list("DOM"), "words": [{"w": "DOM", "x": 0, "y": 0, "dir": "v"}], "bonus": []},
        {"letters": list("XYZ"), "words": [{"w": "XYZ", "x": 0, "y": 0, "dir": "v"}], "bonus": []},
        {"letters": list("KOT"), "words": [{"w": "KOTY", "x": 0, "y": 0, "dir": "v"}]},
        {"letters": ["K", "O", "T\u0301"]},
        {"bonus": []},
        {"bonus": ["DOM", "TOK"]},
        {"bonus": ["TOK", "TOK"]},
        {"words": good["words"] * 2},
        {"grid": {"w": 2, "h": 3}},
        {"slot": 2},
        {"words": [{"w": "KOT", "x": 9, "y": 9, "dir": "v"}]},
        {"words": [{"w": "KOT", "x": 0, "y": 0, "dir": "diagonal"}]},
    ]
    for changes in bad:
        with pytest.raises(ValueError):
            validate_level({**good, **changes}, words, schemas)
    # Both selected words are eligible/formable; only geometry makes these invalid.
    multi_index = WordIndex(
        [{"word": "KOT", "tier": "level_ok"}, {"word": "TOK", "tier": "level_ok"}], words.config
    )
    for raw in (
        (("KOT", 0, 0, "v"), ("TOK", 1, 0, "v")),
        (("KOT", 0, 0, "v"), ("TOK", 4, 4, "v")),
        (("KOT", 0, 0, "v"), ("TOK", 0, 2, "v")),
    ):
        invalid = {
            **good,
            "bonus": [],
            "words": [{"w": w, "x": x, "y": y, "dir": d} for w, x, y, d in raw],
        }
        with pytest.raises(ValueError):
            validate_level(invalid, multi_index, schemas)
    repeated = {
        **good,
        "letters": list("AAK"),
        "words": [{"w": "AAA", "x": 0, "y": 0, "dir": "v"}],
        "bonus": [],
    }
    with pytest.raises(ValueError, match="formable"):
        validate_level(repeated, words, schemas)


def test_preexport_preserves_identity_and_handmade_intent():
    schemas = Schemas(PIPELINE / "schema")
    entry = grid()
    original = copy.deepcopy(entry)
    validate_grid(entry, index(), schemas, False)
    assert entry == original
    eight = {
        **entry,
        "letters": list("AAAKOTYZ"),
        "bonus": ["AAA", "KOTY", "TOK"],
        "candidate_id": "pl-auto-AAAKOTYZ",
    }
    validate_grid(eight, index(), schemas, False)
    assert "landmark" not in eight
    handmade = {k: v for k, v in entry.items() if k != "candidate_id"} | {
        "slot": 3,
        "expect_bonus": ["TOK"],
    }
    validate_grid(handmade, index(), schemas, True)
    for change in (
        {"expect_bonus": ["AAA"]},
        {"expect_bonus": ["TOK", "TOK"]},
        {"slot": True},
        {"words": ["KOTY"]},
        {"bonus": []},
        {"extra": 0},
    ):
        with pytest.raises(ValueError):
            validate_grid({**handmade, **change}, index(), schemas, True)
    with pytest.raises(ValueError, match="identity"):
        validate_grid({**entry, "candidate_id": "pl-auto-OTHER"}, index(), schemas, False)


def test_stage_provenance_atomicity_and_determinism(tmp_path, capsys):
    from wordgame_pipeline.annotate.sources import load_pin as annotation_pin
    from wordgame_pipeline.ingest.source import load_pin as source_pin

    for folder in ("config", "sources", "schema", "overrides"):
        shutil.copytree(PIPELINE / folder, tmp_path / folder)
    config = load_config(tmp_path, "pl")
    rules = asdict(config.tier_rules or TierRules())
    provenance = {
        "source": source_pin(tmp_path).to_dict(),
        "annotation_sources": annotation_pin(tmp_path),
        "tier_rules": rules,
        "tier_rules_sha256": hashlib.sha256(canonical_bytes(rules)).hexdigest(),
        "overrides_sha256": hashlib.sha256(
            (tmp_path / "overrides/pl.csv").read_bytes()
        ).hexdigest(),
    }
    tiers = {**provenance, "records": [{"word": w, "tier": t} for w, t in index().tiers.items()]}
    previous = {
        **provenance,
        "handmade_sha256": hashlib.sha256(canonical_bytes([])).hexdigest(),
        "search_options": {},
        "automatic": [grid()],
        "handmade": [],
    }
    fake = {
        name: lambda _cfg, _prior: tiers
        for name in ("ingest", "normalize", "annotate", "tiers", "candidates")
    }
    fake["grid"] = lambda _cfg, _prior: previous
    run_build(tmp_path, config, fake, last="grid")
    path = run_build(tmp_path, config, handlers_for(tmp_path), "validate", "validate")[0]
    raw = path.read_bytes()
    run_build(tmp_path, config, handlers_for(tmp_path), "validate", "validate")
    assert path.read_bytes() == raw
    payload = json.loads(raw)["payload"]
    assert payload["validation"]["counts"] == {"automatic": 1, "handmade": 0}
    assert payload["automatic"] == previous["automatic"]
    assert set(payload["validation"]["schema_sha256"]) == {"level", "pack", "manifest"}
    assert (
        main(
            [
                "build",
                "--root",
                str(tmp_path),
                "--lang",
                "pl",
                "--from",
                "validate",
                "--to",
                "validate",
            ]
        )
        == 0
    )
    for key in ("source", "tier_rules_sha256", "overrides_sha256", "handmade_sha256"):
        original = previous[key]
        previous[key] = "bad"
        run_build(tmp_path, config, fake, "grid", "grid")
        with pytest.raises(ValueError):
            run_build(tmp_path, config, handlers_for(tmp_path), "validate", "validate")
        assert path.read_bytes() == raw
        previous[key] = original
    previous["automatic"][0]["bonus"] = []
    run_build(tmp_path, config, fake, "grid", "grid")
    with pytest.raises(ValueError, match="complete"):
        run_build(tmp_path, config, handlers_for(tmp_path), "validate", "validate")
    assert path.read_bytes() == raw
    previous["automatic"][0]["bonus"] = ["TOK"]
    # Authored slots must survive, not merely possess the right input digest.
    directory = tmp_path / "handmade/pl"
    directory.mkdir(parents=True)
    (directory / "sample.yaml").write_text(
        "- slot: 1\n  letters: [K, O, T]\n  words: [KOT]\n  expect_bonus: [TOK]\n"
    )
    from wordgame_pipeline.candidates.handmade import load_handmade

    authored, digest = load_handmade(tmp_path, index())
    previous["handmade_sha256"] = digest
    run_build(tmp_path, config, fake, "grid", "grid")
    with pytest.raises(ValueError, match="membership"):
        run_build(tmp_path, config, handlers_for(tmp_path), "validate", "validate")
    handmade = {k: v for k, v in grid().items() if k != "candidate_id"} | {
        "slot": 1,
        "expect_bonus": ["TOK"],
    }
    previous["handmade"] = [handmade]
    run_build(tmp_path, config, fake, "grid", "grid")
    run_build(tmp_path, config, handlers_for(tmp_path), "validate", "validate")
    assert json.loads(path.read_bytes())["payload"]["validation"]["counts"]["handmade"] == 1
    assert authored[0]["words"] == handmade["words"]
    assert main(["build", "--root", str(tmp_path), "--lang", "pl"]) == 1
    assert "export is not implemented" in capsys.readouterr().err
