"""Offline lexical review: real rule path, no network or automated approval."""

import hashlib
from copy import deepcopy
from dataclasses import asdict, replace
from pathlib import Path

import pytest
from wordgame_pipeline import __version__
from wordgame_pipeline.annotate.sources import load_pin as annotation_pin
from wordgame_pipeline.classify import build_review_queue
from wordgame_pipeline.config import canonical_bytes, load_config, parse_json
from wordgame_pipeline.ingest.source import load_pin as source_pin
from wordgame_pipeline.tiers.core import assign_tiers, parse_overrides

ROOT = Path(__file__).parents[2]
SOURCE = source_pin(ROOT).to_dict()
ANNOTATIONS = annotation_pin(ROOT)
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


def test_ambiguous_analyses_remain_explicit_uncertainty():
    record = _row("DOM", 80)
    variant = {**record["analyses"][0], "tag": "subst:pl"}
    record["analyses"].append(variant)
    config, artifact = _fixture(records=[record])
    output = parse_json(_run(artifact, config, words=("DOM",)).decode("utf-8"))
    assert "multiple_analyses" in output["unresolved"][0]["evidence_flags"]


def test_unsorted_tier_source_and_non_polish_config_are_rejected():
    config, artifact = _fixture()
    swapped = artifact["payload"]["records"]
    swapped[0], swapped[1] = swapped[1], swapped[0]
    with pytest.raises(ValueError):
        _run(artifact, config)
    with pytest.raises(ValueError, match="Polish"):
        _run(_fixture()[1], replace(config, lang="en"))


@pytest.mark.parametrize("pin", [None, {}, {"dataset": "unverified"}])
@pytest.mark.parametrize("kind", ["source", "annotation_sources"])
def test_missing_or_unpinned_identity_is_rejected_even_when_expected_matches(kind, pin):
    config, artifact = _fixture()
    artifact["payload"][kind] = pin
    with pytest.raises(ValueError, match="source identity"):
        build_review_queue(
            canonical_bytes(artifact),
            EMPTY_OVERRIDES,
            EMPTY_REVIEWS,
            ("DOM",),
            config,
            pin if kind == "source" else SOURCE,
            pin if kind == "annotation_sources" else ANNOTATIONS,
        )


@pytest.mark.parametrize("field", ["schema_version", "tier_counts", "override", "extra"])
def test_malformed_envelope_and_recomputed_metadata_are_rejected(field):
    config, artifact = _fixture()
    if field == "schema_version":
        artifact[field] = True
    elif field == "tier_counts":
        artifact["payload"][field]["banned"] = True
    elif field == "override":
        artifact["payload"]["records"][0]["override"] = False
    else:
        artifact["payload"]["untrusted"] = "extra"
    with pytest.raises(ValueError):
        _run(artifact, config)


@pytest.mark.parametrize("status", ["approved", "", "REVIEWED"])
def test_invalid_review_status_is_rejected(status):
    config, artifact = _fixture()
    with pytest.raises(ValueError, match="status"):
        _run(artifact, config, reviews=EMPTY_REVIEWS + f"DOM,2,{status},chris,ok\n".encode())


def test_duplicate_tier_rows_are_rejected():
    config, artifact = _fixture()
    artifact["payload"]["records"].insert(0, artifact["payload"]["records"][0])
    with pytest.raises(ValueError, match="unique"):
        _run(artifact, config)


def test_approved_level_override_and_review_evidence_are_preserved_without_mutation():
    overrides = EMPTY_OVERRIDES + b"LAS,level_ok,owner decision,2026-10-20,chris\n"
    config, artifact = _fixture(overrides=overrides)
    original = deepcopy(artifact)
    raw = canonical_bytes(artifact)
    reviews = EMPTY_REVIEWS + b"LAS,3,reviewed,chris,explicit familiarity\n"
    output = parse_json(_run(artifact, config, overrides=overrides, words=("LAS",)).decode())
    row = output["unresolved"][0]
    assert row["source_tier"] == "level_ok"
    assert row["tier_reason"] == "override"
    assert row["source_frequency"] is None
    assert (
        row["evidence_sha256"]
        == hashlib.sha256(canonical_bytes(artifact["payload"]["records"][-1])).hexdigest()
    )
    reviewed = parse_json(
        _run(artifact, config, overrides=overrides, reviews=reviews, words=("LAS",)).decode()
    )
    assert reviewed["reviewed_familiarity_count"] == 1
    assert reviewed["unresolved"] == []
    assert artifact == original
    assert canonical_bytes(artifact) == raw


@pytest.mark.parametrize("words", [(None,), (1, "DOM"), ["DOM"]])
def test_malformed_candidate_types_fail_with_validation_error(words):
    config, artifact = _fixture()
    with pytest.raises(ValueError, match="Candidates"):
        _run(artifact, config, words=words)
