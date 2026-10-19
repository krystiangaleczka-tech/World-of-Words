"""Both export artifacts and actual publication enforce the pipeline-root lock."""

import copy
import hashlib
import json
import os
import runpy
import shutil
from pathlib import Path

import pytest
from wordgame_pipeline.candidates.handmade import load_handmade
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.export import assemble, handlers_for
from wordgame_pipeline.export.publish import publish
from wordgame_pipeline.stages import P1_STAGES, artifact_path, read_artifact, run_build
from wordgame_pipeline.validate import SchemaRegistry
from wordgame_pipeline.validate import handlers_for as validation_handlers
from wordgame_pipeline.validate.locks import LockedSlot, ReleaseLock, geometry_sha256

ROOT = Path(__file__).resolve().parents[2]
fixture = runpy.run_path(str(ROOT / "tests/export/test_export.py"))["fixture"]
workspace = runpy.run_path(str(ROOT / "tests/test_content.py"))["workspace"]


def levels(payload):
    return [
        e
        for entry in payload["files"]["manifest.json"]["packs"]
        for e in payload["files"][entry["file"]]["levels"]
    ]


def write_lock(root, payload, count=15):
    lock = ReleaseLock(
        "pl",
        tuple(LockedSlot(e["slot"], e["id"], geometry_sha256(e)) for e in levels(payload)[:count]),
    )
    path = root / "locks/pl.lock.json"
    path.parent.mkdir(exist_ok=True)
    path.write_bytes(canonical_bytes(lock.to_dict()))
    return path


def snapshot(root):
    return {
        p.relative_to(root).as_posix(): (p.read_bytes(), p.stat().st_mtime_ns)
        for p in root.rglob("*")
        if p.is_file() and not p.is_symlink()
    }


def refresh_hashes(payload):
    for entry in payload["files"]["manifest.json"]["packs"]:
        entry["sha256"] = hashlib.sha256(
            canonical_bytes(payload["files"][entry["file"]])
        ).hexdigest()


def publisher_fixture(root):
    shutil.copytree(ROOT / "schema", root / "schema")
    previous, index, _registry = fixture(31)
    registry = SchemaRegistry(root)
    payload = assemble(previous, 30, 1, index, registry)
    return previous, index, registry, payload


@pytest.mark.parametrize("kind", ["geometry", "reorder", "missing"])
def test_direct_publish_rejects_without_any_writes(tmp_path, kind):
    previous, index, registry, payload = publisher_fixture(tmp_path)
    write_lock(tmp_path, payload, count=30)
    output = tmp_path / "output/pl"
    publish(payload, output, registry)
    changed = assemble(previous, 29 if kind == "missing" else 30, 2, index, registry)
    if kind == "geometry":
        levels(changed)[1]["letters"].reverse()
    elif kind == "reorder":
        pack = next(v for v in changed["files"].values() if "levels" in v)
        pack["levels"][:2] = reversed(pack["levels"][:2])
    refresh_hashes(changed)
    before = snapshot(tmp_path)
    for check in (False, True):
        with pytest.raises(ValueError, match="Released"):
            publish(changed, output, registry, check=check)
        with pytest.raises(ValueError, match="Released"):
            publish(changed, tmp_path / "not-created/pl", registry, check=check)
        assert snapshot(tmp_path) == before
        assert not (tmp_path / "not-created").exists()
    assert sorted(p.name for p in output.parent.iterdir()) == ["pl"]


def test_valid_append_seed_repair_versions_and_readonly_check(tmp_path):
    previous, index, registry, payload = publisher_fixture(tmp_path)
    lock = write_lock(tmp_path, payload)
    raw = lock.read_bytes()
    output = tmp_path / "pl"
    publish(payload, output, registry, require_lock=True)
    before = snapshot(tmp_path)
    publish(payload, output, registry)
    publish(payload, output, registry, check=True, require_lock=True)
    assert snapshot(tmp_path) == before
    changed = assemble(previous, 31, 2, index, registry)
    levels(changed)[0]["seed"] += 100
    refresh_hashes(changed)
    publish(changed, output, registry, require_lock=True)
    publish(changed, output, registry, check=True)
    assert lock.read_bytes() == raw
    with pytest.raises(ValueError, match="version"):
        publish(assemble(previous, 30, 4, index, registry), output, registry)


def test_registry_root_stable_and_publication_reloads_lock(tmp_path, monkeypatch):
    _previous, _index, _registry, payload = publisher_fixture(tmp_path)
    monkeypatch.chdir(tmp_path.parent)
    registry = SchemaRegistry(Path(tmp_path.name))
    output = tmp_path / "out/pl"
    publish(payload, output, registry)
    # A lock created after assembly/registry construction must still gate publication.
    altered = copy.deepcopy(payload)
    levels(altered)[1]["letters"].reverse()
    write_lock(tmp_path, altered)
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    monkeypatch.chdir(elsewhere)
    before = snapshot(tmp_path)
    assert registry.root == tmp_path.absolute()
    for check in (False, True):
        with pytest.raises(ValueError, match="Released geometry changed"):
            publish(payload, output, registry, check=check)
    assert snapshot(tmp_path) == before


@pytest.mark.parametrize("kind", ["absent", "malformed", "symlink", "fifo"])
def test_direct_strict_and_unsafe_locks(tmp_path, kind):
    _previous, _index, registry, payload = publisher_fixture(tmp_path)
    path = tmp_path / "locks/pl.lock.json"
    path.parent.mkdir()
    if kind == "malformed":
        path.write_text("{}")
    elif kind == "symlink":
        path.symlink_to(tmp_path / "missing")
    elif kind == "fifo":
        os.mkfifo(path)
    before = snapshot(tmp_path)
    for check in (False, True):
        with pytest.raises(ValueError):
            publish(
                payload, tmp_path / "out/pl", registry, check=check, require_lock=kind == "absent"
            )
    assert snapshot(tmp_path) == before and not (tmp_path / "out").exists()
    with pytest.raises(ValueError, match="must be bool"):
        publish(payload, tmp_path / "out/pl", registry, require_lock=1)


def export_workspace(root):
    config, content = workspace(root)
    previous, index, _registry = fixture(30)
    tiers, _raw = read_artifact(root, config, next(s for s in P1_STAGES if s.name == "tiers"))
    previous.update({k: v for k, v in tiers.items() if k != "records"})
    previous["handmade_sha256"] = load_handmade(root, index)[1]
    run_build(
        root,
        config,
        {name: lambda _c, _p: previous for name in ("candidates", "grid")},
        "candidates",
        "grid",
    )
    run_build(root, config, validation_handlers(root), "validate", "validate")
    args = [
        "build",
        "--root",
        str(root),
        "--lang",
        "pl",
        "--from",
        "export",
        "--to",
        "export",
        "--slots",
        "30",
        "--content-version",
        "1",
        "--output",
        str(content / "pl"),
    ]
    return config, content, previous, index, args


def test_cli_and_handler_protect_existing_artifact_custom_output_and_strict_flag(tmp_path, capsys):
    config, _content, previous, index, args = export_workspace(tmp_path)
    assert main(args) == 0  # Optional absent lock retains P1 export.
    capsys.readouterr()
    payload, _raw = read_artifact(tmp_path, config, P1_STAGES[-1])
    lock = write_lock(tmp_path, payload)
    assert main([*args, "--require-release-lock"]) == 0
    capsys.readouterr()
    before = snapshot(tmp_path)
    assert main([*args, "--check", "--require-release-lock"]) == 0
    capsys.readouterr()
    assert snapshot(tmp_path) == before
    # A different, valid authored wheel ordering passes P1 validation but violates release geometry.
    previous["handmade"][1]["letters"].reverse()
    authored = tmp_path / "handmade/pl/opening.yaml"
    entries = json.loads(authored.read_text())
    entries[1]["letters"].reverse()
    authored.write_text(json.dumps(entries))
    previous["handmade_sha256"] = load_handmade(tmp_path, index)[1]
    run_build(tmp_path, config, {"grid": lambda _c, _p: previous}, "grid", "grid")
    run_build(tmp_path, config, validation_handlers(tmp_path), "validate", "validate")
    before = snapshot(tmp_path)
    validated, _raw = read_artifact(tmp_path, config, P1_STAGES[-2])
    with pytest.raises(ValueError, match="Released geometry changed at slot 2"):
        handlers_for(tmp_path, 30, 2)["export"](config, validated)
    changed_args = list(args)
    changed_args[changed_args.index("--content-version") + 1] = "2"
    for options in ([], ["--check"], ["--output", str(tmp_path / "other/pl")]):
        assert main([*changed_args, *options]) == 1
        assert "Released geometry changed at slot 2" in capsys.readouterr().err
        assert snapshot(tmp_path) == before
    assert not (tmp_path / "other").exists()
    lock.unlink()
    assert main(changed_args) == 0  # Shows that independent P1 gates accept the revised intent.


def test_strict_cli_absence_and_plan_do_not_write(tmp_path, capsys):
    config, _content, _previous, _index, args = export_workspace(tmp_path)
    before = snapshot(tmp_path)
    for options in ([], ["--check"]):
        assert main([*args, *options, "--require-release-lock"]) == 1
        assert "lock required" in capsys.readouterr().err
        assert snapshot(tmp_path) == before
    path = tmp_path / "locks/pl.lock.json"
    path.parent.mkdir()
    path.write_text("malformed")
    before = snapshot(tmp_path)
    assert main([*args, "--plan", "--require-release-lock"]) == 0
    assert "13-export" in capsys.readouterr().out
    assert snapshot(tmp_path) == before
    nonexport = [
        "build",
        "--root",
        str(tmp_path),
        "--lang",
        "pl",
        "--to",
        "validate",
        "--require-release-lock",
    ]
    assert main(nonexport) == 1
    assert "requires export selection" in capsys.readouterr().err
    assert not artifact_path(tmp_path, config.lang, P1_STAGES[-1]).exists()
    with pytest.raises(ValueError, match="must be bool"):
        handlers_for(tmp_path, 30, 1, require_lock=1)["export"](config, None)
