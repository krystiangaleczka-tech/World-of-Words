"""Pure supply report against reviewed tier fixtures only."""

from pathlib import Path

import pytest
from wordgame_pipeline.candidates.core import WordIndex
from wordgame_pipeline.candidates.coverage import audit_candidate_coverage
from wordgame_pipeline.config import load_config

CONFIG = load_config(Path(__file__).resolve().parents[2], "pl")


def words(**tiers):
    return [{"word": word, "tier": tier} for word, tier in sorted(tiers.items())]


def test_supply_shortage_and_multiplicity():
    index = WordIndex(
        words(DOM="level_ok", KOT="level_ok", TOK="level_ok", OKO="bonus_ok"),
        CONFIG,
    )
    report = audit_candidate_coverage(index, minimum_words=2)
    assert report.required_words == 2
    assert report.total_wheels == 2
    assert report.eligible_wheels == 1
    assert report.wheels_by_length == ((3, 2),)
    assert len(report.shortages) == 1
    shortage = report.shortages[0]
    assert shortage.candidate_id == "pl-auto-DMO"
    assert shortage.letter_count == 3
    assert shortage.selected_options == 1
    assert shortage.seed_count == 1
    assert shortage.bonus_options == 0


def test_no_candidates_and_no_mutation_or_hidden_policy():
    index = WordIndex(words(KOT="bonus_ok"), CONFIG)
    assert audit_candidate_coverage(index, minimum_words=3).total_wheels == 0
    before = index.automatic()
    one = audit_candidate_coverage(index, minimum_words=1)
    assert one.eligible_wheels == 0
    assert index.automatic() == before
    with pytest.raises(ValueError):
        audit_candidate_coverage(index, minimum_words=0)


@pytest.mark.parametrize("minimum", [True, 0, -1, 1.0, "2", None])
def test_invalid_minimum_rejected(minimum):
    with pytest.raises(ValueError):
        audit_candidate_coverage(WordIndex([], CONFIG), minimum_words=minimum)


def test_invalid_index_rejected():
    with pytest.raises(ValueError):
        audit_candidate_coverage(None, minimum_words=1)


def test_ready_supply_and_stable_result():
    index = WordIndex(
        words(KOT="level_ok", TOK="level_ok"),
        CONFIG,
    )
    a = audit_candidate_coverage(index, minimum_words=2)
    b = audit_candidate_coverage(index, minimum_words=2)
    assert a == b and a.eligible_wheels == 1 and a.shortages == ()
