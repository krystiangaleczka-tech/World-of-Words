"""Source-backed pool and strict authoring regressions, without native dependencies."""

import copy
import json
import shutil
from pathlib import Path

import pytest
from wordgame_pipeline.annotate.sources import load_pin as annotation_pin
from wordgame_pipeline.candidates import handlers_for
from wordgame_pipeline.candidates.core import WordIndex
from wordgame_pipeline.candidates.handmade import load_handmade
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import canonical_bytes, load_config
from wordgame_pipeline.ingest.source import load_pin as source_pin
from wordgame_pipeline.stages import run_build

PIPELINE = Path(__file__).parents[2]


def workspace(root):
    for folder in ("config", "sources", "handmade/pl"):
        (root / folder).mkdir(parents=True)
    shutil.copyfile(PIPELINE / "config/pl.yaml", root / "config/pl.yaml")
    for name in ("annotation-pl.json", "sjp-pl.json"):
        shutil.copyfile(PIPELINE / "sources" / name, root / "sources" / name)
    return load_config(root, "pl")


def records(**words):
    return [{"word": word, "tier": tier} for word, tier in sorted(words.items())]


def test_submultisets_and_tiers(tmp_path):
    config = workspace(tmp_path)
    index = WordIndex(records(KOT="level_ok", TOK="bonus_ok", OKO="bonus_ok", KOK="banned"), config)
    assert index.pools(list("KOTO")) == {"level_ok": ["KOT"], "bonus_ok": ["OKO", "TOK"]}
    assert index.pools(list("KOT"))["bonus_ok"] == ["TOK"]
    index = WordIndex(records(ZOL="level_ok", ŻÓŁ="level_ok"), config)
    assert index.pools(list("ŻÓŁ")) == {"level_ok": ["ŻÓŁ"], "bonus_ok": []}
    for letters in (["Q", "O", "T"], list("kot"), ["KO", "T", "O"], list("KO")):
        with pytest.raises(ValueError):
            index.pools(letters)
    for rows in (
        [{"word": "kot", "tier": "level_ok"}],
        records(KOT="unknown"),
        records(KOT="level_ok") * 2,
        list(reversed(records(KOT="level_ok", TOK="bonus_ok"))),
    ):
        with pytest.raises(ValueError):
            WordIndex(rows, config)


def test_seed_signature_deduplication(tmp_path):
    config = workspace(tmp_path)
    rows = records(KOT="level_ok", TOK="level_ok", OKO="bonus_ok", DOM="level_ok")
    original = copy.deepcopy(rows)
    automatic = WordIndex(rows, config).automatic()
    assert rows == original
    assert len(automatic) == 2
    assert automatic == WordIndex(copy.deepcopy(rows), config).automatic()
    wheel = next(c for c in automatic if c["id"] == "pl-auto-KOT")
    assert wheel == {
        "id": "pl-auto-KOT",
        "letters": list("KOT"),
        "seeds": ["KOT", "TOK"],
        "level_ok": ["KOT", "TOK"],
        "bonus_ok": [],
    }
    assert WordIndex(records(OKO="bonus_ok"), config).automatic() == []


def test_handmade_validation_and_bonus(tmp_path):
    config = workspace(tmp_path)
    index = WordIndex(
        records(
            DOM="level_ok",
            MODA="level_ok",
            ODA="bonus_ok",
            DAM="level_ok",
            KOT="level_ok",
            TOK="bonus_ok",
        ),
        config,
    )
    path = tmp_path / "handmade/pl/onboarding.yaml"
    example = """- slot: 1
  letters: [K, O, T]
  words: [KOT]
  grid: [{w: KOT, x: 0, y: 0, dir: h}]
- slot: 5
  letters: [D, O, M, A]
  words: [DOM, MODA]
  expect_bonus: [ODA]
"""
    path.write_text(example)
    result, digest = load_handmade(tmp_path, index)
    assert result[0]["bonus"] == ["TOK"]
    assert result[0]["grid"] == [{"w": "KOT", "x": 0, "y": 0, "dir": "h"}]
    assert result[1]["bonus"] == ["DAM", "ODA"]
    assert load_handmade(tmp_path, index) == (result, digest)
    valid = {"slot": 1, "letters": list("KOT"), "words": ["KOT"]}
    bad = [
        {**valid, "slot": True},
        {**valid, "slot": 0},
        {**valid, "letters": list("kot")},
        {**valid, "words": ["TOK"]},
        {**valid, "words": ["LAS"]},
        {**valid, "words": ["KOT", "KOT"]},
        {**valid, "expect_bonus": ["KOT"]},
        {**valid, "expect_bonus": ["LAS"]},
        {**valid, "typo": 1},
        {**valid, "grid": [{"w": "KOT", "x": True, "y": 0, "dir": "h"}]},
        {**valid, "grid": [{"w": "KOT", "x": 0, "y": 0, "dir": "diagonal"}]},
        {**valid, "grid": []},
        {**valid, "grid": [{"w": "TOK", "x": 0, "y": 0, "dir": "h"}]},
    ]
    for value in bad:
        path.write_text(json.dumps([value]))
        with pytest.raises(ValueError):
            load_handmade(tmp_path, index)
    for text in ("- slot: 1\n  slot: 2\n", "- &a {slot: 1}\n- *a\n", "!unsafe []", "[]\n---\n[]"):
        path.write_text(text)
        with pytest.raises(ValueError):
            load_handmade(tmp_path, index)
    path.write_text(json.dumps([valid, valid]))
    with pytest.raises(ValueError, match="slots"):
        load_handmade(tmp_path, index)
    path.write_text(json.dumps([valid]))
    (path.parent / "other.yaml").write_text(json.dumps([valid]))
    with pytest.raises(ValueError, match="slots"):
        load_handmade(tmp_path, index)


def test_stage_determinism_and_atomicity(tmp_path, capsys):
    config = workspace(tmp_path)
    previous = {
        "source": source_pin(tmp_path).to_dict(),
        "annotation_sources": annotation_pin(tmp_path),
        "tier_rules": config.to_dict()["tier_rules"],
        "tier_rules_sha256": "a" * 64,
        "overrides_sha256": "b" * 64,
        "records": records(KOT="level_ok", TOK="bonus_ok"),
    }
    fake = {
        name: lambda _cfg, _prior: previous for name in ("ingest", "normalize", "annotate", "tiers")
    }
    run_build(tmp_path, config, fake, last="tiers")
    handlers = handlers_for(tmp_path)
    path = run_build(tmp_path, config, handlers, "candidates", "candidates")[0]
    original = path.read_bytes()
    run_build(tmp_path, config, handlers, "candidates", "candidates")
    assert path.read_bytes() == original
    assert canonical_bytes(json.loads(original)) == original
    assert (
        main(
            [
                "build",
                "--root",
                str(tmp_path),
                "--lang",
                "pl",
                "--from",
                "candidates",
                "--to",
                "candidates",
            ]
        )
        == 0
    )
    handmade = tmp_path / "handmade/pl/test.yaml"
    handmade.write_text("- slot: 1\n  letters: [K, O, T]\n  words: [KOT]\n")
    run_build(tmp_path, config, handlers, "candidates", "candidates")
    changed = path.read_bytes()
    assert changed != original
    assert json.loads(changed)["payload"]["handmade"][0]["bonus"] == ["TOK"]
    handmade.write_text("broken")
    with pytest.raises(ValueError):
        run_build(tmp_path, config, handlers, "candidates", "candidates")
    assert path.read_bytes() == changed
    handmade.unlink()
    previous["annotation_sources"]["morphology"]["version"] = "999"
    run_build(tmp_path, config, fake, last="tiers")
    with pytest.raises(ValueError, match="provenance"):
        run_build(tmp_path, config, handlers, "candidates", "candidates")
    assert path.read_bytes() == changed
    assert main(["build", "--root", str(tmp_path), "--lang", "pl", "--to", "grid"]) == 1
    assert "grid is not implemented" in capsys.readouterr().err
