"""End-to-end P2 checks on the exact unchanged shipped P1 campaign fixture."""

import copy
import json
from pathlib import Path

import pytest
from wordgame_pipeline.candidates.core import WordIndex
from wordgame_pipeline.config import load_config
from wordgame_pipeline.dedupe import DuplicatePolicy
from wordgame_pipeline.sequence.curve import CurveConfig
from wordgame_pipeline.sequence.slots import Location, Region, Reservation, SlotPlan
from wordgame_pipeline.validate.locks import extend_release_lock
from wordgame_pipeline.validate.p2_campaign import validate_p2_campaign
from wordgame_pipeline.validate.schema import SchemaRegistry

ROOT = Path(__file__).parents[2]
LANGUAGE = load_config(ROOT, "pl")
TOKENS = ROOT.parent / "game/ui/tokens.gd"


def data():
    path = ROOT.parent / "game/content/pl/packs/c-0001-0065.json"
    levels = json.loads(path.read_bytes())["levels"]
    index = WordIndex(json.loads((ROOT / "content-evidence/pl.json").read_bytes())["records"], LANGUAGE)
    plan = SlotPlan(
        (Region("r1", CurveConfig(1, 65, 0, 0, 5, 0, 0.2, 0.1, ())),),
        (Location("loc1", "r1", 1, 33), Location("loc2", "r1", 34, 65)),
        tuple(Reservation(i, f"c{i}") for i in range(1, 66)),
        (),
    )
    seeds = {row["slot"]: row["words"][0]["w"] for row in levels}
    return levels, index, plan, seeds


def check(levels, index, plan, seeds, *, lock=None, strict=False, area=1000):
    return validate_p2_campaign(
        levels,
        index,
        SchemaRegistry(ROOT),
        LANGUAGE,
        plan,
        seeds,
        DuplicatePolicy(1, 100),
        tokens_path=TOKENS,
        compact_area_width=area,
        compact_area_height=area,
        compact_body_height=area,
        max_deviation=1.0,
        lock=lock,
        require_lock=strict,
    )


def test_unmodified_65_slot_fixture_passes_only_nonrelease_validation():
    levels, index, plan, seeds = data()
    original = copy.deepcopy(levels)
    check(levels, index, plan, seeds)
    assert levels == original
    with pytest.raises(ValueError, match="requires an explicit"):
        check(levels, index, plan, seeds, strict=True)


def test_release_lock_blocks_changed_crossword_but_allows_bonus_only_repair():
    levels, index, plan, seeds = data()
    lock = extend_release_lock(None, levels, 15)
    check(levels, index, plan, seeds, lock=lock, strict=True)
    repaired = copy.deepcopy(levels)
    repaired[0]["bonus"] = list(reversed(repaired[0]["bonus"]))
    # Canonical bonus validation still requires sorted order, so this input
    # exercises semantic validation before the lock is considered.
    with pytest.raises(ValueError):
        check(repaired, index, plan, seeds, lock=lock, strict=True)
    changed = copy.deepcopy(levels)
    changed[0]["letters"] = ["T", "K", "O"]
    with pytest.raises(ValueError, match="Released geometry changed"):
        check(changed, index, plan, seeds, lock=lock, strict=True)


def test_real_compact_dimensions_must_fit_and_not_be_guessed():
    levels, index, plan, seeds = data()
    with pytest.raises(ValueError, match="CELL_MIN"):
        check(levels, index, plan, seeds, area=1)


def test_repetition_and_incomplete_campaign_rejected():
    levels, index, plan, seeds = data()
    with pytest.raises(ValueError, match="order"):
        check(levels[:-1], index, plan, seeds)
    duplicate = copy.deepcopy(levels)
    duplicate[1]["letters"] = duplicate[0]["letters"]
    duplicate[1]["words"] = duplicate[0]["words"]
    duplicate[1]["grid"] = duplicate[0]["grid"]
    duplicate[1]["bonus"] = duplicate[0]["bonus"]
    duplicate[1]["seed"] = duplicate[0]["seed"]
    with pytest.raises(ValueError):
        check(duplicate, index, plan, seeds)
