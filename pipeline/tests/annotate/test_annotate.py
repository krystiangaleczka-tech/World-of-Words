"""Offline annotation adapter tests; no optional native dependency is loaded."""

import copy
import gzip
import hashlib
import json
import shutil
from pathlib import Path
from types import ModuleType

import pytest
from wordgame_pipeline.annotate import make_handler
from wordgame_pipeline.annotate.core import annotate_words
from wordgame_pipeline.annotate.frequency import Frequency, parse_frequency
from wordgame_pipeline.annotate.native import load_native
from wordgame_pipeline.annotate.sources import load_frequency, load_pin, verify_engine
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import load_config
from wordgame_pipeline.ingest.source import load_pin as load_sjp_pin
from wordgame_pipeline.stages import run_build

PIPELINE = Path(__file__).parents[2]


class FakeAnalyzer:
    version = "1.99.15"
    dictionary_id = "pl.sgjp.sgjp-2026.06.01"

    def __init__(self, reversed_order=False):
        self.reversed_order = reversed_order

    def analyse(self, word):
        entries = {
            "domu": [
                (0, 1, ("do", "do", "prep:gen", [], [])),
                (1, 2, ("mu", "on", "ppron3:sg:dat", [], [])),
                (0, 2, ("domu", "dom:Sm3", "subst:sg:gen:m3", ["nazwa_pospolita"], [])),
            ],
            "kot": [
                (0, 1, ("kot", "kot:Sm1", "subst:sg:nom:m1", ["nazwa_pospolita"], ["pot."])),
                (0, 1, ("kot", "kot:Sm2", "subst:sg:nom:m2", ["nazwa_pospolita"], [])),
                (0, 1, ("kot", "kot:Sm2", "subst:sg:nom:m2", ["nazwa_pospolita"], [])),
            ],
            "kog": [(0, 1, ("kog", "kog", "ign", [], []))],
        }.get(word, [])
        return entries[::-1] if self.reversed_order else entries


def csv_bytes(kind, rows):
    header = ",freq,ipm,ARF,DP,DP_norm,1-DP,total_freq\n"
    if kind == "lemma":
        header = "," + header
    return gzip.compress((header + "".join(row + "\n" for row in rows)).encode(), mtime=0)


def workspace(root):
    (root / "sources").mkdir(parents=True)
    (root / "config").mkdir()
    for name in ("annotation-pl.json", "sjp-pl.json"):
        shutil.copyfile(PIPELINE / "sources" / name, root / "sources" / name)
    shutil.copyfile(PIPELINE / "config" / "pl.yaml", root / "config" / "pl.yaml")
    return load_config(root, "pl"), load_pin(root)


def test_frequency_sources_and_nullable_joins(tmp_path):
    config, pin = workspace(tmp_path)
    files = {
        "orth": csv_bytes("orth", ["kot,10,2,8,0,0,1,10", "tok,99,99,99,0,0,1,99"]),
        "lemma": csv_bytes("lemma", ["dom,subst,20,4,16,0,0,1,20"]),
    }
    for kind, raw in files.items():
        pin["frequency"]["files"][kind].update(
            bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest()
        )
    calls = []

    def fetch(url):
        calls.append(url)
        return files["orth" if "orth_lc" in url else "lemma"]

    forms = load_frequency(tmp_path, pin, "orth", fetch)
    lemmas = load_frequency(tmp_path, pin, "lemma", fetch)
    assert load_frequency(tmp_path, pin, "orth", fetch) == forms
    assert len(calls) == 2
    result = annotate_words(["DOMU", "KOG", "KOT"], config, FakeAnalyzer(), forms, lemmas)
    records = {record["word"]: record for record in result["records"]}
    assert records["KOT"]["frequency"] == {"arf": 8.0, "ipm": 2.0}
    assert records["KOT"]["analyses"][0]["frequency"] is None
    assert records["DOMU"]["frequency"] is None
    assert records["DOMU"]["analyses"][0]["frequency"] == {"arf": 16.0, "ipm": 4.0}
    for rows in (
        ["kot,1,NaN,2,0,0,1,1"],
        ["kot,1,1,-2,0,0,1,1"],
        ["kot,1,1,2,0,0,1,1"] * 2,
        ["kot,1"],
    ):
        with pytest.raises(ValueError):
            parse_frequency(csv_bytes("orth", rows), "orth")
    with pytest.raises(ValueError):
        parse_frequency(b"not gzip", "orth")
    cache = (
        tmp_path
        / "build"
        / "pl"
        / "sources"
        / f"kwjp-{pin['frequency']['files']['orth']['sha256']}.csv.gz"
    )
    cache.write_bytes(b"bad cache")
    with pytest.raises(ValueError, match="SHA256"):
        load_frequency(tmp_path, pin, "orth", fetch)
    assert cache.read_bytes() == b"bad cache"
    assert len(calls) == 2


def test_morphology_preserves_ambiguity_and_whole_word_identity(tmp_path):
    config, _pin = workspace(tmp_path)
    words = ["DOMU", "KOG", "KOT"]
    result = annotate_words(words, config, FakeAnalyzer(), {}, {})
    assert result == annotate_words(words, config, FakeAnalyzer(True), {}, {})
    doma, unknown, kot = result["records"]
    assert doma["analyses"][0]["lemma"] == "DOM"
    assert doma["analyses"][0]["lemma_raw"] == "dom:Sm3"
    assert doma["analyses"][0]["is_inflected"] is True
    assert doma["analyses"][0]["names"] == ["nazwa_pospolita"]
    assert len(doma["analyses"]) == 1, "partial DAG segments are not full-word evidence"
    assert unknown["analyses"] == [], "ign must not masquerade as a dictionary lemma"
    assert len(kot["analyses"]) == 2, "homonyms retained, duplicate interpretation removed"
    assert {entry["lemma_raw"] for entry in kot["analyses"]} == {"kot:Sm1", "kot:Sm2"}
    assert all(entry["is_inflected"] is False for entry in kot["analyses"])


def test_annotation_never_adds_valid_words_or_invents_eligibility(tmp_path):
    config, _pin = workspace(tmp_path)
    result = annotate_words(
        ["KOG", "KOT"], config, FakeAnalyzer(), {"tok": Frequency(100, 100)}, {}
    )
    assert [entry["word"] for entry in result["records"]] == ["KOG", "KOT"]
    assert result["coverage"] == {
        "source_forms": 2,
        "forms_with_lemma": 1,
        "forms_with_frequency": 0,
        "unique_lemmas": 1,
    }
    assert result["records"][0]["has_lemma_evidence"] is False
    assert all("tier" not in entry and "level_ok" not in entry for entry in result["records"])
    for words in (["KOT", "KOG"], ["KOT", "KOT"], ["kot"], ["QVX"]):
        with pytest.raises(ValueError):
            annotate_words(words, config, FakeAnalyzer(), {}, {})


def test_stage_artifacts_and_identity_failures(tmp_path):
    config, pin = workspace(tmp_path)
    analyzer = FakeAnalyzer()
    previous = {"source": load_sjp_pin(tmp_path).to_dict(), "words": ["DOMU", "KOG", "KOT"]}
    handlers = {name: lambda _cfg, _prior: previous for name in ("ingest", "normalize")}
    run_build(tmp_path, config, handlers, last="normalize")
    handlers["annotate"] = make_handler(tmp_path, analyzer, pin, {}, {})
    path = run_build(tmp_path, config, handlers, "annotate", "annotate")[0]
    original = path.read_bytes()
    run_build(tmp_path, config, handlers, "annotate", "annotate")
    assert path.read_bytes() == original
    payload = json.loads(original)["payload"]
    assert payload["source"] == previous["source"]
    assert payload["annotation_sources"] == pin
    analyzer.dictionary_id = "polimorf"
    with pytest.raises(ValueError, match="identity"):
        run_build(tmp_path, config, handlers, "annotate", "annotate")
    assert path.read_bytes() == original
    analyzer.dictionary_id = pin["morphology"]["dictionary_id"]
    analyzer.version = "999"
    with pytest.raises(ValueError, match="identity"):
        verify_engine(analyzer, pin)
    original_pin = copy.deepcopy(pin)
    for update in ({"commit": "26d82bd"}, {"repository": "https://example.com"}):
        altered = copy.deepcopy(original_pin)
        altered["frequency"].update(update)
        (tmp_path / "sources" / "annotation-pl.json").write_text(json.dumps(altered))
        with pytest.raises(ValueError):
            load_pin(tmp_path)


def test_native_loader_and_cli_registration(tmp_path, monkeypatch, capsys):
    import wordgame_pipeline.annotate as annotation

    config, pin = workspace(tmp_path)
    settings = []
    module = ModuleType("fixture_morfeusz")
    module.__version__ = "1.99.15"
    module.IGNORE_CASE = 99

    class Engine:
        def __init__(self, **kwargs):
            settings.append(kwargs)

        def dict_id(self):
            return pin["morphology"]["dictionary_id"]

        def analyse(self, word):
            return FakeAnalyzer().analyse(word)

    module.Morfeusz = Engine
    analyzer = load_native(pin, lambda _name: module)
    assert settings == [{"dict_name": "sgjp", "generate": False, "case_handling": 99}]
    assert analyzer.analyse("kot") == FakeAnalyzer().analyse("kot")

    def missing(_name):
        raise ImportError("not installed")

    with pytest.raises(ValueError, match="--extra annotate"):
        load_native(pin, missing)
    module.__version__ = "999"
    with pytest.raises(ValueError, match="version mismatch"):
        load_native(pin, lambda _name: module)
    assert len(settings) == 1, "version mismatch fails before constructing native engine"
    module.__version__ = "1.99.15"
    previous = {"source": load_sjp_pin(tmp_path).to_dict(), "words": ["DOMU", "KOT"]}
    handlers = {name: lambda _cfg, _prior: previous for name in ("ingest", "normalize")}
    run_build(tmp_path, config, handlers, last="normalize")
    calls = []
    monkeypatch.setattr(annotation, "load_native", lambda _pin: load_native(_pin, lambda _: module))
    monkeypatch.setattr(
        annotation, "load_frequency", lambda _root, _pin, kind: calls.append(kind) or {}
    )
    args = [
        "build",
        "--root",
        str(tmp_path),
        "--lang",
        "pl",
        "--from",
        "annotate",
        "--to",
        "annotate",
    ]
    assert main(args) == 0
    assert calls == ["orth", "lemma"]
    path = tmp_path / "build" / "pl" / "03-annotate" / "artifact.json"
    original = path.read_bytes()
    assert [entry["word"] for entry in json.loads(original)["payload"]["records"]] == [
        "DOMU",
        "KOT",
    ]
    calls.clear()
    module.__version__ = "999"
    assert main(args) == 1
    assert "version mismatch" in capsys.readouterr().err
    assert calls == [], "identity verification precedes source downloads"
    assert path.read_bytes() == original
