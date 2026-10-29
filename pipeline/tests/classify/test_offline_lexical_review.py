"""Offline lexical review: real rule path, no network or automated approval."""

import hashlib
from dataclasses import asdict
from pathlib import Path

import pytest
from wordgame_pipeline import __version__
from wordgame_pipeline.classify import build_review_queue
from wordgame_pipeline.config import canonical_bytes, load_config, parse_json
from wordgame_pipeline.tiers.core import assign_tiers, parse_overrides

ROOT = Path(__file__).parents[2]
SOURCE = {"dataset": "source-pin"}
ANNOTATIONS = {"dataset": "morphology-frequency-pin"}
EMPTY_OVERRIDES = b"word,tier,reason,date,by\n"
EMPTY_REVIEWS = b"word,band,status,reviewer,rationale\n"


def _row(word, form_arf=None, *, names=(), analyses=True):
    entry = {
        "lemma": word,
        "lemma_raw": word.lower(),
        "pos": "subst",
        "tag": "subst:sg",
        "names": list(names),
        "labels": [],
        "is_inflected": False,
        "frequency": None,
    }
    return {
        "word": word,
        "frequency": None if form_arf is None else {"arf": form_arf, "ipm": 1},
        "analyses": [entry] if analyses else [],
        "has_lemma_evidence": analyses,
    }


def _fixture(overrides=EMPTY_OVERRIDES, records=None):
    config = load_config(ROOT, "pl")
    raw = (
        records
        if records is not None
        else [
            _row("DOM", 80),
            _row("JAN", 100, names=("imię",)),
            _row("KOT", 100),
            _row("LAS"),
        ]
    )
    rules = parse_json(canonical_bytes(asdict(config.tier_rules)).decode("utf-8"))
    decisions = parse_overrides(overrides.decode("utf-8"), config)
    assigned = assign_tiers(raw, config, decisions)
    payload = {
        "source": SOURCE,
        "annotation_sources": ANNOTATIONS,
        "tier_rules": rules,
        "tier_rules_sha256": hashlib.sha256(canonical_bytes(rules)).hexdigest(),
        "overrides_sha256": hashlib.sha256(overrides).hexdigest(),
        **assigned,
    }
    artifact = {
        "schema_version": 1,
        "pipeline_version": __version__,
        "lang": "pl",
        "stage": "05-tiers",
        "config_sha256": hashlib.sha256(canonical_bytes(config.to_dict())).hexdigest(),
        "input_sha256": "a" * 64,
        "payload": payload,
    }
    return config, artifact


def _run(artifact, config, overrides=EMPTY_OVERRIDES, reviews=EMPTY_REVIEWS, words=None):
    candidates = ("DOM", "JAN", "KOT", "LAS") if words is None else words
    return build_review_queue(
        canonical_bytes(artifact), overrides, reviews, candidates, config, SOURCE, ANNOTATIONS
    )


def test_unreviewed_and_escalation_are_separate_and_no_approval_is_inferred():
    config, artifact = _fixture()
    reviews = EMPTY_REVIEWS + b"KOT,2,reviewed,chris,well known\n"
    first = _run(artifact, config, reviews=reviews)
    second = _run(artifact, config, reviews=reviews)
    assert first == second
    result = parse_json(first.decode("utf-8"))
    assert result["candidate_count"] == 4
    assert result["reviewed_familiarity_count"] == 1
    assert [row["word"] for row in result["unresolved"]] == ["DOM"]
    assert [row["word"] for row in result["escalations"]] == ["JAN", "LAS"]
    assert result["semantic_approval_inferred"] is False
    assert result["unresolved"][0]["source_arf"] == 80
    assert result["unresolved"][0]["editorial_status"] == "unreviewed"
    assert "frequency_missing" in result["escalations"][1]["evidence_flags"]
    assert all(
        entry["escalation"] == "manual_only_no_automatic_promotion"
        for entry in result["escalations"]
    )
    assert (
        result["basis"]["tier_artifact_sha256"]
        == hashlib.sha256(canonical_bytes(artifact)).hexdigest()
    )
    assert result["basis"]["familiarity_catalog_sha256"] == hashlib.sha256(reviews).hexdigest()


@pytest.mark.parametrize(
    "words",
    [
        ("JAN", "DOM"),
        ("DOM", "DOM"),
        ("XYZ",),
        ("KOT", "BRAK"),
        ("KÓT",),
    ],
)
def test_candidate_identity_fails_closed(words):
    config, artifact = _fixture()
    with pytest.raises(ValueError, match="Candidates"):
        _run(artifact, config, words=words)


def test_source_and_rules_tamper_is_rejected():
    config, artifact = _fixture()
    with pytest.raises(ValueError, match="Unpinned"):
        build_review_queue(
            canonical_bytes(artifact),
            EMPTY_OVERRIDES,
            EMPTY_REVIEWS,
            ("DOM",),
            config,
            {"dataset": "different"},
            ANNOTATIONS,
        )
    artifact["payload"]["records"][0]["tier"] = "banned"
    with pytest.raises(ValueError, match="disagree"):
        _run(artifact, config)
    artifact["payload"]["records"][0]["tier"] = "level_ok"
    artifact["payload"]["tier_rules"]["base_min_arf"] = 9999
    with pytest.raises(ValueError, match="Unpinned"):
        _run(artifact, config)


def test_missing_evidence_does_not_become_safe_or_a_level_word():
    config, artifact = _fixture(records=[_row("KOT", analyses=False)])
    result = parse_json(_run(artifact, config, words=("KOT",)).decode("utf-8"))
    assert result["unresolved"] == []
    assert result["escalations"][0]["source_tier"] == "bonus_ok"
    assert "lemma_missing" in result["escalations"][0]["evidence_flags"]
    assert "frequency_missing" in result["escalations"][0]["evidence_flags"]
    assert result["semantic_approval_inferred"] is False


def test_explicit_ban_is_immutable_in_the_review_queue():
    overrides = EMPTY_OVERRIDES + b"DOM,banned,editorial exclusion,2026-10-20,chris\n"
    config, artifact = _fixture(overrides=overrides)
    result = parse_json(_run(artifact, config, overrides=overrides, words=("DOM",)).decode("utf-8"))
    assert result["unresolved"] == []
    assert result["escalations"][0]["source_tier"] == "banned"


@pytest.mark.parametrize(
    "reviews",
    [
        b"word,band,status,reviewer,rationale\nDOM,,reviewed,chris,ok\n",
        b"word,band,status,reviewer,rationale\nDOM,6,proposed,chris,ok\n",
        b"word,band,status,reviewer,rationale\nJAN,2,reviewed,chris,ok\n",
        b"word,band,status,reviewer,rationale\nXYZ,2,reviewed,chris,ok\n",
        b"word,band,status,reviewer,rationale\nKOT,2,reviewed,chris,ok\nDOM,2,reviewed,chris,ok\n",
    ],
)
def test_malformed_and_unauthorized_familiarity_catalogs_fail(reviews):
    config, artifact = _fixture()
    with pytest.raises(ValueError):
        _run(artifact, config, reviews=reviews)


def test_override_mutation_and_noncanonical_artifact_fail():
    config, artifact = _fixture()
    with pytest.raises(ValueError, match="Unpinned"):
        _run(artifact, config, overrides=EMPTY_OVERRIDES + b"\n")
    data = canonical_bytes(artifact) + b" "
    with pytest.raises(ValueError, match="identity"):
        build_review_queue(
            data,
            EMPTY_OVERRIDES,
            EMPTY_REVIEWS,
            ("DOM",),
            config,
            SOURCE,
            ANNOTATIONS,
        )


def test_proposed_familiarity_is_not_reviewed():
    config, artifact = _fixture()
    reviews = EMPTY_REVIEWS + b"DOM,2,proposed,editor,needs owner\n"
    result = parse_json(_run(artifact, config, reviews=reviews, words=("DOM",)).decode())
    assert result["reviewed_familiarity_count"] == 0
    assert result["unresolved"][0]["editorial_status"] == "proposed"
