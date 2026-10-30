"""T-0297: an offline review can flag changes but cannot approve new words."""

import hashlib
from dataclasses import asdict
from pathlib import Path

import pytest
from wordgame_pipeline import __version__
from wordgame_pipeline.config import canonical_bytes, load_config, parse_json
from wordgame_pipeline.tiers.core import assign_tiers, parse_overrides
from wordgame_pipeline.tiers.review_diff import audit_reviewed_tiers

ROOT = Path(__file__).parents[2]
SOURCE = {"dataset": "pinned-source"}
ANNOTATIONS = {"dataset": "pinned-annotations"}
HEADER = b"word,tier,reason,date,by\n"
REVIEWS = b"word,band,status,reviewer,rationale\nKOT,2,reviewed,chris,confirmed familiar\n"
BEFORE = {"JAN": "banned", "KOT": "bonus_ok", "LAS": "bonus_ok"}


def _record(word, frequency=None, *, proper=False):
    return {
        "word": word,
        "frequency": None if frequency is None else {"arf": frequency, "ipm": 1},
        "analyses": [
            {
                "lemma": word,
                "lemma_raw": word.lower(),
                "pos": "subst",
                "tag": "subst:sg",
                "names": ["imię"] if proper else [],
                "labels": [],
                "is_inflected": False,
                "frequency": None,
            }
        ],
        "has_lemma_evidence": True,
    }


def _fixture(overrides=HEADER):
    config = load_config(ROOT, "pl")
    rules = asdict(config.tier_rules)
    rows = [_record("JAN", 100, proper=True), _record("KOT", 100), _record("LAS")]
    decisions = parse_overrides(overrides.decode(), config)
    payload = {
        "source": SOURCE,
        "annotation_sources": ANNOTATIONS,
        "tier_rules": rules,
        "tier_rules_sha256": hashlib.sha256(canonical_bytes(rules)).hexdigest(),
        "overrides_sha256": hashlib.sha256(overrides).hexdigest(),
        **assign_tiers(rows, config, decisions),
    }
    envelope = {
        "schema_version": 1,
        "pipeline_version": __version__,
        "lang": "pl",
        "stage": "05-tiers",
        "config_sha256": hashlib.sha256(canonical_bytes(config.to_dict())).hexdigest(),
        "input_sha256": "a" * 64,
        "payload": payload,
    }
    return config, canonical_bytes(envelope)


def _audit(config, artifact, overrides=HEADER, *, before=BEFORE, limit=0, reviews=REVIEWS):
    return parse_json(
        audit_reviewed_tiers(
            artifact,
            overrides,
            reviews,
            before,
            config,
            SOURCE,
            ANNOTATIONS,
            max_changed_words=limit,
        ).decode()
    )


def test_source_rule_promotion_requires_owner_attention():
    config, artifact = _fixture()
    result = _audit(config, artifact)
    assert result["current_counts"] == {"level_ok": 1, "bonus_ok": 1, "banned": 1}
    assert result["previous_counts"] == {"level_ok": 0, "bonus_ok": 2, "banned": 1}
    assert result["transition_count"] == 1
    assert result["transitions"] == [
        {
            "word": "KOT",
            "from": "bonus_ok",
            "to": "level_ok",
            "explicit_owner_override": False,
        }
    ]
    assert result["unapproved_promotions"] == ["KOT"]
    assert result["alarm_reasons"] == [
        "change_limit_exceeded",
        "level_promotion_without_owner_override",
    ]
    assert result["reviewed_familiarity_count"] == 1
    assert result["automated_approval"] is False
    assert canonical_bytes(result) == audit_reviewed_tiers(
        artifact,
        HEADER,
        REVIEWS,
        BEFORE,
        config,
        SOURCE,
        ANNOTATIONS,
        max_changed_words=0,
    )


def test_explicit_owner_override_can_clear_promotion_alarm_but_not_mark_approved():
    overrides = HEADER + b"KOT,level_ok,manual eligibility,2026-10-29,chris\n"
    config, artifact = _fixture(overrides)
    result = _audit(config, artifact, overrides, limit=1)
    assert result["transitions"][0]["explicit_owner_override"] is True
    assert result["alarm"] is False
    assert result["alarm_reasons"] == []
    assert result["automated_approval"] is False
    assert result["manual_escalation_count"] == 2


def test_unchanged_snapshot_has_no_transitions_but_still_needs_familiarity_review():
    config, artifact = _fixture()
    result = _audit(
        config,
        artifact,
        before={
            "JAN": "banned",
            "KOT": "level_ok",
            "LAS": "bonus_ok",
        },
    )
    assert result["transition_count"] == 0
    assert result["alarm"] is False
    assert result["manual_escalation_count"] == 2


@pytest.mark.parametrize(
    "bad",
    [
        {},
        {"JAN": "banned"},
        {"JAN": "banned", "KOT": "bad", "LAS": "bonus_ok"},
        {"JAN": "banned", "KOT": "bonus_ok", "LAS": "bonus_ok", "XYZ": "banned"},
    ],
)
def test_incomplete_or_wrong_baseline_rejected(bad):
    config, artifact = _fixture()
    with pytest.raises(ValueError, match="Baseline"):
        _audit(config, artifact, before=bad)


@pytest.mark.parametrize("limit", [-1, True, 1.1, "2"])
def test_noninteger_alarm_limit_rejected(limit):
    config, artifact = _fixture()
    with pytest.raises(ValueError, match="alarm limit"):
        _audit(config, artifact, limit=limit)


def test_source_or_tier_tampering_fails_closed():
    config, artifact = _fixture()
    with pytest.raises(ValueError):
        audit_reviewed_tiers(
            artifact,
            HEADER,
            REVIEWS,
            BEFORE,
            config,
            {"dataset": "different"},
            ANNOTATIONS,
            max_changed_words=1,
        )
    parsed = parse_json(artifact.decode())
    parsed["payload"]["records"][1]["tier"] = "banned"
    with pytest.raises(ValueError):
        _audit(config, canonical_bytes(parsed))


def test_bad_review_and_changed_override_bytes_fail_closed():
    config, artifact = _fixture()
    with pytest.raises(ValueError):
        _audit(
            config,
            artifact,
            reviews=(b"word,band,status,reviewer,rationale\nKOT,2,reviewed,,no reviewer\n"),
        )
    with pytest.raises(ValueError):
        _audit(config, artifact, HEADER + b"\n")
