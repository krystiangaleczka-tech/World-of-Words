"""QA reports only evidence-backed flags and measured difficulty."""

import copy

import pytest
from wordgame_pipeline.config import canonical_bytes, parse_json
from wordgame_pipeline.qa.p2_report import campaign_qa_report


def level(slot, word, score):
    return {
        "id": f"pl-c-{slot:06d}",
        "slot": slot,
        "letters": list(word),
        "words": [{"w": word}],
        "bonus": [],
        "source": "handmade",
        "landmark": False,
        "difficulty": score,
    }


def review():
    return canonical_bytes(
        {
            "schema_version": 1,
            "lang": "pl",
            "basis": {
                "tier_artifact_sha256": "a" * 64,
                "overrides_sha256": "b" * 64,
                "familiarity_catalog_sha256": "c" * 64,
            },
            "unresolved": [
                {
                    "word": "KOT",
                    "source_tier": "level_ok",
                    "evidence_flags": ["frequency_missing"],
                }
            ],
            "escalations": [
                {"word": "LAS", "source_tier": "bonus_ok", "evidence_flags": ["lemma_missing"]}
            ],
            "semantic_approval_inferred": False,
        }
    )


def test_histogram_hardest_and_lexical_flags_are_deterministic():
    levels = [level(1, "KOT", 0.1), level(2, "LAS", 0.9), level(3, "DOM", 0.5)]
    before = copy.deepcopy(levels)
    raw = campaign_qa_report(levels, review(), bucket_edges=(0, 0.5, 1), review_limit=2)
    result = parse_json(raw.decode())
    assert result["summary"]["slots"] == 3
    assert result["hardest_slots"] == [
        {"slot": 2, "difficulty": 0.9},
        {"slot": 3, "difficulty": 0.5},
    ]
    assert [(row["word"], row["source_tier"]) for row in result["uncertain_selected_words"]] == [
        ("KOT", "level_ok"),
        ("LAS", "bonus_ok"),
    ]
    assert result["human_approval_recorded"] is False
    assert levels == before
    assert raw == campaign_qa_report(
        levels[::-1], review(), bucket_edges=(0, 0.5, 1), review_limit=2
    )


def test_empty_review_flags_are_allowed_without_inventing_approval():
    empty = parse_json(review().decode())
    empty["unresolved"] = []
    empty["escalations"] = []
    result = parse_json(
        campaign_qa_report(
            [level(1, "KOT", 0)],
            canonical_bytes(empty),
            bucket_edges=(0, 1),
            review_limit=3,
        ).decode()
    )
    assert result["uncertain_selected_words"] == []
    assert result["human_approval_recorded"] is False


@pytest.mark.parametrize(
    "mutate",
    [
        lambda data: data.update(semantic_approval_inferred=True),
        lambda data: data["unresolved"].append(data["unresolved"][0]),
        lambda data: data["unresolved"][0].update(source_tier="banned"),
    ],
)
def test_invalid_or_false_review_evidence_rejected(mutate):
    data = parse_json(review().decode())
    mutate(data)
    with pytest.raises(ValueError):
        campaign_qa_report(
            [level(1, "KOT", 0.1)],
            canonical_bytes(data),
            bucket_edges=(0, 1),
            review_limit=1,
        )


def test_noncanonical_bytes_and_invalid_limits_rejected():
    with pytest.raises(ValueError):
        campaign_qa_report(
            [level(1, "KOT", 0.1)],
            review() + b" ",
            bucket_edges=(0, 1),
            review_limit=1,
        )
    for bad in (0, True, 1.2, -1):
        with pytest.raises(ValueError):
            campaign_qa_report(
                [level(1, "KOT", 0.1)],
                review(),
                bucket_edges=(0, 1),
                review_limit=bad,
            )
