"""T-0306: validate proposed Polish 200-slot inventory through native source/grid rules."""

import copy
import hashlib
import json
from pathlib import Path

import pytest
from wordgame_pipeline.candidates.core import WordIndex
from wordgame_pipeline.config import load_config
from wordgame_pipeline.grid import make_level

PIPELINE = Path(__file__).resolve().parents[2]
REPO = PIPELINE.parent
PROPOSAL = PIPELINE / "reviews/pl/T-0306-200-level-candidates.json"
COMPACT = PIPELINE / "content-inputs/pl.json"
BASE = REPO / "game/content/pl/packs/c-0001-0065.json"
LEXICAL = PIPELINE / "reviews/pl/T-0129-words.csv"


def _git_blob_sha1(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def _inputs() -> tuple[dict, list, WordIndex, object]:
    proposal = json.loads(PROPOSAL.read_text(encoding="utf-8"))
    base = json.loads(BASE.read_text(encoding="utf-8"))["levels"]
    records = json.loads(COMPACT.read_text(encoding="utf-8"))["records"]
    config = load_config(PIPELINE, "pl")
    return proposal, base, WordIndex(records, config), config


def _validate(proposal: dict, base: list, index: WordIndex, config: object) -> None:
    assert proposal["schema_version"] == 1
    assert proposal["lang"] == "pl"
    assert proposal["status"] == "proposed"
    assert set(proposal) == {"schema_version", "lang", "status", "provenance", "policy", "levels"}
    assert proposal["provenance"] == {
        "compact_input_git_blob_sha1": _git_blob_sha1(COMPACT.read_bytes()),
        "first65_pack_git_blob_sha1": _git_blob_sha1(BASE.read_bytes()),
        "lexical_review_git_blob_sha1": _git_blob_sha1(LEXICAL.read_bytes()),
    }
    assert proposal["policy"] == {
        "first_new_slot": 66,
        "last_new_slot": 200,
        "crossword_word_spacing": 100,
        "existing_slots_preserved": 65,
        "api_ai_cost_pln": 0,
    }
    assert len(base) == 65
    assert [level["slot"] for level in base] == list(range(1, 66))
    entries = proposal["levels"]
    assert len(entries) == 135
    assert [level["slot"] for level in entries] == list(range(66, 201))
    seen_wheels: set[str] = set()
    last_answer: dict[str, int] = {}
    for level in base:
        letters = "".join(sorted(level["letters"]))
        assert letters not in seen_wheels
        seen_wheels.add(letters)
        for placement in level["words"]:
            last_answer[placement["w"]] = level["slot"]
    for level in entries:
        slot = level["slot"]
        assert set(level) == {
            "slot",
            "band",
            "letters",
            "words",
            "grid",
            "editorial_status",
            "manual_review_priority",
        }
        assert level["editorial_status"] == "proposed"
        assert type(level["manual_review_priority"]) is bool
        assert type(level["band"]) is int
        assert level["band"] == (2 if slot <= 90 else 3 if slot <= 150 else 4 if slot <= 175 else 5)
        letters = level["letters"]
        assert 5 <= len(letters) <= 7
        assert letters == sorted(letters)
        assert len(letters) == (5 if slot <= 90 else 6 if slot <= 150 else 7)
        signature = "".join(letters)
        assert signature not in seen_wheels
        seen_wheels.add(signature)
        words = level["words"]
        assert len(words) >= 2
        assert len(set(words)) == len(words)
        assert len(level["grid"]) == len(words)
        assert all(index.tiers.get(word) == "level_ok" for word in words)
        pools = index.pools(letters)
        assert set(words) <= set(pools["level_ok"])
        expected_bonus = sorted((set(pools["level_ok"]) | set(pools["bonus_ok"])) - set(words))
        authored = {
            "slot": slot,
            "letters": letters,
            "words": words,
            "bonus": expected_bonus,
            "grid": level["grid"],
        }
        native = make_level(authored, config, handmade=True)
        assert native["words"] == sorted(words)
        assert native["bonus"] == expected_bonus
        assert native["grid"]["w"] <= native["grid"]["h"] <= 10
        for word in words:
            assert slot - last_answer.get(word, -100) >= 100
            last_answer[word] = slot
    assert len(seen_wheels) == 200


def test_all_135_candidates_are_native_valid_and_source_pinned() -> None:
    _validate(*_inputs())


def test_published_65_remain_identical_and_no_generated_pack_is_added() -> None:
    proposal, base, _index, _config = _inputs()
    assert len(base) == 65
    assert proposal["policy"]["existing_slots_preserved"] == 65
    manifest = json.loads((REPO / "game/content/pl/manifest.json").read_text())
    assert manifest["slots"] == 65
    assert [entry["file"] for entry in manifest["packs"]] == ["packs/c-0001-0065.json"]


@pytest.mark.parametrize("mutation", ["unknown_answer", "duplicate_slot", "grid", "repeat"])
def test_corrupt_candidate_is_rejected(mutation: str) -> None:
    proposal, base, index, config = _inputs()
    bad = copy.deepcopy(proposal)
    if mutation == "unknown_answer":
        bad["levels"][0]["words"][0] = "ZZZ"
    elif mutation == "duplicate_slot":
        bad["levels"][1]["slot"] = 66
    elif mutation == "grid":
        bad["levels"][0]["grid"][0]["x"] = 99
    else:
        bad["levels"][1]["letters"] = bad["levels"][0]["letters"]
    with pytest.raises((AssertionError, ValueError)):
        _validate(bad, base, index, config)


def test_tampered_source_provenance_is_rejected() -> None:
    proposal, base, index, config = _inputs()
    proposal["provenance"]["compact_input_git_blob_sha1"] = "0" * 40
    with pytest.raises(AssertionError):
        _validate(proposal, base, index, config)
