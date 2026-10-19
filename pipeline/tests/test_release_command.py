"""Actual campaign is untouched; every write below targets a temporary fixture."""

import fcntl
import hashlib
import json
import os
import runpy
from contextlib import contextmanager
from pathlib import Path

import pytest
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.content import validate_content
from wordgame_pipeline.filesystem import directory_fd
from wordgame_pipeline.release_apply import apply_release_lock
from wordgame_pipeline.release_plan import plan_release_lock
from wordgame_pipeline.validate.locks import load_release_lock

ROOT = Path(__file__).resolve().parents[1]
workspace = runpy.run_path(str(ROOT / "tests/test_content.py"))["workspace"]


def setup(root):
    config, content = workspace(root)
    validate_content(root, config, content, prepare=True)
    return config, content


def snapshot(root):
    return {
        p: (p.read_bytes(), p.stat().st_mtime_ns)
        for p in root.rglob("*")
        if p.is_file() and not p.is_symlink()
    }


def args(root, content, cutoff=15):
    return [
        "release-lock",
        "--root",
        str(root),
        "--content-root",
        str(content),
        "--released-through",
        str(cutoff),
    ]


def apply(root, content, cutoff=15):
    plan = plan_release_lock(root, content, cutoff)
    return apply_release_lock(root, content, cutoff, expected_sha256=plan.sha256, approved=True)


def test_cli_readonly_initial_extension_noop_and_existing_validation(tmp_path, capsys):
    config, content = setup(tmp_path)
    before = snapshot(tmp_path)
    assert main(args(tmp_path, content)) == 0
    captured = capsys.readouterr()
    report = json.loads(captured.out)
    assert not captured.err and captured.out.encode() == canonical_bytes(report)
    assert report["status"] == "proposal"
    assert snapshot(tmp_path) == before and not (tmp_path / "locks").exists()
    approved_args = [
        *args(tmp_path, content),
        "--apply",
        "--expected-plan-sha256",
        report["plan_sha256"],
    ]
    assert main(approved_args) == 0
    assert json.loads(capsys.readouterr().out)["status"] == "written"
    path = tmp_path / "locks/pl.lock.json"
    first = load_release_lock(tmp_path, "pl")
    assert len(first.levels) == 15
    assert path.read_bytes() == canonical_bytes(first.to_dict())
    assert {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in before} == before
    assert validate_content(tmp_path, config, content, require_lock=True) == 30
    extension, changed = apply(tmp_path, content, 20)
    assert changed and extension.proposed.levels[:15] == first.levels
    assert len(load_release_lock(tmp_path, "pl").levels) == 20
    assert main(args(tmp_path, content, 20)) == 0
    noop = json.loads(capsys.readouterr().out)
    before = snapshot(tmp_path)
    assert (
        main(
            [*args(tmp_path, content, 20), "--apply", "--expected-plan-sha256", noop["plan_sha256"]]
        )
        == 0
    )
    assert json.loads(capsys.readouterr().out)["status"] == "unchanged"
    assert snapshot(tmp_path) == before
    assert sorted(p.name for p in path.parent.iterdir()) == ["pl.lock.json"]


@pytest.mark.parametrize(
    "kind", ["unapproved", "bad_hash", "stale", "missing_cli_hash", "hash_without_apply"]
)
def test_explicit_intent_and_reviewed_hash_required_before_writes(tmp_path, capsys, kind):
    _config, content = setup(tmp_path)
    plan = plan_release_lock(tmp_path, content, 15)
    before = snapshot(tmp_path)
    if kind in ("unapproved", "bad_hash", "stale"):
        with pytest.raises(ValueError):
            apply_release_lock(
                tmp_path,
                content,
                15,
                expected_sha256="bad"
                if kind == "bad_hash"
                else "0" * 64
                if kind == "stale"
                else plan.sha256,
                approved=kind != "unapproved",
            )
    else:
        options = (
            ["--apply"] if kind == "missing_cli_hash" else ["--expected-plan-sha256", plan.sha256]
        )
        assert main([*args(tmp_path, content), *options]) == 1
        captured = capsys.readouterr()
        assert not captured.out and captured.err
    assert snapshot(tmp_path) == before and not (tmp_path / "locks").exists()


@pytest.mark.parametrize("kind", ["evidence", "baseline", "content"])
def test_changed_inputs_reject_old_review_identity(tmp_path, kind):
    _config, content = setup(tmp_path)
    reviewed = plan_release_lock(tmp_path, content, 15)
    if kind == "evidence":
        path = tmp_path / "content-evidence/pl.json"
        data = json.loads(path.read_bytes())
        data["tiers_sha256"] = "3" * 64
        path.write_bytes(canonical_bytes(data))
    elif kind == "content":
        path = content / "pl/manifest.json"
        manifest = json.loads(path.read_bytes())
        pack_path = content / "pl" / manifest["packs"][0]["file"]
        pack = json.loads(pack_path.read_bytes())
        pack["levels"][-1]["seed"] += 1
        pack_path.write_bytes(canonical_bytes(pack))
        manifest["packs"][0]["sha256"] = hashlib.sha256(pack_path.read_bytes()).hexdigest()
        path.write_bytes(canonical_bytes(manifest))
        validate_content(tmp_path, _config, content, prepare=True)
    else:
        apply(tmp_path, content, 10)
    before = snapshot(tmp_path)
    with pytest.raises(ValueError, match="proposal changed"):
        apply_release_lock(tmp_path, content, 15, expected_sha256=reviewed.sha256, approved=True)
    assert snapshot(tmp_path) == before


def test_cooperating_writer_mutex_is_nonblocking(tmp_path):
    _config, content = setup(tmp_path)
    plan = plan_release_lock(tmp_path, content, 15)
    path = tmp_path / "locks"
    path.mkdir()
    with directory_fd(path) as directory:
        fcntl.flock(directory, fcntl.LOCK_EX | fcntl.LOCK_NB)
        with pytest.raises(ValueError, match="already in progress"):
            apply_release_lock(tmp_path, content, 15, expected_sha256=plan.sha256, approved=True)
    assert list(path.iterdir()) == []
    assert apply(tmp_path, content)[1]  # Mutex is usable again after the holder closes.


@pytest.mark.parametrize("operation", ["write", "fsync", "replace"])
def test_write_failures_preserve_baseline_and_clean_owned_temporary(
    tmp_path, monkeypatch, operation
):
    import wordgame_pipeline.release_apply as module

    _config, content = setup(tmp_path)
    apply(tmp_path, content)
    plan = plan_release_lock(tmp_path, content, 20)
    before = snapshot(tmp_path)

    def fail(*_args, **_kwargs):
        raise OSError("injected release write failure")

    if operation == "write":
        actual = module.os.fdopen

        class BrokenStream:
            def write(self, _data):
                raise OSError("injected release write failure")

        @contextmanager
        def writer_failure(descriptor, mode="r", **kwargs):
            with actual(descriptor, mode, **kwargs) as stream:
                yield BrokenStream() if mode == "wb" else stream

        monkeypatch.setattr(module.os, "fdopen", writer_failure)
    else:
        monkeypatch.setattr(module.os, operation, fail)
    with pytest.raises((ValueError, OSError), match="Release|injected"):
        apply_release_lock(tmp_path, content, 20, expected_sha256=plan.sha256, approved=True)
    assert snapshot(tmp_path) == before
    assert sorted(p.name for p in (tmp_path / "locks").iterdir()) == ["pl.lock.json"]


def test_temp_collision_does_not_delete_unowned_file(tmp_path, monkeypatch):
    import wordgame_pipeline.release_apply as module

    _config, content = setup(tmp_path)
    apply(tmp_path, content)
    plan = plan_release_lock(tmp_path, content, 20)
    other = tmp_path / "locks/.pl.lock-collision.tmp"
    other.write_text("keep")
    before = snapshot(tmp_path)
    monkeypatch.setattr(module.secrets, "token_hex", lambda _n: "collision")
    with pytest.raises(ValueError):
        apply_release_lock(tmp_path, content, 20, expected_sha256=plan.sha256, approved=True)
    assert other.read_text() == "keep" and snapshot(tmp_path) == before


@pytest.mark.parametrize("kind", ["symlink", "fifo", "protected_geometry"])
def test_unsafe_or_changed_baseline_never_replaced(tmp_path, kind):
    _config, content = setup(tmp_path)
    plan = plan_release_lock(tmp_path, content, 15)
    path = tmp_path / "locks/pl.lock.json"
    path.parent.mkdir()
    if kind == "symlink":
        path.symlink_to(tmp_path / "absent")
    elif kind == "fifo":
        os.mkfifo(path)
    else:
        data = plan.proposed.to_dict()
        data["levels"][0]["geometry_sha256"] = "0" * 64
        path.write_bytes(canonical_bytes(data))
    before = snapshot(tmp_path)
    with pytest.raises(ValueError):
        apply_release_lock(tmp_path, content, 15, expected_sha256=plan.sha256, approved=True)
    assert snapshot(tmp_path) == before
    assert list(path.parent.iterdir()) == [path]


def test_last_revalidation_rejects_change_after_temporary_write(tmp_path, monkeypatch):
    import wordgame_pipeline.release_apply as module

    _config, content = setup(tmp_path)
    apply(tmp_path, content)
    plan = plan_release_lock(tmp_path, content, 20)
    baseline = tmp_path / "locks/pl.lock.json"
    before = baseline.read_bytes()
    actual = module.os.fsync

    def changed(descriptor):
        actual(descriptor)
        path = tmp_path / "content-evidence/pl.json"
        data = json.loads(path.read_bytes())
        data["tiers_sha256"] = "4" * 64
        path.write_bytes(canonical_bytes(data))

    monkeypatch.setattr(module.os, "fsync", changed)
    with pytest.raises(ValueError, match="proposal changed"):
        apply_release_lock(tmp_path, content, 20, expected_sha256=plan.sha256, approved=True)
    assert baseline.read_bytes() == before
    assert sorted(p.name for p in baseline.parent.iterdir()) == ["pl.lock.json"]
