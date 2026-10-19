"""Readonly validated proposals identify content and validation context."""

import copy
import hashlib
import json
import os
import runpy
import shutil
from dataclasses import FrozenInstanceError, replace
from pathlib import Path

import pytest
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.content import validate_content
from wordgame_pipeline.release_plan import plan_release_lock

ROOT = Path(__file__).resolve().parents[1]
workspace = runpy.run_path(str(ROOT / "tests/test_content.py"))["workspace"]


def setup(root):
    config, content = workspace(root)
    validate_content(root, config, content, prepare=True)
    return config, content


def snapshot(root):
    return {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in root.rglob("*") if p.is_file()}


def test_initial_deterministic_readonly_proposal_and_immutable_report(tmp_path):
    _config, content = setup(tmp_path)
    before = snapshot(tmp_path)
    plan = plan_release_lock(tmp_path, content, 15)
    assert plan == plan_release_lock(tmp_path, content, 15)
    assert snapshot(tmp_path) == before and not (tmp_path / "locks").exists()
    report = plan.to_dict()
    assert report["scope"] == "release-lock-proposal" and report["schema_version"] == 1
    assert report["campaign_slots"] == 30 and report["released_through"] == 15
    assert report["previous_sha256"] is None
    assert plan.sha256 == hashlib.sha256(canonical_bytes(report)).hexdigest()
    assert (
        report["proposed_sha256"]
        == hashlib.sha256(canonical_bytes(plan.proposed.to_dict())).hexdigest()
    )
    report["proposed"]["levels"].clear()
    assert len(plan.proposed.levels) == 15
    with pytest.raises(FrozenInstanceError):
        plan.campaign_slots = 1
    # No absolute paths or timestamps appear in the serialized proposal.
    assert str(tmp_path) not in json.dumps(plan.to_dict())


def test_extension_noop_and_semantic_previous_lock_identity(tmp_path):
    _config, content = setup(tmp_path)
    initial = plan_release_lock(tmp_path, content, 15)
    path = tmp_path / "locks/pl.lock.json"
    path.parent.mkdir()
    path.write_bytes(canonical_bytes(initial.proposed.to_dict()))
    extended = plan_release_lock(tmp_path, content, 20)
    assert extended.proposed.levels[:15] == initial.proposed.levels
    assert extended.previous == initial.proposed
    noop = plan_release_lock(tmp_path, content, 15)
    assert noop.previous == noop.proposed and noop.sha256 != initial.sha256
    path.write_text(json.dumps(initial.proposed.to_dict(), indent=2, sort_keys=False))
    assert plan_release_lock(tmp_path, content, 20) == extended
    assert plan_release_lock(tmp_path, content, 21).sha256 != extended.sha256


def test_fingerprints_cover_tail_metadata_evidence_and_schema_context(tmp_path):
    config, content = setup(tmp_path)
    first = plan_release_lock(tmp_path, content, 15)
    manifest_path = content / "pl/manifest.json"
    manifest = json.loads(manifest_path.read_bytes())
    pack_path = content / "pl" / manifest["packs"][0]["file"]
    pack = json.loads(pack_path.read_bytes())
    pack["levels"][-1]["seed"] += 100  # Outside the proposed release prefix.
    pack_path.write_bytes(canonical_bytes(pack))
    manifest["packs"][0]["sha256"] = hashlib.sha256(pack_path.read_bytes()).hexdigest()
    manifest_path.write_bytes(canonical_bytes(manifest))
    validate_content(tmp_path, config, content, prepare=True)
    second = plan_release_lock(tmp_path, content, 15)
    assert second.proposed == first.proposed and second.sha256 != first.sha256
    assert second.manifest_sha256 != first.manifest_sha256
    assert second.evidence_sha256 != first.evidence_sha256
    evidence_path = tmp_path / "content-evidence/pl.json"
    evidence = json.loads(evidence_path.read_bytes())
    evidence["tiers_sha256"] = "1" * 64
    evidence_path.write_bytes(canonical_bytes(evidence))
    third = plan_release_lock(tmp_path, content, 15)
    assert third.manifest_sha256 == second.manifest_sha256
    assert third.sha256 != second.sha256
    schema = tmp_path / "schema/level.schema.json"
    data = json.loads(schema.read_bytes())
    data["description"] += " Fixture context change."
    schema.write_bytes(canonical_bytes(data))
    fourth = plan_release_lock(tmp_path, content, 15)
    assert fourth.sha256 != third.sha256 and fourth.validation_sha256 != third.validation_sha256
    # A current config change without new matching evidence is rejected, not certified.
    config_path = tmp_path / "config/pl.yaml"
    data = json.loads(config_path.read_bytes())
    data["min_length"] = 4
    config_path.write_bytes(canonical_bytes(data))
    with pytest.raises(ValueError):
        plan_release_lock(tmp_path, content, 15)


@pytest.mark.parametrize(
    "kind", ["content", "evidence", "unsafe_evidence", "bad_lock", "unsafe_lock", "bonus"]
)
def test_missing_stale_or_unsafe_inputs_never_prepare_or_write(tmp_path, kind):
    _config, content = setup(tmp_path)
    evidence = tmp_path / "content-evidence/pl.json"
    if kind == "content":
        shutil.rmtree(content)
    elif kind == "evidence":
        evidence.unlink()
    elif kind == "unsafe_evidence":
        evidence.unlink()
        os.mkfifo(evidence)
    elif kind in ("bad_lock", "unsafe_lock"):
        path = tmp_path / "locks/pl.lock.json"
        path.parent.mkdir()
        if kind == "bad_lock":
            path.write_text("{}")
        else:
            path.symlink_to(tmp_path / "absent")
    else:
        data = json.loads(evidence.read_bytes())
        data["records"] = [{"word": "AAA", "tier": "invalid"}]
        evidence.write_bytes(canonical_bytes(data))
    # Snapshot only regular, nonlinked files so FIFO safety is actually exercised.
    before = {p: p.read_bytes() for p in tmp_path.rglob("*") if p.is_file() and not p.is_symlink()}
    with pytest.raises((OSError, ValueError)):
        plan_release_lock(tmp_path, content, 15)
    assert before == {p: p.read_bytes() for p in before}


def test_changed_inputs_during_validation_and_protected_geometry_rejected(tmp_path, monkeypatch):
    import wordgame_pipeline.release_plan as module

    config, content = setup(tmp_path)
    actual = module.validate_content
    evidence = tmp_path / "content-evidence/pl.json"

    def changed(*args, **kwargs):
        result = actual(*args, **kwargs)
        data = json.loads(evidence.read_bytes())
        data["tiers_sha256"] = "2" * 64
        evidence.write_bytes(canonical_bytes(data))
        return result

    monkeypatch.setattr(module, "validate_content", changed)
    with pytest.raises(ValueError, match="inputs changed"):
        plan_release_lock(tmp_path, content, 15)
    monkeypatch.setattr(module, "validate_content", actual)
    validate_content(tmp_path, config, content, prepare=True)
    proposal = plan_release_lock(tmp_path, content, 15)
    path = tmp_path / "locks/pl.lock.json"
    path.parent.mkdir()
    lock = proposal.proposed.to_dict()
    lock["levels"][0]["geometry_sha256"] = "0" * 64
    path.write_bytes(canonical_bytes(lock))
    with pytest.raises(ValueError, match="Released geometry changed"):
        plan_release_lock(tmp_path, content, 20)


def test_bad_direct_constructors_and_cutoffs(tmp_path):
    _config, content = setup(tmp_path)
    plan = plan_release_lock(tmp_path, content, 15)
    original = copy.deepcopy(plan)
    for update in (
        dict(previous={}),
        dict(proposed=None),
        dict(campaign_slots=True),
        dict(campaign_slots=14),
        dict(manifest_sha256="A" * 64),
        dict(evidence_sha256="short"),
        dict(validation_sha256=None),
    ):
        with pytest.raises(ValueError):
            replace(plan, **update)
    longer = plan_release_lock(tmp_path, content, 20)
    with pytest.raises(ValueError):
        replace(plan, previous=longer.proposed)
    for cutoff in (True, 0, 31):
        with pytest.raises(ValueError):
            plan_release_lock(tmp_path, content, cutoff)
    assert plan == original
