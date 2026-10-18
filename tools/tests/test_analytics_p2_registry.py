"""Independent product coverage and runtime/schema naming parity, without provider/network calls."""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from tools import check_registries

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "game/services/analytics/registry.schema.json"
GD_PATH = ROOT / "game/services/analytics/analytics_registry.gd"


def _gd_pattern(name: str) -> str:
    match = re.search(rf"const {name}: String = \((.*?)\n\)", GD_PATH.read_text(), re.DOTALL)
    assert match is not None
    return "".join(
        json.loads('"' + part + '"') for part in re.findall(r'"([^"\n]*)"', match.group(1))
    )


def test_catalog_is_exact_product_core_event_seed_once() -> None:
    product = (ROOT / "docs/PRODUCT.md").read_text()
    table = product.split("### Core events (seed of the registry)", 1)[1].split("### Funnels", 1)[0]
    names = re.findall(
        r"`([a-z][a-z0-9_]*)`",
        "\n".join(line for line in table.splitlines() if line.startswith("|")),
    )
    assert len(names) == len(set(names)) == 48
    registry, errors = check_registries.load_registry(ROOT, "analytics")
    assert errors == []
    assert set(registry) == set(names)
    assert registry["content_load_failed"]["params"] == {"error_code": "int"}
    assert registry["invalid_word_submitted"]["params"] == {
        "language": "string",
        "slot": "int",
        "letters": "string",
    }


def test_existing_lifecycle_contract_remains_exact() -> None:
    lifecycle = json.loads((ROOT / "game/data/analytics/lifecycle.json").read_text())
    assert lifecycle == {
        "app_boot": {"params": {}, "description": "Application process boot"},
        "app_foreground": {"params": {}, "description": "Application returns to foreground"},
        "app_background": {"params": {}, "description": "Application moves to background"},
        "nav_screen": {"params": {"screen": "string"}, "description": "Navigation enters a screen"},
    }


def test_runtime_schema_provider_pattern_parity_and_boundaries() -> None:
    schema = json.loads(SCHEMA_PATH.read_text())
    check_registries.check_schema(schema)
    assert _gd_pattern("EVENT_NAME_PATTERN") == schema["propertyNames"]["pattern"]
    assert (
        _gd_pattern("PARAM_NAME_PATTERN")
        == schema["additionalProperties"]["properties"]["params"]["propertyNames"]["pattern"]
    )
    for name in ["a" * 40, "level_complete", "ad_shown", "iap_purchase_completed"]:
        assert (
            check_registries.schema_errors({name: {"params": {}, "description": "Fixture"}}, schema)
            == []
        )
    for name in [
        "a" * 41,
        "first_open",
        "session_start",
        "screen_view",
        "error",
        "ad_impression",
        "firebase_event",
        "google_event",
        "ga_event",
        "fixture\n",
    ]:
        assert check_registries.schema_errors(
            {name: {"params": {}, "description": "Fixture"}}, schema
        )


@pytest.mark.parametrize(
    "name",
    [
        "currency",
        "user_id",
        "session_id",
        "firebase_param",
        "google_param",
        "ga_param",
        "_private",
        "a" * 41,
        "param\n",
    ],
)
def test_provider_reserved_custom_parameters_are_rejected(name: str) -> None:
    schema = json.loads(SCHEMA_PATH.read_text())
    assert check_registries.schema_errors(
        {"fixture": {"params": {name: "string"}, "description": "Fixture"}}, schema
    )
