"""Authored evidence tests; no native engine or corpus downloads."""

import copy
import json
import shutil
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.annotate.sources import load_pin as annotation_pin
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import TierRules, canonical_bytes, load_config
from wordgame_pipeline.ingest.source import load_pin as source_pin
from wordgame_pipeline.stages import run_build
from wordgame_pipeline.tiers import handlers_for
from wordgame_pipeline.tiers.core import assign_tiers, parse_overrides

PIPELINE = Path(__file__).parents[2]
HEADER = "word,tier,reason,date,by\n"


def workspace(root):
    for folder in ("config", "sources", "overrides"):
        (root / folder).mkdir(parents=True)
    shutil.copyfile(PIPELINE / "config/pl.yaml", root / "config/pl.yaml")
    for name in ("annotation-pl.json", "sjp-pl.json"):
        shutil.copyfile(PIPELINE / "sources" / name, root / "sources" / name)
    (root / "overrides/pl.csv").write_text(HEADER)
    return load_config(root, "pl")


def row(word, form=None, lemma=None, inflected=False, names=(), labels=(), pos="subst", own=None):
    analysis = {
        "lemma": lemma or word,
        "lemma_raw": (lemma or word).lower(),
        "pos": pos,
        "tag": pos + ":sg",
        "names": list(names),
        "labels": list(labels),
        "is_inflected": inflected,
        "frequency": None if own is None else {"arf": own, "ipm": 1},
    }
    return {
        "word": word,
        "frequency": None if form is None else {"arf": form, "ipm": 1},
        "analyses": [analysis],
        "has_lemma_evidence": True,
    }


def test_base_inflection_nullable_and_ambiguity(tmp_path):
    config = workspace(tmp_path)
    records = [
        row("CUD", own=10),
        row("DOMU", 99, "DOM", True),
        row("DOMY", 100, "DOM", True),
        row("KOT", 10),
        row("LAS", 9),
        row("RZEKA", 1000, labels=("daw.",)),
        row("TOK"),
    ]
    unknown = row("KOG", 1000)
    unknown.update(analyses=[], has_lemma_evidence=False)
    records.append(unknown)
    records.sort(key=lambda r: r["word"])
    original = copy.deepcopy(records)
    result = assign_tiers(records, config, {})
    assert records == original
    tiers = {r["word"]: r["tier"] for r in result["records"]}
    assert tiers == {
        "CUD": "level_ok",
        "DOMU": "bonus_ok",
        "DOMY": "level_ok",
        "KOG": "bonus_ok",
        "KOT": "level_ok",
        "LAS": "bonus_ok",
        "RZEKA": "bonus_ok",
        "TOK": "bonus_ok",
    }
    word = row("KOT", 10, names=("nazwisko",))
    word["analyses"].append(row("KOT", names=("nazwa_pospolita",))["analyses"][0])
    assert assign_tiers([word], config, {})["records"][0]["tier"] == "level_ok"
    inflection = row("DOMU", lemma="DOM", inflected=True, own=100000)
    assert assign_tiers([inflection], config, {})["records"][0]["tier"] == "bonus_ok"

    ign = row("KOG", 1000, pos="ign")
    assert assign_tiers([ign], config, {})["records"][0]["tier"] == "bonus_ok"


def test_banned_evidence_and_override_precedence(tmp_path):
    config = workspace(tmp_path)
    records = [
        row("JAN", 1000, names=("imię",)),
        row("KOT", 1000, labels=("wulg.",)),
        row("USA", 1000, pos="brev"),
    ]
    result = assign_tiers(records, config, {})
    assert result["tier_counts"] == {"level_ok": 0, "bonus_ok": 0, "banned": 3}
    decisions = (
        "KOT,bonus_ok,reviewed homonym,2026-10-09,chris\n"
        "KOT,banned,initial,2026-10-01,chris\n"
        "TOK,banned,unused,2026-10-09,chris\n"
    )
    overrides = parse_overrides(HEADER + decisions, config)
    assert overrides == parse_overrides(
        HEADER + "\n".join(reversed(decisions.splitlines())) + "\n", config
    )
    result = assign_tiers(records, config, overrides)
    assert [r["word"] for r in result["records"]] == ["JAN", "KOT", "USA"]
    assert result["records"][1]["tier"] == "bonus_ok"
    assert result["unmatched_overrides"][0]["word"] == "TOK"
    unknown = row("KOT")
    unknown.update(analyses=[], has_lemma_evidence=False)
    promote = parse_overrides(HEADER + "KOT,level_ok,reviewed,2026-10-09,chris\n", config)
    with pytest.raises(ValueError, match="lemma"):
        assign_tiers([unknown], config, promote)
    with pytest.raises(ValueError, match="lemma"):
        assign_tiers([row("KOT", pos="ign")], config, promote)
    for text in (
        "word,tier\nKOT,banned\n",
        HEADER + "kot,banned,bad,2026-10-09,chris\n",
        HEADER + "KOT,other,bad,2026-10-09,chris\n",
        HEADER + "KOT,banned,,2026-10-09,chris\n",
        HEADER + "KOT,banned,bad,20261009,chris\n",
        HEADER + "KOT,banned,first,2026-10-09,chris\nKOT,bonus_ok,second,2026-10-09,chris\n",
    ):
        with pytest.raises(ValueError):
            parse_overrides(text, config)


def test_config_and_input_validation(tmp_path):
    config = workspace(tmp_path)
    with pytest.raises(FrozenInstanceError):
        config.tier_rules.base_min_arf = 999
    path = tmp_path / "config/pl.yaml"
    original = json.loads(path.read_text())
    for value in (-1, True, "10", None):
        malformed = copy.deepcopy(original)
        malformed["tier_rules"]["base_min_arf"] = value
        path.write_text(json.dumps(malformed))
        with pytest.raises(ValueError):
            load_config(tmp_path, "pl")
    rules = {
        "base_min_arf": float("inf"),
        "inflected_min_arf": 100,
        "banned_labels": [],
        "excluded_level_labels": [],
    }
    with pytest.raises(ValueError):
        TierRules.from_dict(rules)
    legacy = original.copy()
    del legacy["tier_rules"]
    path.write_text(json.dumps(legacy))
    assert load_config(tmp_path, "pl").to_dict() == legacy
    for records in ([row("kot")], [row("KOT"), row("KOT")], [row("TOK"), row("KOT")]):
        with pytest.raises(ValueError):
            assign_tiers(records, config, {})
    for mutate in (
        lambda r: r.update(frequency={"arf": -1, "ipm": 0}),
        lambda r: r["analyses"][0].update(is_inflected=True),
        lambda r: r["analyses"][0].update(names="bad"),
        lambda r: r.update(has_lemma_evidence=False),
        lambda r: r["analyses"][0].update(lemma_raw="pies"),
        lambda r: r.pop("frequency"),
        lambda r: r["analyses"][0].pop("frequency"),
    ):
        record = row("KOT")
        mutate(record)
        with pytest.raises(ValueError):
            assign_tiers([record], config, {})


def test_stage_repeat_override_change_and_failure_atomicity(tmp_path, capsys):
    config = workspace(tmp_path)
    previous = {
        "source": source_pin(tmp_path).to_dict(),
        "annotation_sources": annotation_pin(tmp_path),
        "records": [row("KOT", 10)],
    }
    fake = {name: lambda _cfg, _prior: previous for name in ("ingest", "normalize", "annotate")}
    run_build(tmp_path, config, fake, last="annotate")
    handlers = handlers_for(tmp_path)
    path = run_build(tmp_path, config, handlers, "tiers", "tiers")[0]
    original = path.read_bytes()
    run_build(tmp_path, config, handlers, "tiers", "tiers")
    assert path.read_bytes() == original
    payload = json.loads(original)["payload"]
    assert payload["source"] == previous["source"]
    assert payload["tier_counts"]["level_ok"] == 1
    assert (
        main(["build", "--root", str(tmp_path), "--lang", "pl", "--from", "tiers", "--to", "tiers"])
        == 0
    )
    overrides = tmp_path / "overrides/pl.csv"
    overrides.write_text(HEADER + "KOT,banned,reviewed,2026-10-09,chris\n")
    run_build(tmp_path, config, handlers, "tiers", "tiers")
    changed = path.read_bytes()
    assert changed != original
    assert json.loads(changed)["payload"]["records"][0]["tier"] == "banned"
    overrides.write_text("bad header\n")
    with pytest.raises(ValueError):
        run_build(tmp_path, config, handlers, "tiers", "tiers")
    assert path.read_bytes() == changed
    overrides.write_text(HEADER)
    previous["annotation_sources"]["morphology"]["version"] = "999"
    run_build(tmp_path, config, fake, last="annotate")
    with pytest.raises(ValueError, match="provenance"):
        run_build(tmp_path, config, handlers, "tiers", "tiers")
    assert path.read_bytes() == changed
    assert main(["build", "--root", str(tmp_path), "--lang", "pl", "--to", "grid"]) == 1
    assert "grid is not implemented" in capsys.readouterr().err
    assert canonical_bytes(json.loads(changed)) == changed
