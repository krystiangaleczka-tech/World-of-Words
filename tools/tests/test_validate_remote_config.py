from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools/validate_remote_config.py"
DEFAULT = {"version": 1, "values": {}, "experiments": []}


@pytest.fixture
def workspace(tmp_path: Path) -> tuple[Path, Path]:
    registry = tmp_path / "registry"
    registry.mkdir()
    (registry / "ads.json").write_text(
        json.dumps(
            {
                "ads.interstitial.min_levels_between": {
                    "type": "int",
                    "range": [1, 20],
                    "remote": True,
                },
                "ads.interstitial.first_slot": {
                    "type": "int",
                    "range": [1, 200],
                    "remote": False,
                },
            }
        ),
        encoding="utf-8",
    )
    (registry / "consent.json").write_text(
        json.dumps({"consent.att_after_slot": {"type": "int", "remote": False}}),
        encoding="utf-8",
    )
    return tmp_path / "remote.json", registry


def check(config: Path, registry: Path, document: object) -> subprocess.CompletedProcess[str]:
    config.write_text(json.dumps(document), encoding="utf-8")
    return subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--config",
            str(config),
            "--registry-dir",
            str(registry),
        ],
        capture_output=True,
        text=True,
        check=False,
    )


def valid_experiment() -> dict[str, object]:
    return {
        "id": "ad_frequency",
        "variants": [
            {"id": "control", "weight": 50},
            {"id": "variant", "weight": 50},
        ],
    }


def test_shipped_document_passes() -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--config", str(ROOT / "remote/config.json"),
         "--registry-dir", str(ROOT / "game/data/config")],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr


def test_empty_config_is_safe(workspace: tuple[Path, Path]) -> None:
    config, registry = workspace
    assert check(config, registry, DEFAULT).returncode == 0


def test_valid_override_and_weighted_experiment(workspace: tuple[Path, Path]) -> None:
    config, registry = workspace
    document = {
        "version": 1,
        "values": {"ads.interstitial.min_levels_between": 6},
        "experiments": [valid_experiment()],
    }
    assert check(config, registry, document).returncode == 0


@pytest.mark.parametrize(
    ("key", "value", "message"),
    [
        ("ads.interstitial.first_slot", 3, "not remotely tunable"),
        ("consent.att_after_slot", 1, "not remotely tunable"),
        ("unlocks.hint_slot", 2, "unknown override"),
        ("ads.interstitial.min_levels_between", True, "invalid type or range"),
        ("ads.interstitial.min_levels_between", 6.0, "invalid type or range"),
        ("ads.interstitial.min_levels_between", 0, "invalid type or range"),
        ("ads.interstitial.min_levels_between", 21, "invalid type or range"),
    ],
)
def test_rejects_unsafe_overrides(
    workspace: tuple[Path, Path], key: str, value: object, message: str
) -> None:
    config, registry = workspace
    document = {**DEFAULT, "values": {key: value}}
    result = check(config, registry, document)
    assert result.returncode == 1
    assert message in result.stderr


@pytest.mark.parametrize(
    "document",
    [
        [],
        {},
        {"version": True, "values": {}, "experiments": []},
        {"version": 2, "values": {}, "experiments": []},
        {**DEFAULT, "extra": "not in v1"},
        {**DEFAULT, "values": []},
        {**DEFAULT, "experiments": {}},
        {**DEFAULT, "experiments": [valid_experiment()] * 33},
        {
            **DEFAULT,
            "experiments": [
                valid_experiment(),
                valid_experiment(),
            ],
        },
        {
            **DEFAULT,
            "experiments": [
                {"id": "Bad-Name", "variants": [{"id": "control", "weight": 100}]}
            ],
        },
        {
            **DEFAULT,
            "experiments": [
                {"id": "ad_frequency", "variants": [{"id": "control", "weight": 99}]}
            ],
        },
        {
            **DEFAULT,
            "experiments": [
                {"id": "ad_frequency", "variants": [
                    {"id": "control", "weight": True},
                    {"id": "control", "weight": 100},
                ]}
            ],
        },
    ],
)
def test_invalid_envelopes_or_experiments_fail(
    workspace: tuple[Path, Path], document: object
) -> None:
    config, registry = workspace
    assert check(config, registry, document).returncode == 1


@pytest.mark.parametrize(
    "content",
    [
        '{"version":1,"version":1,"values":{},"experiments":[]}',
        '{"version":1,"values":{"x":1,"x":2},"experiments":[]}',
        '{"version":1,"values":{},"experiments":[{"id":"x","variants":[{"id":"c","weight":NaN}]}]}',
        "not json",
    ],
)
def test_malformed_or_duplicate_json_fails(
    workspace: tuple[Path, Path], content: str
) -> None:
    config, registry = workspace
    config.write_text(content, encoding="utf-8")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--config", str(config),
         "--registry-dir", str(registry)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 1


def test_oversized_remote_document_is_rejected(workspace: tuple[Path, Path]) -> None:
    config, registry = workspace
    config.write_bytes(b" " * 65537)
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--config", str(config),
         "--registry-dir", str(registry)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 1
    assert "exceeds" in result.stderr
