"""Boundary and deterministic pair evidence; thresholds here are fixtures only."""

import copy
from dataclasses import FrozenInstanceError
from itertools import permutations
from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.dedupe import DuplicatePolicy, audit_duplicates

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")
POLICY = DuplicatePolicy(1, 100)


def record(identity="a", slot=1, letters="KOT", words=("KOT",), seed="KOT", pool="campaign"):
    return dict(
        id=identity, pool=pool, slot=slot, letters=list(letters), words=list(words), seed_word=seed
    )


def test_same_multiset_ignores_tile_order_and_preserves_multiplicity():
    a = record(letters="ANNA", words=("ANNA",), seed="ANNA")
    b = record("b", 201, "AANN", ("ANNA",), "ANNA")
    result = audit_duplicates([a, b], POLICY, CONFIG)
    assert result[0].reasons == ("letter_multiset",)
    assert result[0].shared_words == ("ANNA",) and result[0].jaccard == 1
    b["letters"] = list("ANNAA")
    assert audit_duplicates([a, b], POLICY, CONFIG) == ()


def test_polish_diacritics_are_distinct_tiles_and_words():
    a = record(letters="ŁATA", words=("ŁATA",), seed="ŁATA")
    b = record("b", 2, "LATA", ("LATA",), "LATA")
    assert audit_duplicates([a, b], POLICY, CONFIG) == ()


def test_jaccard_strict_threshold_and_cross_pool_symmetry():
    a = record(words=("KOT", "TOK"))
    b = record("b", 1, "KOTA", ("KOT", "KAT"), "KAT", "daily")
    assert audit_duplicates([a, b], DuplicatePolicy(1 / 3, 100), CONFIG) == ()
    result = audit_duplicates([a, b], DuplicatePolicy(0.3, 100), CONFIG)
    assert result[0].reasons == ("word_jaccard",)
    assert result[0].jaccard == 1 / 3 and result[0].shared_words == ("KOT",)
    assert audit_duplicates([b, a], DuplicatePolicy(0.3, 100), CONFIG) == result


def test_nonseed_crossword_word_spacing_boundary_99_and_100():
    a = record()
    b = record("b", 100, "KOTA", ("KAT", "KOT"), "KAT")
    assert audit_duplicates([a, b], POLICY, CONFIG)[0].reasons == ("word_spacing",)
    b["slot"] = 101
    assert audit_duplicates([a, b], POLICY, CONFIG) == ()


def test_seed_spacing_extra_boundary_and_no_cross_pool_or_daily_clock_guess():
    a = record()
    b = record("b", 200, "KOTA")
    policy = DuplicatePolicy(1, 200)
    assert audit_duplicates([a, b], policy, CONFIG)[0].reasons == ("seed_spacing",)
    b["slot"] = 201
    assert audit_duplicates([a, b], policy, CONFIG) == ()
    a["pool"] = b["pool"] = "daily"
    b["slot"] = 2
    assert audit_duplicates([a, b], policy, CONFIG) == ()
    a["pool"] = "campaign"
    assert audit_duplicates([a, b], policy, CONFIG) == ()


def test_multiple_reasons_and_shared_words_are_stably_ordered():
    a = record(words=("TOK", "KOT"))
    b = record("b", 2, words=("KOT", "TOK"))
    result = audit_duplicates([a, b], DuplicatePolicy(0.5, 100), CONFIG)
    assert result[0].reasons == ("letter_multiset", "word_jaccard", "word_spacing", "seed_spacing")
    assert result[0].shared_words == ("KOT", "TOK")
    with pytest.raises(FrozenInstanceError):
        result[0].jaccard = 0


def test_empty_singleton_permutations_nonmutation_and_no_selection():
    records = [record(), record("b", 2), record("c", 3, "DOM", ("DOM",), "DOM")]
    before = copy.deepcopy(records)
    expected = audit_duplicates(records, POLICY, CONFIG)
    assert len(expected) == 1
    for permuted in permutations(records):
        assert audit_duplicates(permuted, POLICY, CONFIG) == expected
    assert records == before
    assert (
        audit_duplicates([], POLICY, CONFIG) == audit_duplicates([records[0]], POLICY, CONFIG) == ()
    )
    records[0]["words"].reverse()
    records[0]["letters"].reverse()
    assert audit_duplicates(records, POLICY, CONFIG) == expected


@pytest.mark.parametrize(
    "threshold,spacing",
    [
        (True, 100),
        (-0.1, 100),
        (1.1, 100),
        (float("nan"), 100),
        (float("inf"), 100),
        (".5", 100),
        (0.5, True),
        (0.5, 99),
        (0.5, 100.0),
    ],
)
def test_invalid_policy_fails(threshold, spacing):
    with pytest.raises(ValueError):
        DuplicatePolicy(threshold, spacing)


@pytest.mark.parametrize(
    "update",
    [
        {"id": ""},
        {"id": " a "},
        {"id": "a\x00b"},
        {"pool": "unknown"},
        {"slot": True},
        {"slot": 0},
        {"slot": 1.5},
        {"letters": "KOT"},
        {"letters": list("kot")},
        {"letters": list("QOT")},
        {"letters": list("KO")},
        {"letters": ["K", "O", "A\u0328"]},
        {"words": []},
        {"words": ["KOT", "KOT"]},
        {"words": ["KOK"]},
        {"words": [None]},
        {"seed_word": "TOK"},
        {"seed_word": 1},
        {"bonus": ["TOK"]},
    ],
)
def test_malformed_records_fail_without_partial_output_or_mutation(update):
    records = [record(), record("b", 2), record("c", 3) | update]
    before = copy.deepcopy(records)
    with pytest.raises(ValueError):
        audit_duplicates(records, POLICY, CONFIG)
    assert records == before


def test_duplicate_ids_positions_missing_fields_and_invalid_call_shapes():
    a = record()
    for b in (record("a", 2), record("b", 1), {"id": "b"}, None):
        with pytest.raises(ValueError):
            audit_duplicates([a, b], POLICY, CONFIG)
    with pytest.raises(ValueError):
        audit_duplicates(iter([a]), POLICY, CONFIG)
    with pytest.raises(ValueError):
        audit_duplicates([a], None, CONFIG)
    with pytest.raises(ValueError):
        audit_duplicates([a], POLICY, None)


def test_cross_pool_multisets_and_zero_threshold_with_disjoint_words():
    a = record()
    b = record("b", 1, "TOK", ("TOK",), "TOK", "daily")
    policy = DuplicatePolicy(0, 100)
    assert audit_duplicates([a, b], policy, CONFIG)[0].reasons == ("letter_multiset",)
    b["words"] = ["TOK", "KOT"]
    assert audit_duplicates([a, b], policy, CONFIG)[0].reasons == (
        "letter_multiset",
        "word_jaccard",
    )
    assert (
        audit_duplicates([a, record("c", 1, "DOM", ("DOM",), "DOM", "daily")], policy, CONFIG) == ()
    )
