"""Pure P2 campaign diversity gate; P1 shipped content remains untouched."""

import copy
from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.dedupe import DuplicatePolicy
from wordgame_pipeline.validate.diversity import validate_campaign_diversity

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")
POLICY = DuplicatePolicy(1, 100)


def level(slot, letters, words):
    return {
        "id": f"pl-c-{slot:06d}",
        "slot": slot,
        "letters": list(letters),
        "words": [{"w": word} for word in words],
    }


def test_clean_campaign_and_input_order_do_not_change_result():
    levels = [level(1, "KOT", ["KOT"]), level(2, "DOME", ["DOM"])]
    seeds = {1: "KOT", 2: "DOM"}
    original = copy.deepcopy((levels, seeds))
    assert validate_campaign_diversity(levels, seeds, POLICY, CONFIG) is None
    assert validate_campaign_diversity(levels[::-1], seeds, POLICY, CONFIG) is None
    assert (levels, seeds) == original


def test_same_wheel_multiset_is_rejected_even_with_different_order():
    levels = [level(1, "KOT", ["KOT"]), level(2, "TOK", ["TOK"])]
    with pytest.raises(ValueError, match="letter_multiset"):
        validate_campaign_diversity(levels, {1: "KOT", 2: "TOK"}, POLICY, CONFIG)


def test_every_word_spacing_and_seed_boundaries():
    levels = [level(1, "KOT", ["KOT"]), level(2, "KOTA", ["KOT", "KAT"])]
    with pytest.raises(ValueError, match="word_spacing"):
        validate_campaign_diversity(levels, {1: "KOT", 2: "KAT"}, POLICY, CONFIG)
    # A single campaign must be contiguous; test distance boundaries in the
    # underlying reviewed pair audit instead of forging missing campaign slots.
    from wordgame_pipeline.dedupe import audit_duplicates

    one = dict(id="a", pool="campaign", slot=1, letters=list("KOT"), words=["KOT"], seed_word="KOT")
    two = dict(
        id="b",
        pool="campaign",
        slot=100,
        letters=list("KOTA"),
        words=["KOT", "KAT"],
        seed_word="KOT",
    )
    assert "word_spacing" in audit_duplicates([one, two], POLICY, CONFIG)[0].reasons
    two["slot"] = 101
    assert audit_duplicates([one, two], POLICY, CONFIG) == ()


def test_jaccard_threshold_is_explicit_and_strict():
    levels = [level(1, "KOT", ["KOT"]), level(2, "KOTA", ["KOT", "KAT"])]
    seeds = {1: "KOT", 2: "KAT"}
    with pytest.raises(ValueError, match="word_jaccard"):
        validate_campaign_diversity(levels, seeds, DuplicatePolicy(0.4, 100), CONFIG)
    with pytest.raises(ValueError, match="word_spacing"):
        validate_campaign_diversity(levels, seeds, POLICY, CONFIG)


@pytest.mark.parametrize(
    "levels,seeds",
    [
        ([], {}),
        ([level(2, "KOT", ["KOT"])], {2: "KOT"}),
        ([level(1, "KOT", ["KOT"])], {}),
        ([level(1, "KOT", ["KOT"])], {1: "KOT", 2: "DOM"}),
        ([level(1, "KOT", ["KOT"])], {True: "KOT"}),
        ([level(1, "KOT", ["KOT"])], {1: "TOK"}),
        ([level(1, "KOT", ["KOT"]), level(1, "DOME", ["DOM"])], {1: "KOT"}),
        ([level(1, "KOT", ["KOT"]) | {"id": "wrong"}], {1: "KOT"}),
    ],
)
def test_missing_invalid_or_ambiguous_sources_fail(levels, seeds):
    with pytest.raises(ValueError):
        validate_campaign_diversity(levels, seeds, POLICY, CONFIG)


def test_non_campaign_bad_wheel_and_no_guessing_rng_seed():
    with pytest.raises(ValueError):
        validate_campaign_diversity(
            [level(1, "KOT", ["KOT"]) | {"seed": 123}], {1: "KOK"}, POLICY, CONFIG
        )
    with pytest.raises(ValueError):
        validate_campaign_diversity([level(1, "KOT", ["KOT"])], {1: 123}, POLICY, CONFIG)
