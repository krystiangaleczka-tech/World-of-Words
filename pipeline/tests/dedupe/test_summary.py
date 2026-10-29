"""The conflict summary reports pair evidence without relaxing gates."""

import copy
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.dedupe import DuplicatePolicy
from wordgame_pipeline.dedupe.summary import summarize_duplicate_conflicts

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")
POLICY = DuplicatePolicy(0.5, 100)


def record(identity, slot, letters, words, seed, pool="campaign"):
    return {
        "id": identity,
        "pool": pool,
        "slot": slot,
        "letters": list(letters),
        "words": list(words),
        "seed_word": seed,
    }


def test_all_reasons_and_unique_affected_ids():
    rows = [
        record("a", 1, "KOT", ("KOT", "TOK"), "KOT"),
        record("b", 2, "TOK", ("TOK", "KOT"), "KOT"),
        record("c", 3, "DOM", ("DOM",), "DOM"),
    ]
    before = copy.deepcopy(rows)
    report = summarize_duplicate_conflicts(rows, POLICY, CONFIG)
    assert report.compared_pairs == 3
    assert report.conflicting_pairs == 1
    assert report.by_reason == (
        ("letter_multiset", 1),
        ("word_jaccard", 1),
        ("word_spacing", 1),
        ("seed_spacing", 1),
    )
    assert report.affected_ids == ("a", "b") and report.highest_jaccard == 1
    assert report == summarize_duplicate_conflicts(rows[::-1], POLICY, CONFIG)
    assert rows == before
    with pytest.raises(FrozenInstanceError):
        report.conflicting_pairs = 2


def test_empty_single_and_clean_records():
    empty = summarize_duplicate_conflicts([], POLICY, CONFIG)
    assert empty.compared_pairs == empty.conflicting_pairs == 0
    assert empty.highest_jaccard == 0
    assert all(count == 0 for _, count in empty.by_reason)
    one = record("a", 1, "KOT", ("KOT",), "KOT")
    assert summarize_duplicate_conflicts([one], POLICY, CONFIG).compared_pairs == 0
    two = record("b", 2, "DOM", ("DOM",), "DOM")
    report = summarize_duplicate_conflicts([one, two], POLICY, CONFIG)
    assert report.compared_pairs == 1 and report.conflicting_pairs == 0


def test_cross_pool_overlap_only_counts_applicable_reasons():
    a = record("a", 1, "KOT", ("KOT",), "KOT")
    b = record("b", 1, "TOK", ("TOK",), "TOK", "daily")
    summary = summarize_duplicate_conflicts([a, b], POLICY, CONFIG)
    assert summary.by_reason[0] == ("letter_multiset", 1)
    assert sum(count for _, count in summary.by_reason) == 1


def test_invalid_record_policy_and_shape_rejected():
    a = record("a", 1, "KOT", ("KOT",), "KOT")
    for records in (None, [a, a], [a, {"id": "b"}], [a, 5], iter([a])):
        with pytest.raises(ValueError):
            summarize_duplicate_conflicts(records, POLICY, CONFIG)
    with pytest.raises(ValueError):
        summarize_duplicate_conflicts([a], None, CONFIG)
    with pytest.raises(ValueError):
        summarize_duplicate_conflicts([a], POLICY, None)
