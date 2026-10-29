"""Repeat words are reported but never removed from the campaign."""

import copy
from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.qa.word_reuse import WordReuse, review_word_reuse


def level(slot, words):
    return {
        "id": f"pl-c-{slot:06d}",
        "slot": slot,
        "words": [{"w": word} for word in words],
    }


def test_exact_repeat_counts_order_and_threshold():
    rows = [
        level(1, ("KOT", "DOM")),
        level(2, ("KOT", "TOK")),
        level(3, ("KOT", "DOM")),
    ]
    original = copy.deepcopy(rows)
    expected = (
        WordReuse("KOT", (1, 2, 3)),
        WordReuse("DOM", (1, 3)),
    )
    assert review_word_reuse(rows, minimum_levels=2) == expected
    assert review_word_reuse(rows[::-1], minimum_levels=2) == expected
    assert review_word_reuse(rows, minimum_levels=3) == expected[:1]
    assert review_word_reuse(rows, minimum_levels=4) == ()
    assert rows == original
    with pytest.raises(FrozenInstanceError):
        expected[0].word = "TOK"


def test_empty_valid_campaign_has_no_repetitions():
    assert review_word_reuse([], minimum_levels=2) == ()
    assert review_word_reuse([level(1, ("KOT",))], minimum_levels=2) == ()


@pytest.mark.parametrize("minimum", [0, 1, True, 2.0, "2", None])
def test_bad_minimum_fails(minimum):
    with pytest.raises(ValueError):
        review_word_reuse([], minimum_levels=minimum)


@pytest.mark.parametrize(
    "levels",
    [
        None,
        [None],
        [level(2, ("KOT",))],
        [level(1, ("KOT",)), level(1, ("DOM",))],
        [level(1, ("KOT",)), level(3, ("DOM",))],
        [level(1, ("KOT",)) | {"slot": True}],
        [level(1, ("KOT",)) | {"id": "wrong"}],
        [level(1, ("KOT", "KOT"))],
        [level(1, ("kot",))],
        [level(1, ())],
        [level(1, ("KOT",)) | {"words": "KOT"}],
    ],
)
def test_malformed_campaign_fails(levels):
    with pytest.raises(ValueError):
        review_word_reuse(levels, minimum_levels=2)
