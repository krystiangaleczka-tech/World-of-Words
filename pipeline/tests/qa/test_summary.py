"""Pure campaign summary: fixtures are not approved production scores."""

import copy

import pytest
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.qa.summary import summarize_campaign


def level(slot, score, letters="KOT", source="handmade"):
    return {
        "id": f"pl-c-{slot:06d}",
        "slot": slot,
        "letters": list(letters),
        "words": [{"w": "KOT"}],
        "bonus": ["TOK"] if slot == 1 else [],
        "source": source,
        "landmark": False,
        "difficulty": score,
    }


def test_complete_summary_and_exact_bucket_boundaries():
    levels = [level(1, 0), level(2, 0.5, "KOTA", "generated"), level(3, 1)]
    report = summarize_campaign(levels, bucket_edges=(0, 0.5, 1))
    assert report == {
        "schema_version": 1,
        "slots": 3,
        "by_source": {"handmade": 2, "generated": 1},
        "landmarks": 0,
        "wheel_sizes": [{"letters": 3, "count": 2}, {"letters": 4, "count": 1}],
        "selected_words": 3,
        "bonus_words": 1,
        "mean_difficulty": 0.5,
        "difficulty_histogram": [
            {"lower": 0.0, "upper": 0.5, "count": 1},
            {"lower": 0.5, "upper": 1.0, "count": 2},
        ],
    }


def test_order_independent_deterministic_fresh_and_nonmutating():
    levels = [level(1, 0.2), level(2, 0.6, "KOTA", "generated")]
    original = copy.deepcopy(levels)
    first = summarize_campaign(levels, bucket_edges=(0, 0.5, 1))
    second = summarize_campaign(levels[::-1], bucket_edges=(0, 0.5, 1))
    assert canonical_bytes(first) == canonical_bytes(second)
    assert levels == original
    first["difficulty_histogram"][0]["count"] = 999
    assert summarize_campaign(levels, bucket_edges=(0, 0.5, 1)) == second


@pytest.mark.parametrize(
    "edges",
    [(), (0,), (0, 0.5), (0.1, 1), (0, 0.5, 0.5, 1), (0, 2), (0, True, 1),
     (0, float("nan"), 1), (0, float("inf"), 1), [0, 1]],
)
def test_invalid_histogram_edges_fail(edges):
    with pytest.raises(ValueError):
        summarize_campaign([level(1, 0.4)], bucket_edges=edges)


@pytest.mark.parametrize(
    "change",
    [
        {"slot": True},
        {"slot": 0},
        {"slot": 3},
        {"id": "pl-c-000002"},
        {"difficulty": True},
        {"difficulty": -0.1},
        {"difficulty": 1.1},
        {"difficulty": float("nan")},
        {"difficulty": float("inf")},
        {"difficulty": 10**400},
        {"letters": "KOT"},
        {"words": []},
        {"words": [{"w": "KOT"}, {"w": "KOT"}]},
        {"bonus": None},
        {"source": "unknown"},
        {"landmark": 1},
    ],
)
def test_invalid_level_and_position_rejected(change):
    with pytest.raises(ValueError):
        summarize_campaign([level(1, 0.2) | change], bucket_edges=(0, 1))


def test_empty_duplicate_missing_and_non_mapping_levels_rejected():
    for records in (
        [],
        [level(1, 0), level(1, 1)],
        [level(1, 0), level(3, 1)],
        [None],
    ):
        with pytest.raises(ValueError):
            summarize_campaign(records, bucket_edges=(0, 1))
