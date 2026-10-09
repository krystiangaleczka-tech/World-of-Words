"""Export behavior: deterministic bytes, sequencing and safe publication."""

import copy
import hashlib
import itertools
import json
import os
import shutil
from dataclasses import asdict
from pathlib import Path

import pytest
from wordgame_pipeline.annotate.sources import load_pin as annotation_pin
from wordgame_pipeline.candidates.core import WordIndex
from wordgame_pipeline.candidates.handmade import load_handmade
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import TierRules, canonical_bytes, load_config
from wordgame_pipeline.export import assemble, handlers_for
from wordgame_pipeline.export.publish import publish
from wordgame_pipeline.ingest.source import load_pin as source_pin
from wordgame_pipeline.stages import P1_STAGES, artifact_path, read_artifact, run_build
from wordgame_pipeline.validate import SchemaRegistry
from wordgame_pipeline.validate import handlers_for as validation_handlers

PIPELINE = Path(__file__).parents[2]


def fixture(count=220):
    words = [
        "".join(chars)
        for chars in itertools.islice(
            itertools.combinations_with_replacement("ABCDEFGHIJKLMNOPRSTUWYZ", 3), count
        )
    ]
    index = WordIndex([{"word": w, "tier": "level_ok"} for w in words], load_config(PIPELINE, "pl"))
    entries = [
        {
            "letters": list(w),
            "words": [w],
            "placements": [{"w": w, "x": 0, "y": 0, "dir": "v"}],
            "grid": {"w": 1, "h": 3},
            "bonus": [],
            "seed": i,
            "candidate_id": f"pl-auto-{w}",
        }
        for i, w in enumerate(words)
    ]
    handmade = [
        {**{k: v for k, v in e.items() if k != "candidate_id"}, "slot": i, "expect_bonus": []}
        for i, e in enumerate(entries[:15], 1)
    ]
    return {"automatic": entries[15:], "handmade": handmade}, index, SchemaRegistry(PIPELINE)


def snapshot(output):
    return {
        p.relative_to(output).as_posix(): p.read_bytes() for p in output.rglob("*") if p.is_file()
    }


def test_packs_and_repeat():
    previous, index, registry = fixture()
    original = copy.deepcopy(previous)
    result = assemble(previous, 201, 1, index, registry)
    manifest = result["files"]["manifest.json"]
    assert [(e["first"], e["last"]) for e in manifest["packs"]] == [
        (1, 100),
        (101, 200),
        (201, 201),
    ]
    levels = []
    for entry in manifest["packs"]:
        pack = result["files"][entry["file"]]
        assert entry["sha256"] == hashlib.sha256(canonical_bytes(pack)).hexdigest()
        levels.extend(pack["levels"])
    assert [e["slot"] for e in levels] == list(range(1, 202))
    assert all(type(e["difficulty"]) is float and e["difficulty"] == 0.0 for e in levels)
    assert [e["source"] for e in levels[:16]] == ["handmade"] * 15 + ["generated"]
    assert all(e["id"] == f"pl-c-{e['slot']:06d}" and e["pipeline"] == "0.1.0" for e in levels)
    assert previous == original
    mixed = copy.deepcopy(previous)
    mixed["automatic"].append(
        {
            "letters": list("ZZZZ"),
            "words": ["ZZZZ"],
            "placements": [{"w": "ZZZZ", "x": 0, "y": 0, "dir": "v"}],
            "grid": {"w": 1, "h": 4},
            "bonus": [],
            "seed": 300,
            "candidate_id": "pl-auto-ZZZZ",
        }
    )
    mixed_index = WordIndex(
        sorted(
            [{"word": w, "tier": t} for w, t in index.tiers.items()]
            + [{"word": "ZZZZ", "tier": "level_ok"}],
            key=lambda e: e["word"],
        ),
        load_config(PIPELINE, "pl"),
    )
    mixed_result = assemble(mixed, 221, 1, mixed_index, registry)
    wheels = [
        len(level["letters"])
        for pack in mixed_result["files"].values()
        if "levels" in pack
        for level in pack["levels"]
        if level["source"] == "generated"
    ]
    assert wheels == sorted(wheels) and wheels[-1] == 4
    previous["automatic"].reverse()
    previous["handmade"].reverse()
    assert canonical_bytes(assemble(previous, 201, 1, index, registry)) == canonical_bytes(result)


def test_selection_constraints():
    previous, index, registry = fixture()
    bad = copy.deepcopy(previous)
    bad["handmade"].pop()
    with pytest.raises(ValueError, match="onboarding"):
        assemble(bad, 201, 1, index, registry)
    for distance in (99, 100):
        bad = copy.deepcopy(previous)
        bad["handmade"].append({**bad["handmade"][0], "slot": 1 + distance})
        if distance == 99:
            with pytest.raises(ValueError, match="spacing"):
                assemble(bad, 201, 1, index, registry)
        else:
            assemble(bad, 201, 1, index, registry)
    bad = copy.deepcopy(previous)
    candidate = bad["automatic"][0]
    bad["handmade"].append(
        {
            **{k: v for k, v in candidate.items() if k != "candidate_id"},
            "slot": 20,
            "expect_bonus": [],
        }
    )
    result = assemble(bad, 30, 1, index, registry)
    levels = result["files"]["packs/c-0001-0030.json"]["levels"]
    assert levels[15]["words"] != candidate["placements"]
    assert levels[19]["words"] == candidate["placements"]
    bad = copy.deepcopy(previous)
    bad["automatic"].append(bad["automatic"][0])
    with pytest.raises(ValueError, match="Duplicate"):
        assemble(bad, 30, 1, index, registry)
    bad = copy.deepcopy(previous)
    bad["automatic"] = [{**e, "letters": list("AAAKOTYZ")} for e in bad["automatic"]]
    with pytest.raises(ValueError, match="slot 16"):
        assemble(bad, 30, 1, index, registry)
    with pytest.raises(ValueError, match="slot 221"):
        assemble(previous, 221, 1, index, registry)
    bad = copy.deepcopy(previous)
    bad["handmade"][0]["letters"] = list("AAAKOTYZ")
    with pytest.raises(ValueError, match="landmarks"):
        assemble(bad, 30, 1, index, registry)
    # An eight-tile handmade level outside onboarding is an actual landmark;
    # its shorter form is a bonus and does not violate crossword spacing.
    bad = copy.deepcopy(previous)
    word = "AAABBBBB"
    wheel = {
        "letters": list(word),
        "words": [word],
        "placements": [{"w": word, "x": 0, "y": 0, "dir": "v"}],
        "grid": {"w": 1, "h": 8},
        "bonus": ["AAA", "AAB", "ABB", "BBB"],
        "seed": 99,
        "slot": 16,
        "expect_bonus": [],
    }
    big_index = WordIndex(
        sorted(
            [{"word": w, "tier": t} for w, t in index.tiers.items()]
            + [{"word": word, "tier": "level_ok"}],
            key=lambda e: e["word"],
        ),
        load_config(PIPELINE, "pl"),
    )
    wheel["bonus"] = sorted(big_index.pools(wheel["letters"])["level_ok"])
    wheel["bonus"].remove(word)
    bad["handmade"].append(wheel)
    landmark = assemble(bad, 30, 1, big_index, registry)["files"]["packs/c-0001-0030.json"][
        "levels"
    ][15]
    assert landmark["landmark"] is True and landmark["source"] == "handmade"
    for slots, version in ((True, 1), (14, 1), (10000, 1), (30, False), (30, 0)):
        with pytest.raises(ValueError):
            assemble(previous, slots, version, index, registry)


def test_publish_versions_and_check(tmp_path):
    previous, index, registry = fixture()
    result = assemble(previous, 30, 1, index, registry)
    output = tmp_path / "pl"
    publish(result, output, registry)
    old = snapshot(output)
    publish(result, output, registry)
    publish(result, output, registry, check=True)
    assert snapshot(output) == old
    changed = assemble(previous, 31, 1, index, registry)
    with pytest.raises(ValueError, match="version"):
        publish(changed, output, registry)
    with pytest.raises(ValueError, match="differs"):
        publish(changed, output, registry, check=True)
    assert snapshot(output) == old
    publish(assemble(previous, 31, 2, index, registry), output, registry)
    for version in (1, 4):
        with pytest.raises(ValueError, match="version"):
            publish(assemble(previous, 32, version, index, registry), output, registry)
    for kind in ("extra", "missing", "corrupt", "symlink", "directory", "fifo"):
        copy_output = tmp_path / kind
        shutil.copytree(output, copy_output)
        pack = next((copy_output / "packs").iterdir())
        if kind == "extra":
            (copy_output / "notes.txt").write_text("keep")
        elif kind == "missing":
            pack.unlink()
        elif kind == "corrupt":
            pack.write_text("{}")
        elif kind == "directory":
            (copy_output / "packs/packs").mkdir()
        elif kind == "fifo":
            os.mkfifo(copy_output / "unmanaged.pipe")
        else:
            (copy_output / "link").symlink_to(pack)
        before = snapshot(copy_output)
        with pytest.raises(ValueError):
            publish(assemble(previous, 32, 3, index, registry), copy_output, registry)
        assert snapshot(copy_output) == before
        if kind == "fifo":
            assert (copy_output / "unmanaged.pipe").exists()
    output_link = tmp_path / "linked"
    output_link.symlink_to(output, target_is_directory=True)
    with pytest.raises(ValueError, match="symlinks"):
        publish(result, output_link, registry)


def test_publication_failure(tmp_path, monkeypatch):
    import wordgame_pipeline.export.publish as module

    previous, index, registry = fixture()
    output = tmp_path / "pl"
    publish(assemble(previous, 30, 1, index, registry), output, registry)
    before = snapshot(output)
    replace = module.os.replace

    def fail_new(source, target):
        if Path(source).name == "new":
            raise OSError("injected replacement failure")
        replace(source, target)

    monkeypatch.setattr(module.os, "replace", fail_new)
    with pytest.raises(OSError, match="injected"):
        publish(assemble(previous, 31, 2, index, registry), output, registry)
    assert snapshot(output) == before
    assert sorted(p.name for p in tmp_path.iterdir()) == ["pl"]


def test_cli_and_provenance(tmp_path, capsys):
    previous, index, _registry = fixture(30)
    for folder in ("config", "sources", "schema", "overrides"):
        shutil.copytree(PIPELINE / folder, tmp_path / folder)
    handmade_path = tmp_path / "handmade/pl/onboarding.yaml"
    handmade_path.parent.mkdir(parents=True)
    handmade_path.write_text(
        json.dumps(
            [
                {k: e[k] for k in ("slot", "letters", "words", "expect_bonus")}
                for e in previous["handmade"]
            ]
        )
    )
    config = load_config(tmp_path, "pl")
    _authored, digest = load_handmade(tmp_path, index)
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
    tiers = {**provenance, "records": [{"word": w, "tier": t} for w, t in index.tiers.items()]}
    previous.update({**provenance, "handmade_sha256": digest})
    fake = {s.name: lambda _c, _p: tiers for s in P1_STAGES if s.number <= 6}
    fake["grid"] = lambda _c, _p: previous
    run_build(tmp_path, config, fake, last="grid")
    run_build(tmp_path, config, validation_handlers(tmp_path), "validate", "validate")
    args = ["build", "--root", str(tmp_path), "--lang", "pl", "--from", "export", "--to", "export"]
    assert main(args) == 1
    assert "requires --slots" in capsys.readouterr().err
    assert main([*args, "--plan"]) == 0
    path = artifact_path(tmp_path, "pl", P1_STAGES[-1])
    assert not path.exists()
    output = tmp_path / "content/pl"
    args += ["--slots", "30", "--content-version", "1", "--output", str(output)]
    assert main(args) == 0
    raw, files = path.read_bytes(), snapshot(output)
    assert main(args) == 0
    assert path.read_bytes() == raw and snapshot(output) == files
    before = {p: p.stat().st_mtime_ns for p in tmp_path.rglob("*") if p.is_file()}
    assert main([*args, "--check"]) == 0
    assert before == {p: p.stat().st_mtime_ns for p in before}
    payload, _raw = read_artifact(tmp_path, config, P1_STAGES[-2])
    payload["validation"]["schema_sha256"]["level"] = "bad"
    with pytest.raises(ValueError, match="Stale validation"):
        handlers_for(tmp_path, 30, 1)["export"](config, payload)
    payload["automatic"][0]["bonus"] = ["BAD"]
    with pytest.raises(ValueError):
        handlers_for(tmp_path, 30, 1)["export"](config, payload)
    assert path.read_bytes() == raw and snapshot(output) == files
