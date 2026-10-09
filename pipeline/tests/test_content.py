"""Shipped content validation runs offline using reproducible compact evidence."""

import copy
import hashlib
import json
import os
import runpy
import shutil
from dataclasses import asdict
from pathlib import Path

import pytest
from wordgame_pipeline.annotate.sources import load_pin as annotation_pin
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import TierRules, canonical_bytes, load_config
from wordgame_pipeline.content import validate_content, validate_levels
from wordgame_pipeline.export import assemble
from wordgame_pipeline.export.publish import publish
from wordgame_pipeline.ingest.source import load_pin as source_pin
from wordgame_pipeline.stages import P1_STAGES, run_build

PIPELINE = Path(__file__).parents[1]


def workspace(root):
    fixture = runpy.run_path(str(PIPELINE / "tests/export/test_export.py"))["fixture"]
    previous, index, registry = fixture(30)
    for folder in ("config", "sources", "schema", "overrides"):
        shutil.copytree(PIPELINE / folder, root / folder)
    handmade = root / "handmade/pl/opening.yaml"
    handmade.parent.mkdir(parents=True)
    handmade.write_text(
        json.dumps(
            [
                {k: e[k] for k in ("slot", "letters", "words", "expect_bonus")}
                for e in previous["handmade"]
            ]
        )
    )
    config = load_config(root, "pl")
    rules = asdict(config.tier_rules or TierRules())
    tiers = {
        "source": source_pin(root).to_dict(),
        "annotation_sources": annotation_pin(root),
        "tier_rules": rules,
        "tier_rules_sha256": hashlib.sha256(canonical_bytes(rules)).hexdigest(),
        "overrides_sha256": hashlib.sha256((root / "overrides/pl.csv").read_bytes()).hexdigest(),
        "records": [{"word": w, "tier": t} for w, t in index.tiers.items()],
    }
    run_build(
        root,
        config,
        {s.name: lambda _c, _p: tiers for s in P1_STAGES if s.number <= 5},
        last="tiers",
    )
    content = root / "game/content"
    publish(assemble(previous, 30, 1, index, registry), content / "pl", registry)
    return config, content


def test_evidence_and_readonly_repeat(tmp_path):
    config, content = workspace(tmp_path)
    assert validate_content(tmp_path, config, content, prepare=True) == 30
    evidence = tmp_path / "content-evidence/pl.json"
    raw = evidence.read_bytes()
    before = {p: p.stat().st_mtime_ns for p in tmp_path.rglob("*") if p.is_file()}
    assert validate_content(tmp_path, config, content) == 30
    assert before == {p: p.stat().st_mtime_ns for p in before}
    assert validate_content(tmp_path, config, content, prepare=True) == 30
    assert evidence.read_bytes() == raw
    # The CI path does not read ignored full source/build artifacts.
    shutil.rmtree(tmp_path / "build")
    assert validate_content(tmp_path, config, content) == 30


def test_missing_initial_content_and_cli(tmp_path, capsys):
    config, content = workspace(tmp_path)
    shutil.rmtree(content)
    assert validate_content(tmp_path, config, content) is None
    assert main(["validate-content", "--root", str(tmp_path), "--content-root", str(content)]) == 0
    assert "SKIP" in capsys.readouterr().out
    with pytest.raises(ValueError, match="without content"):
        validate_content(tmp_path, config, content, prepare=True)
    evidence = tmp_path / "content-evidence/pl.json"
    evidence.parent.mkdir()
    evidence.write_text("{}")
    assert main(["validate-content", "--root", str(tmp_path), "--content-root", str(content)]) == 1
    assert "wg:" in capsys.readouterr().err


@pytest.mark.parametrize(
    "field",
    [
        "source",
        "annotation_sources",
        "config_sha256",
        "overrides_sha256",
        "handmade_sha256",
        "manifest_sha256",
    ],
)
def test_stale_evidence(tmp_path, field):
    config, content = workspace(tmp_path)
    validate_content(tmp_path, config, content, prepare=True)
    path = tmp_path / "content-evidence/pl.json"
    data = json.loads(path.read_bytes())
    data[field] = "stale"
    path.write_bytes(canonical_bytes(data))
    with pytest.raises(ValueError, match="Stale"):
        validate_content(tmp_path, config, content)


@pytest.mark.parametrize(
    "kind",
    [
        "hash",
        "ranges",
        "id",
        "schema",
        "geometry",
        "bonus",
        "formability",
        "spacing",
        "extra",
        "symlink",
        "fifo",
    ],
)
def test_corrupt_content_and_atomic_evidence(tmp_path, kind):
    config, content = workspace(tmp_path)
    validate_content(tmp_path, config, content, prepare=True)
    evidence = tmp_path / "content-evidence/pl.json"
    old = evidence.read_bytes()
    directory = content / "pl"
    manifest_path = directory / "manifest.json"
    manifest = json.loads(manifest_path.read_bytes())
    pack_path = directory / manifest["packs"][0]["file"]
    pack = json.loads(pack_path.read_bytes())
    if kind == "extra":
        (directory / "notes").write_text("keep")
    elif kind == "symlink":
        (directory / "linked").symlink_to(pack_path)
    elif kind == "fifo":
        os.mkfifo(directory / "pipe")
    elif kind == "hash":
        pack_path.write_bytes(b"{}\n")
    else:
        level = pack["levels"][-1]
        if kind == "ranges":
            manifest["packs"][0]["first"] = 2
        elif kind == "id":
            level["id"] = "pl-c-000099"
        elif kind == "schema":
            level["extra"] = 1
        elif kind == "geometry":
            level["grid"]["h"] = 4
        elif kind == "bonus":
            level["bonus"] = [level["words"][0]["w"]]
        elif kind == "formability":
            level["letters"] = list("ZZZ")
        else:
            replacement = copy.deepcopy(pack["levels"][15])
            replacement["id"], replacement["slot"] = level["id"], level["slot"]
            pack["levels"][-1] = replacement
        pack_path.write_bytes(canonical_bytes(pack))
        manifest["packs"][0]["sha256"] = hashlib.sha256(pack_path.read_bytes()).hexdigest()
        manifest_path.write_bytes(canonical_bytes(manifest))
    with pytest.raises((ValueError, OSError)):
        validate_content(tmp_path, config, content, prepare=True)
    assert evidence.read_bytes() == old


@pytest.mark.parametrize("kind", ["symlink", "fifo"])
def test_evidence_path_safety(tmp_path, kind):
    config, content = workspace(tmp_path)
    path = tmp_path / "content-evidence/pl.json"
    path.parent.mkdir()
    if kind == "symlink":
        target = tmp_path / "keep.json"
        target.write_text("keep")
        path.symlink_to(target)
    else:
        os.mkfifo(path)
    for prepare in (False, True):
        with pytest.raises(ValueError):
            validate_content(tmp_path, config, content, prepare=prepare)
    assert path.exists()


def test_handmade_intent_preserved(tmp_path):
    config, content = workspace(tmp_path)
    validate_content(tmp_path, config, content, prepare=True)
    evidence = tmp_path / "content-evidence/pl.json"
    old = evidence.read_bytes()
    authored = tmp_path / "handmade/pl/opening.yaml"
    entries = json.loads(authored.read_text())
    entries[1]["letters"].reverse()
    authored.write_text(json.dumps(entries))
    with pytest.raises(ValueError, match="intent"):
        validate_content(tmp_path, config, content, prepare=True)
    assert evidence.read_bytes() == old


def test_landmark_relationship():
    fixture = runpy.run_path(str(PIPELINE / "tests/export/test_export.py"))["fixture"]
    previous, index, registry = fixture(30)
    levels = assemble(previous, 30, 1, index, registry)["files"]["packs/c-0001-0030.json"]["levels"]
    levels[15]["source"] = "handmade"
    levels[15]["landmark"] = True
    with pytest.raises(ValueError, match="landmark"):
        validate_levels(levels, index, registry)
