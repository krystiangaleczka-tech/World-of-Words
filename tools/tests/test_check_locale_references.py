"""Bounded source references and named travel-copy evidence, without execution."""

import json
import shutil
import subprocess
import sys

import pytest

from tools.check_locale_references import ROOT, audit


def fixture(root):
    for name in ("game/features", "game/ui", "game/services", "game/locale", "game/content/pl"):
        (root / name).mkdir(parents=True, exist_ok=True)
    (root / "game/locale/probe.csv").write_text(
        "keys,pl,en\nprobe.main.title,Tytuł,Title\n", encoding="utf-8"
    )
    manifest(root, {})
    return root


def manifest(root, value):
    (root / "game/content/pl/manifest.json").write_text(json.dumps(value), encoding="utf-8")


def script(root, body):
    path = root / "game/features/probe.gd"
    path.write_text("extends Control\nfunc run() -> void:\n\t" + body + "\n", encoding="utf-8")
    return path


@pytest.mark.parametrize(
    "body",
    [
        'var copy = tr("probe.main.title")',
        'var copy = TranslationServer.translate("probe.main.title")',
        'var values = {"title": "probe.main.title"}',
        'row.title_key = "probe.main.title"',
        'row.a11y_label_key = &"probe.main.title"',
        'row.text_key = ""',
        'var value = "unrelated.data.identifier"',
        '# tr("probe.main.missing")',
    ],
)
def test_valid_key_contexts_optional_empty_and_nonkey_literals(tmp_path, body):
    root = fixture(tmp_path)
    script(root, body)
    assert audit(root)["errors"] == []


@pytest.mark.parametrize(
    "body",
    [
        'var copy = tr("absent.main.title")',
        'var copy = tr("")',
        'var copy = TranslationServer.translate("absent.main.title")',
        'var values = {"title": "probe.main.missing"}',
        'row.title_key = "absent.main.title"',
        'row.a11y_label_key = &"absent.main.title"',
        'row.text_key = "Tyop"',
    ],
)
def test_missing_keys_fail_in_calls_maps_and_explicit_ui_fields(tmp_path, body):
    root = fixture(tmp_path)
    script(root, body)
    report = audit(root)
    assert any("game/features/probe.gd:3: unknown translation key" in e for e in report["errors"])


def test_typed_class_key_declaration_and_dynamic_families(tmp_path):
    root = fixture(tmp_path)
    path = script(root, 'var key = "probe.main." + str(state)')
    report = audit(root)
    assert report["errors"] == []
    assert report["dynamic"] == [
        dict(path="game/features/probe.gd", line=3, expression="probe.main.")
    ]
    path.write_text('extends Control\nvar title_key: String = "absent.main.title"\n')
    assert audit(root)["errors"]


@pytest.mark.parametrize("key", ['"probe.main.missing"', '&"absent.main.title"', '"Literal"', "42"])
def test_scene_ui_key_fields_are_checked(tmp_path, key):
    root = fixture(tmp_path)
    path = root / "game/features/probe.tscn"
    path.write_text(
        '[gd_scene format=3]\n[node name="Root" type="Control"]\ntitle_key = ' + key + "\n"
    )
    assert audit(root)["errors"]
    path.write_text(
        '[gd_scene format=3]\n[node name="Root" type="Label"]\ntext = "probe.main.title"\n'
    )
    assert audit(root)["errors"] == []


@pytest.mark.parametrize("failure", ["parse", "encoding", "scope", "catalog", "manifest", "json"])
def test_unreadable_malformed_and_missing_inputs_fail_closed(tmp_path, failure):
    root = fixture(tmp_path)
    path = script(root, "pass")
    if failure == "parse":
        path.write_text("func ( invalid:\n")
    elif failure == "encoding":
        path.write_bytes(b"\xff")
    elif failure == "scope":
        shutil.rmtree(root / "game/ui")
    elif failure == "catalog":
        (root / "game/locale/probe.csv").unlink()
        with pytest.raises(ValueError):
            audit(root)
        return
    elif failure == "manifest":
        (root / "game/content/pl/manifest.json").unlink()
    elif failure == "json":
        (root / "game/content/pl/manifest.json").write_text("not json")
    assert audit(root)["errors"]


def named():
    return {
        "regions": [{"name_key": "probe.main.title"}],
        "locations": [{"id": "one", "name_key": "probe.main.title"}],
        "landmarks": [],
    }


def test_legacy_named_and_pending_or_available_fact_metadata(tmp_path):
    root = fixture(tmp_path)
    assert audit(root)["metadata"][0]["legacy"]
    manifest(root, named())
    report = audit(root)
    assert report["errors"] == []
    assert not report["metadata"][0]["legacy"]
    assert report["metadata"][0]["pending_facts"] == ["location.one.fact"]
    (root / "game/locale/location.csv").write_text("keys,pl,en\nlocation.one.fact,Fakt,Fact\n")
    report = audit(root)
    assert report["errors"] == []
    assert report["metadata"][0]["named_locations"] == 1
    assert report["metadata"][0]["pending_facts"] == []
    assert any(r["key"] == "location.one.fact" for r in report["references"])


@pytest.mark.parametrize(
    "value",
    [
        [],
        {"regions": []},
        {"regions": [], "locations": [], "landmarks": []},
        {"regions": {}, "locations": [], "landmarks": []},
        {"regions": [{}], "locations": [], "landmarks": []},
        {"regions": [{"name_key": 1}], "locations": [], "landmarks": []},
    ],
)
def test_malformed_named_metadata_fails(tmp_path, value):
    root = fixture(tmp_path)
    manifest(root, value)
    assert audit(root)["errors"]


@pytest.mark.parametrize(
    "field,value", [("name_key", ""), ("name_key", "missing.main.name"), ("id", 1), ("id", "")]
)
def test_missing_named_copy_or_location_identity_fails(tmp_path, field, value):
    root = fixture(tmp_path)
    data = named()
    data["locations"][0][field] = value
    manifest(root, data)
    assert audit(root)["errors"]


def test_actual_repository_has_valid_static_references():
    report = audit(ROOT)
    assert report["errors"] == []
    assert report["references"] and report["dynamic"]
    assert report["keys"] > 0


def test_fixture_report_is_deterministic_and_diagnostics_are_sorted(tmp_path):
    root = fixture(tmp_path)
    script(root, 'var values = ["probe.main.zzz", "probe.main.aaa"]')
    report = audit(root)
    assert report == audit(root)
    assert report["errors"] == sorted(report["errors"])
    assert [r["key"] for r in report["references"]] == ["probe.main.aaa", "probe.main.zzz"]


def test_cli_from_other_cwd_no_writes_and_nonzero_failure(tmp_path):
    root = fixture(tmp_path)
    script(root, 'row.text_key = "missing.main.title"')
    before = {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
    command = [sys.executable, str(ROOT / "tools/check_locale_references.py")]
    failed = subprocess.run(
        command + ["--root", str(root), "--json"], cwd=tmp_path, capture_output=True, text=True
    )
    assert failed.returncode == 1
    assert json.loads(failed.stdout)["errors"]
    assert before == {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
    good = subprocess.run(command + ["--json"], cwd=tmp_path, capture_output=True, text=True)
    assert good.returncode == 0, good.stderr
    assert not json.loads(good.stdout)["errors"]
