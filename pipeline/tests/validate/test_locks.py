"""Release locks protect exact geometry, independently of content approval."""

import copy
import hashlib
import json
import os
from dataclasses import FrozenInstanceError, replace
from pathlib import Path

import pytest
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.validate.locks import (
    LockedSlot,
    ReleaseLock,
    geometry_sha256,
    load_release_lock,
    verify_release_lock,
)

ROOT = Path(__file__).resolve().parents[2]


def campaign():
    path = next((ROOT.parent / "game/content/pl/packs").glob("*.json"))
    return json.loads(path.read_bytes())["levels"]


def lock_for(levels):
    return ReleaseLock(
        "pl", tuple(LockedSlot(e["slot"], e["id"], geometry_sha256(e)) for e in levels)
    )


def test_hash_projection_order_and_allowed_changes():
    level = next(
        e
        for e in campaign()
        if len(e["words"]) > 1 and e["letters"] != list(reversed(e["letters"]))
    )
    before = copy.deepcopy(level)
    expected = hashlib.sha256(
        canonical_bytes({k: level[k] for k in ("letters", "words", "grid")})
    ).hexdigest()
    assert geometry_sha256(level) == expected
    assert geometry_sha256(json.loads(json.dumps(level, sort_keys=True))) == expected
    for change in (dict(bonus=[]), dict(difficulty=0.75), dict(seed=999), dict(pipeline="2.0.0")):
        assert geometry_sha256({**level, **change}) == expected
    for field in ("letters", "words", "grid", "coordinates"):
        changed = copy.deepcopy(level)
        if field == "letters":
            changed["letters"].reverse()
        elif field == "words":
            changed["words"].reverse()
        elif field == "grid":
            changed["grid"]["h"] = 10 if level["grid"]["h"] != 10 else 9
        else:
            changed["words"][0]["x"] = (changed["words"][0]["x"] + 1) % 10
        assert geometry_sha256(changed) != expected
    assert level == before


def test_roundtrip_immutable_and_complete_verification():
    levels = campaign()
    lock = lock_for(levels[:15])
    before = copy.deepcopy(levels)
    assert ReleaseLock.from_dict(lock.to_dict()) == lock
    lock.to_dict()["levels"].clear()
    assert len(lock.levels) == 15
    with pytest.raises(FrozenInstanceError):
        lock.lang = "en"
    with pytest.raises(FrozenInstanceError):
        lock.levels[0].id = "changed"
    verify_release_lock(lock, levels)
    verify_release_lock(lock, tuple(levels[:15]))
    levels[0].update(bonus=[], difficulty=1, seed=42, pipeline="2.0.0")
    verify_release_lock(lock, levels)
    assert before[0]["seed"] != 42
    for invalid in (
        levels[:14],
        list(reversed(levels)),
        [levels[0], *levels],
        levels[:-1] + [None],
    ):
        with pytest.raises(ValueError):
            verify_release_lock(lock, invalid)
    levels[0]["grid"]["h"] = 10
    with pytest.raises(ValueError, match="slot 1"):
        verify_release_lock(lock, levels)
    with pytest.raises(ValueError):
        verify_release_lock(None, before)
    with pytest.raises(ValueError):
        verify_release_lock(lock, iter(before))


@pytest.mark.parametrize(
    "change",
    [
        dict(slot=True),
        dict(slot=10000),
        dict(id="pl-c-000002"),
        dict(geometry_sha256="A" * 64),
        dict(geometry_sha256="0" * 63),
    ],
)
def test_bad_slot_constructors(change):
    with pytest.raises(ValueError):
        replace(lock_for(campaign()[:1]).levels[0], **change)


@pytest.mark.parametrize(
    "change", [dict(lang="en"), dict(levels=[]), dict(levels=()), dict(levels=(None,))]
)
def test_bad_lock_constructors(change):
    with pytest.raises(ValueError):
        replace(lock_for(campaign()[:1]), **change)


def test_bad_lock_fields_prefix_json_and_projection():
    data = lock_for(campaign()[:2]).to_dict()
    for value in (
        None,
        {**data, "extra": 1},
        {**data, "schema_version": True},
        {**data, "levels": data["levels"][1:]},
        {**data, "levels": data["levels"] * 2},
        {**data, "levels": [{**data["levels"][0], "extra": 0}]},
    ):
        with pytest.raises(ValueError):
            ReleaseLock.from_dict(value)
    level = campaign()[0]
    for change in (
        dict(slot=False),
        dict(id="pl-d-000001"),
        dict(letters=[]),
        dict(words=[]),
        dict(grid={"w": True, "h": 1}),
        dict(words=[{"w": "KOT", "x": True, "y": 0, "dir": "v"}]),
        dict(difficulty=float("nan")),
    ):
        with pytest.raises(ValueError):
            geometry_sha256({**level, **change})


def test_safe_loader_readonly_and_malformed_files(tmp_path):
    assert load_release_lock(tmp_path, "pl") is None
    path = tmp_path / "locks/pl.lock.json"
    path.parent.mkdir()
    lock = lock_for(campaign()[:15])
    raw = canonical_bytes(lock.to_dict())
    path.write_bytes(raw)
    stamp = path.stat().st_mtime_ns
    assert load_release_lock(tmp_path, "pl") == lock
    assert path.read_bytes() == raw and path.stat().st_mtime_ns == stamp
    for invalid in ("", "{}", '{"lang":"pl","lang":"pl"}', '{"levels":NaN}', '{"levels":1e999}'):
        path.write_text(invalid)
        with pytest.raises(ValueError):
            load_release_lock(tmp_path, "pl")
        assert path.read_text() == invalid
    with pytest.raises(ValueError):
        load_release_lock(tmp_path, "../pl")


@pytest.mark.parametrize(
    "kind", ["symlink", "dangling", "parent_link", "parent_file", "fifo", "directory"]
)
def test_loader_path_safety(tmp_path, kind):
    path = tmp_path / "locks/pl.lock.json"
    target = tmp_path / "target"
    target.mkdir()
    if kind == "parent_link":
        path.parent.symlink_to(target, target_is_directory=True)
    elif kind == "parent_file":
        path.parent.write_text("keep")
    else:
        path.parent.mkdir()
        if kind in ("symlink", "dangling"):
            path.symlink_to(target / "file")
            if kind == "symlink":
                (target / "file").write_text("keep")
        elif kind == "fifo":
            os.mkfifo(path)
        else:
            path.mkdir()
    with pytest.raises(ValueError):
        load_release_lock(tmp_path, "pl")


@pytest.mark.parametrize("kind", ["fifo", "file_symlink", "parent_symlink"])
def test_loader_replacement_races_fail_before_read(tmp_path, monkeypatch, kind):
    import wordgame_pipeline.filesystem as module

    path = tmp_path / "locks/pl.lock.json"
    path.parent.mkdir()
    path.write_bytes(canonical_bytes(lock_for(campaign()[:1]).to_dict()))
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / path.name).write_text("must not read")
    original = module.os.open
    replaced = False

    def race(name, flags, *args, **kwargs):
        nonlocal replaced
        trigger = "locks" if kind == "parent_symlink" else path.name
        if name == trigger and not replaced:
            replaced = True
            if kind == "parent_symlink":
                path.parent.rename(tmp_path / "old-locks")
                path.parent.symlink_to(outside, target_is_directory=True)
            else:
                path.unlink()
                if kind == "fifo":
                    os.mkfifo(path)
                else:
                    path.symlink_to(outside / path.name)
        return original(name, flags, *args, **kwargs)

    monkeypatch.setattr(module.os, "open", race)
    with pytest.raises(ValueError):
        load_release_lock(tmp_path, "pl")
    assert replaced and (outside / path.name).read_text() == "must not read"
