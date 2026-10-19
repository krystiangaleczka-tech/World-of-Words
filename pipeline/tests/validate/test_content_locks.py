"""Release guard composes with existing offline content and evidence validation."""

import hashlib
import json
import os
import runpy
import shutil
from pathlib import Path

import pytest
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.content import validate_content
from wordgame_pipeline.validate.locks import LockedSlot, ReleaseLock, geometry_sha256

ROOT = Path(__file__).resolve().parents[2]
workspace = runpy.run_path(str(ROOT / "tests/test_content.py"))["workspace"]


def setup(root, released=15):
    config, content = workspace(root)
    manifest_path = content / "pl/manifest.json"
    manifest = json.loads(manifest_path.read_bytes())
    pack_path = content / "pl" / manifest["packs"][0]["file"]
    pack = json.loads(pack_path.read_bytes())
    lock = ReleaseLock(
        "pl",
        tuple(
            LockedSlot(e["slot"], e["id"], geometry_sha256(e)) for e in pack["levels"][:released]
        ),
    )
    path = root / "locks/pl.lock.json"
    path.parent.mkdir()
    path.write_bytes(canonical_bytes(lock.to_dict()))
    return config, content, path, manifest_path, pack_path, pack


def save_pack(manifest_path, pack_path, pack):
    pack_path.write_bytes(canonical_bytes(pack))
    manifest = json.loads(manifest_path.read_bytes())
    manifest["packs"][0]["sha256"] = hashlib.sha256(pack_path.read_bytes()).hexdigest()
    manifest_path.write_bytes(canonical_bytes(manifest))


def test_locked_repeat_append_and_cli_are_readonly(tmp_path, capsys):
    config, content, lock, _manifest, _pack_path, _pack = setup(tmp_path)
    assert validate_content(tmp_path, config, content, prepare=True, require_lock=True) == 30
    before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in tmp_path.rglob("*") if p.is_file()}
    assert validate_content(tmp_path, config, content) == 30
    assert (
        main(
            [
                "validate-content",
                "--root",
                str(tmp_path),
                "--content-root",
                str(content),
                "--require-release-lock",
            ]
        )
        == 0
    )
    assert "30 pl campaign levels validated" in capsys.readouterr().out
    assert {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in before} == before
    assert lock.read_bytes() == before[lock][0]
    # Thirty levels validate against a fifteen-level released prefix: append is allowed.
    assert len(json.loads(lock.read_bytes())["levels"]) == 15


def test_optional_required_absence_and_missing_campaign(tmp_path, capsys):
    config, content, path, *_ = setup(tmp_path)
    raw = path.read_bytes()
    path.unlink()
    assert validate_content(tmp_path, config, content, prepare=True) == 30
    with pytest.raises(ValueError, match="lock required"):
        validate_content(tmp_path, config, content, require_lock=True)
    with pytest.raises(ValueError, match="must be bool"):
        validate_content(tmp_path, config, content, require_lock=1)
    assert (
        main(
            [
                "validate-content",
                "--root",
                str(tmp_path),
                "--content-root",
                str(content),
                "--require-release-lock",
            ]
        )
        == 1
    )
    captured = capsys.readouterr()
    assert not captured.out and "lock required" in captured.err
    shutil.rmtree(content)
    (tmp_path / "content-evidence/pl.json").unlink()
    assert validate_content(tmp_path, config, content) is None
    path.write_bytes(raw)
    with pytest.raises(ValueError, match="content missing"):
        validate_content(tmp_path, config, content)
    assert main(["validate-content", "--root", str(tmp_path), "--content-root", str(content)]) == 1
    assert not capsys.readouterr().out


def test_geometry_change_rejected_before_evidence_even_with_valid_new_authorship(tmp_path):
    config, content, lock, manifest, pack_path, pack = setup(tmp_path)
    validate_content(tmp_path, config, content, prepare=True)
    evidence = tmp_path / "content-evidence/pl.json"
    before, lock_bytes = evidence.read_bytes(), lock.read_bytes()
    pack["levels"][1]["letters"].reverse()
    save_pack(manifest, pack_path, pack)
    authored = tmp_path / "handmade/pl/opening.yaml"
    entries = json.loads(authored.read_text())
    entries[1]["letters"].reverse()
    authored.write_text(json.dumps(entries))
    for prepare in (False, True):
        with pytest.raises(ValueError, match="Released geometry changed at slot 2"):
            validate_content(tmp_path, config, content, prepare=prepare)
        assert evidence.read_bytes() == before and lock.read_bytes() == lock_bytes
    # Proves this valid geometry/authorship change would pass ordinary P1 gates.
    lock.unlink()
    assert validate_content(tmp_path, config, content, prepare=True) == 30


def test_allowed_seed_repair_and_independent_bonus_gate(tmp_path):
    config, content, lock, manifest, pack_path, pack = setup(tmp_path)
    before = lock.read_bytes()
    pack["levels"][0]["seed"] += 100
    save_pack(manifest, pack_path, pack)
    assert validate_content(tmp_path, config, content, prepare=True) == 30
    assert validate_content(tmp_path, config, content, require_lock=True) == 30
    evidence = tmp_path / "content-evidence/pl.json"
    raw = evidence.read_bytes()
    pack["levels"][0]["bonus"] = [pack["levels"][0]["words"][0]["w"]]
    save_pack(manifest, pack_path, pack)
    with pytest.raises(ValueError):
        validate_content(tmp_path, config, content, prepare=True)
    assert evidence.read_bytes() == raw and lock.read_bytes() == before


@pytest.mark.parametrize("kind", ["malformed", "symlink", "fifo"])
def test_existing_bad_lock_cannot_be_ignored_or_overwritten(tmp_path, kind):
    config, content, path, *_ = setup(tmp_path)
    validate_content(tmp_path, config, content, prepare=True)
    evidence = tmp_path / "content-evidence/pl.json"
    raw = evidence.read_bytes()
    path.unlink()
    if kind == "malformed":
        path.write_text("{}")
    elif kind == "symlink":
        path.symlink_to(tmp_path / "missing")
    else:
        os.mkfifo(path)
    for prepare in (False, True):
        with pytest.raises(ValueError):
            validate_content(tmp_path, config, content, prepare=prepare)
        assert evidence.read_bytes() == raw


@pytest.mark.parametrize("field", ["manifest_sha256", "records"])
def test_lock_does_not_replace_independent_evidence_checks(tmp_path, field):
    config, content, _lock, *_ = setup(tmp_path)
    validate_content(tmp_path, config, content, prepare=True)
    path = tmp_path / "content-evidence/pl.json"
    evidence = json.loads(path.read_bytes())
    evidence[field] = (
        "stale" if field == "manifest_sha256" else [{"word": "AAA", "tier": "invalid"}]
    )
    path.write_bytes(canonical_bytes(evidence))
    raw = path.read_bytes()
    with pytest.raises(ValueError):
        validate_content(tmp_path, config, content, require_lock=True)
    assert path.read_bytes() == raw


def test_truncated_released_prefix_rejected_after_valid_bundle(tmp_path):
    config, content, _lock, manifest, pack_path, pack = setup(tmp_path, released=30)
    pack["levels"].pop()
    save_pack(manifest, pack_path, pack)
    data = json.loads(manifest.read_bytes())
    data["slots"] = data["packs"][0]["last"] = 29
    manifest.write_bytes(canonical_bytes(data))
    with pytest.raises(ValueError, match="Released campaign prefix missing"):
        validate_content(tmp_path, config, content, prepare=True)
    assert not (tmp_path / "content-evidence/pl.json").exists()
