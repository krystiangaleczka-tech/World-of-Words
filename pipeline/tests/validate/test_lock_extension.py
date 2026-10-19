"""In-memory release proposals never rewrite an existing prefix."""

import copy
import json
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.validate.locks import (
    ReleaseLock,
    extend_release_lock,
    geometry_sha256,
    verify_release_lock,
)

ROOT = Path(__file__).resolve().parents[2]


def campaign():
    path = next((ROOT.parent / "game/content/pl/packs").glob("*.json"))
    return json.loads(path.read_bytes())["levels"]


def test_initial_prefix_extension_noop_and_immutable_entries():
    levels = campaign()
    before = copy.deepcopy(levels)
    first = extend_release_lock(None, levels, 15)
    assert len(first.levels) == 15
    assert first.levels[0].geometry_sha256 == geometry_sha256(levels[0])
    expanded = extend_release_lock(first, tuple(levels), 30)
    assert expanded.levels[:15] == first.levels
    assert all(a is b for a, b in zip(expanded.levels, first.levels, strict=False))
    assert len(expanded.levels) == 30
    assert extend_release_lock(expanded, levels, 30) == expanded
    assert extend_release_lock(None, copy.deepcopy(levels), 30) == expanded
    assert ReleaseLock.from_dict(expanded.to_dict()) == expanded
    verify_release_lock(expanded, levels)
    assert levels == before
    with pytest.raises(FrozenInstanceError):
        expanded.levels = ()


def test_allowed_metadata_keeps_old_entries_but_changed_geometry_never_rebaselines():
    levels = campaign()
    previous = extend_release_lock(None, levels, 15)
    for level in levels[:15]:
        level.update(bonus=[], difficulty=0.5, seed=999, pipeline="2.0.0")
    assert extend_release_lock(previous, levels, 20).levels[:15] == previous.levels
    levels[1]["letters"].reverse()
    assert levels[1]["letters"] != campaign()[1]["letters"]
    before = copy.deepcopy(levels)
    for cutoff in (15, 20):
        with pytest.raises(ValueError, match="Released geometry changed at slot 2"):
            extend_release_lock(previous, levels, cutoff)
    assert levels == before


@pytest.mark.parametrize("cutoff", [True, False, 0, -1, 10000, 2**53, 1.5, "15", None, 66])
def test_invalid_cutoffs(cutoff):
    with pytest.raises(ValueError):
        extend_release_lock(None, campaign(), cutoff)


def test_shrink_missing_reorder_and_full_unlocked_tail_validation():
    levels = campaign()
    previous = extend_release_lock(None, levels, 30)
    for bad, cutoff in (
        (levels, 29),
        (levels[:15], 15),
        (list(reversed(levels)), 30),
        (levels + [None], 30),
    ):
        with pytest.raises(ValueError):
            extend_release_lock(previous, bad, cutoff)
    with pytest.raises(ValueError):
        extend_release_lock(None, levels[:-1] + [None], 1)
    with pytest.raises(ValueError):
        extend_release_lock({}, levels, 15)
    with pytest.raises(ValueError):
        extend_release_lock(None, iter(levels), 15)
    with pytest.raises(ValueError):
        extend_release_lock(None, [], 1)
    changed = copy.deepcopy(levels)
    changed[0]["id"] = "pl-c-000099"
    with pytest.raises(ValueError):
        extend_release_lock(None, changed, 1)
