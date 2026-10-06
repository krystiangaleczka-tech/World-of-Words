from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "tools/check_registries.py"


@pytest.fixture
def root(tmp_path: Path) -> Path:
    for area, filename in (("config", "hint.json"), ("analytics", "lifecycle.json")):
        schema = tmp_path / "game/services" / area / "registry.schema.json"
        schema.parent.mkdir(parents=True)
        shutil.copyfile(REPO / schema.relative_to(tmp_path), schema)
        data = tmp_path / "game/data" / area / filename
        data.parent.mkdir(parents=True)
        shutil.copyfile(REPO / data.relative_to(tmp_path), data)
    return tmp_path


def run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        text=True,
        capture_output=True,
        check=False,
    )


def source(root: Path, text: str, path: str = "game/features/example.gd") -> None:
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("extends Node\nfunc example():\n" + text, encoding="utf-8")


def mutate(root: Path, area: str, filename: str, action) -> None:
    path = root / "game/data" / area / filename
    document = json.loads(path.read_text())
    action(document)
    path.write_text(json.dumps(document), encoding="utf-8")


def test_shipped_registries_pass() -> None:
    result = run(REPO)
    assert result.returncode == 0, result.stderr
    assert "9 config keys, 4 events" in result.stdout


def test_valid_multiline_stringname_and_escaped_literals(root: Path) -> None:
    source(
        root,
        '\tAnalytics.track(\n\t\t&"app_boot"\n\t)\n'
        '\tConfig.get_int("hint.offer_idle_\\u0073econds")\n',
    )
    result = run(root)
    assert result.returncode == 0, result.stderr


@pytest.mark.parametrize(
    "call",
    [
        'Analytics.track("missing")',
        "Analytics.track(&'missing')",
        'Config.get_int("hint.missing")',
        'Config.get_float("hint.missing")',
        'Config.get_bool("hint.missing")',
        'Config.get_string("hint.missing")',
    ],
)
def test_unknown_literal_fails_with_file_and_line(root: Path, call: str) -> None:
    source(root, "\t" + call + "\n")
    result = run(root)
    assert result.returncode == 1
    assert "game/features/example.gd:3: unregistered" in result.stderr
    assert "missing" in result.stderr


def test_wrong_typed_getter_fails(root: Path) -> None:
    source(root, '\tConfig.get_bool("hint.offer_idle_seconds")\n')
    result = run(root)
    assert result.returncode == 1
    assert "wrong type" in result.stderr


def test_comments_strings_other_receivers_and_fixtures_are_ignored(root: Path) -> None:
    source(
        root,
        '\t# Analytics.track("missing")\n'
        "\tvar text = 'Config.get_int(\"hint.missing\")'\n"
        '\tvar multiline = """Analytics.track("missing")"""\n'
        '\tother.Analytics.track("missing")\n'
        '\tMyAnalytics.track("missing")\n',
    )
    for directory in ("tests/integration", "addons/vendor", ".godot/cache"):
        source(root, '\tAnalytics.track("missing")\n', f"game/{directory}/example.gd")
    result = run(root)
    assert result.returncode == 0, result.stderr


def test_dynamic_and_composed_arguments_are_left_to_runtime(root: Path) -> None:
    source(root, '\tAnalytics.track(event_name)\n\tConfig.get_int(prefix + ".price")\n')
    result = run(root)
    assert result.returncode == 0, result.stderr
    assert "2 dynamic calls checked at runtime" in result.stdout


def test_invalid_gdscript_fails_closed(root: Path) -> None:
    source(root, '\tAnalytics.track("app_boot"\n')
    result = run(root)
    assert result.returncode == 1
    assert "cannot parse source" in result.stderr


@pytest.mark.parametrize(
    "field,value",
    [
        ("type", "decimal"),
        ("default", True),
        ("default", 1.5),
        ("default", 901),
        ("range", [600, 10]),
        ("range", [10]),
        ("range", [10, "600"]),
        ("owner", " "),
        ("description", ""),
        ("remote", "false"),
        ("extra", 1),
    ],
)
def test_config_schema_and_runtime_invariants(root: Path, field: str, value) -> None:
    mutate(
        root,
        "config",
        "hint.json",
        lambda doc: doc["hint.offer_idle_seconds"].__setitem__(field, value),
    )
    result = run(root)
    assert result.returncode == 1
    assert "game/data/config/hint.json" in result.stderr


@pytest.mark.parametrize(
    "area,filename,text",
    [
        ("config", "hint.json", "[]"),
        ("analytics", "lifecycle.json", "{}"),
        ("analytics", "lifecycle.json", '{"event":{},"event":{}}'),
        ("config", "hint.json", '{"a":NaN}'),
        ("config", "hint.json", "{broken"),
    ],
)
def test_invalid_json_and_empty_registry(root: Path, area: str, filename: str, text: str) -> None:
    (root / "game/data" / area / filename).write_text(text)
    assert run(root).returncode == 1


@pytest.mark.parametrize("change", ["params", "description", "extra", "name"])
def test_analytics_schema_rejects_bad_definitions(root: Path, change: str) -> None:
    def action(doc):
        if change == "params":
            doc["app_boot"]["params"] = {"count": "integer"}
        elif change == "name":
            doc["BadEvent"] = doc.pop("app_boot")
        else:
            doc["app_boot"][change] = " "

    mutate(root, "analytics", "lifecycle.json", action)
    result = run(root)
    assert result.returncode == 1
    assert "game/data/analytics/lifecycle.json" in result.stderr


def test_duplicate_events_across_files(root: Path) -> None:
    directory = root / "game/data/analytics"
    shutil.copyfile(directory / "lifecycle.json", directory / "other.json")
    result = run(root)
    assert result.returncode == 1
    assert "duplicate registry name" in result.stderr


def test_config_filename_prefix_and_remote_unlocks(root: Path) -> None:
    path = root / "game/data/config/hint.json"
    path.rename(path.with_name("wrong.json"))
    assert "wrong filename prefix" in run(root).stderr
    path.with_name("wrong.json").rename(path)
    doc = json.loads(path.read_text())
    entry = doc["hint.offer_idle_seconds"]
    entry["remote"] = True
    (path.parent / "unlocks.json").write_text(json.dumps({"unlocks.hint_slot": entry}))
    assert "cannot be remote" in run(root).stderr


def test_missing_schema_or_registry_fails(root: Path) -> None:
    schema = root / "game/services/config/registry.schema.json"
    schema.unlink()
    assert run(root).returncode == 1
    shutil.copyfile(REPO / schema.relative_to(root), schema)
    (root / "game/data/config/hint.json").unlink()
    assert "no registry JSON files" in run(root).stderr


def test_schema_changes_are_applied_and_unknown_keywords_fail_closed(root: Path) -> None:
    path = root / "game/services/analytics/registry.schema.json"
    schema = json.loads(path.read_text())
    schema["minProperties"] = 100
    path.write_text(json.dumps(schema))
    assert "too few properties" in run(root).stderr
    schema.pop("minProperties")
    schema["additionalProperties"]["not"] = {}
    path.write_text(json.dumps(schema))
    assert "unsupported schema keywords: not" in run(root).stderr


@pytest.mark.parametrize("field", ["default", "type", "range", "description", "owner", "remote"])
def test_required_config_fields(root: Path, field: str) -> None:
    mutate(root, "config", "hint.json", lambda doc: doc["hint.offer_idle_seconds"].pop(field))
    result = run(root)
    assert result.returncode == 1
    assert f"missing {field}" in result.stderr


@pytest.mark.parametrize("number", [float("inf"), 9007199254740992, 10**400])
def test_nonfinite_and_unsafe_numbers_fail(root: Path, number) -> None:
    mutate(
        root,
        "config",
        "hint.json",
        lambda doc: doc["hint.offer_idle_seconds"].__setitem__("default", number),
    )
    assert run(root).returncode == 1


def test_all_config_types_and_integral_json_number_pass(root: Path) -> None:
    path = root / "game/data/config/hint.json"
    template = json.loads(path.read_text())["hint.offer_idle_seconds"]
    document = {}
    for name, kind, default, bounds in (
        ("integer", "int", 1.0, [0.0, 2.0]),
        ("decimal", "float", 1.5, [0, 2]),
        ("enabled", "bool", True, None),
        ("label", "string", "value", None),
    ):
        document[f"hint.{name}"] = {**template, "type": kind, "default": default, "range": bounds}
    path.write_text(json.dumps(document))
    source(
        root,
        '\tConfig.get_int("hint.integer")\n'
        '\tConfig.get_float("hint.decimal")\n'
        '\tConfig.get_bool("hint.enabled")\n'
        '\tConfig.get_string("hint.label")\n',
    )
    result = run(root)
    assert result.returncode == 0, result.stderr
