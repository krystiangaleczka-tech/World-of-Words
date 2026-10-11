"""Rebuild the real shipped campaign in CI without native dictionary artifacts."""

import json
import shutil
from pathlib import Path

import pytest
from wordgame_pipeline.config import canonical_bytes, load_config
from wordgame_pipeline.content import digest, validate_content
from wordgame_pipeline.p1 import check, main

PIPELINE = Path(__file__).parents[1]
REPO = PIPELINE.parent


def workspace(tmp_path):
    root = tmp_path / "pipeline"
    for folder in (
        "config",
        "sources",
        "schema",
        "overrides",
        "handmade",
        "content-inputs",
        "content-evidence",
    ):
        shutil.copytree(PIPELINE / folder, root / folder)
    path = root / "reviews/pl"
    path.mkdir(parents=True)
    shutil.copy(PIPELINE / "reviews/pl/T-0129-words.csv", path)
    shutil.copy(REPO / "NOTICE", tmp_path)
    content = tmp_path / "game/content"
    shutil.copytree(REPO / "game/content", content)
    return root, content


def test_real_campaign_rebuild_is_offline_readonly(tmp_path):
    root, content = workspace(tmp_path)
    assert not (root / "build").exists()
    before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in tmp_path.rglob("*") if p.is_file()}
    assert check(root, content) == 65
    assert before == {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in before}
    assert not (root / "build").exists()
    pack = json.loads((content / "pl/packs/c-0001-0065.json").read_bytes())
    levels = pack["levels"]
    assert all(level["source"] == "handmade" for level in levels)
    words = [p["w"] for level in levels for p in level["words"]]
    assert len(words) == len(set(words))


def test_curated_opening_keeps_familiar_answers_and_complete_bonuses():
    pack = json.loads((REPO / "game/content/pl/packs/c-0001-0065.json").read_bytes())
    manifest = json.loads((REPO / "game/content/pl/manifest.json").read_bytes())
    levels = pack["levels"]
    assert manifest["content_version"] == 2
    assert [level["slot"] for level in levels] == list(range(1, 66))
    required = [{p["w"] for p in level["words"]} for level in levels]
    assert required[:10] == [
        {"KOT"},
        {"RAK"},
        {"DOM", "DYM"},
        {"LATO"},
        {"KOSA", "OSA"},
        {"WODA", "DWA"},
        {"KURA"},
        {"RYBA"},
        {"MOST"},
        {"PIES"},
    ]
    excluded = {"LAT", "KUR", "RYB", "KOS", "PSI", "CŁA", "DAŃ", "HAL", "JAJ", "JAR", "KAJ"}
    assert not set.union(*required) & excluded
    for slot, bonus in ((4, "LAT"), (5, "KOS"), (7, "KUR"), (8, "RYB"), (10, "PSI")):
        assert bonus in levels[slot - 1]["bonus"]
    assert required[-1] == {"PARASOL", "ROSA", "PAS"}
    assert max(len(level["letters"]) for level in levels) == 7
    assert all(level["difficulty"] == 0.0 for level in levels)


def test_changed_authored_input_is_not_silently_accepted(tmp_path):
    root, content = workspace(tmp_path)
    path = root / "handmade/pl/opening.yaml"
    path.write_bytes(path.read_bytes().replace(b"words: [KOT]", b"words: [KOT, KTO]"))
    with pytest.raises(ValueError, match="candidate inputs"):
        check(root, content)


def test_semantically_valid_pack_edit_still_fails_rebuild(tmp_path):
    root, content = workspace(tmp_path)
    pack_path = content / "pl/packs/c-0001-0065.json"
    pack = json.loads(pack_path.read_bytes())
    pack["levels"][-1]["seed"] += 1
    pack_path.write_bytes(canonical_bytes(pack))
    manifest_path = content / "pl/manifest.json"
    manifest = json.loads(manifest_path.read_bytes())
    manifest["packs"][0]["sha256"] = digest(pack_path.read_bytes())
    manifest_path.write_bytes(canonical_bytes(manifest))
    evidence_path = root / "content-evidence/pl.json"
    evidence = json.loads(evidence_path.read_bytes())
    evidence["manifest_sha256"] = digest(manifest_path.read_bytes())
    evidence_path.write_bytes(canonical_bytes(evidence))
    # This preserves schemas, hashes and all word/geometry semantics.
    assert validate_content(root, load_config(root, "pl"), content) == 65
    with pytest.raises(ValueError, match="deterministic export"):
        check(root, content)


@pytest.mark.parametrize(
    "relative", ["config/p1-pl.json", "reviews/pl/T-0129-words.csv", "schema/level.schema.json"]
)
def test_changed_committed_inputs_are_not_silently_accepted(tmp_path, relative):
    root, content = workspace(tmp_path)
    path = root / relative
    if relative.endswith("csv"):
        path.write_bytes(path.read_bytes() + b"\n")
    else:
        data = json.loads(path.read_bytes())
        if relative.startswith("config"):
            data["content_version"] += 1
        else:
            data["title"] = "Changed schema"
        path.write_bytes(canonical_bytes(data))
    with pytest.raises(ValueError, match="provenance"):
        check(root, content)


def test_broken_attribution_and_cli(tmp_path, capsys):
    root, content = workspace(tmp_path)
    args = ["--check", "--root", str(root), "--content-root", str(content)]
    assert main(args) == 0
    assert "65 PL levels" in capsys.readouterr().out
    (content / "NOTICE").write_text("incomplete")
    assert main(args) == 1
    assert "attribution" in capsys.readouterr().err
