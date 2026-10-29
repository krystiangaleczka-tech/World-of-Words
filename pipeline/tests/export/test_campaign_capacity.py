"""Regression checks for the first 10,000-slot boundary and 30,000-slot target."""

from pathlib import Path

import pytest
from wordgame_pipeline.content_limits import (
    MAX_CAMPAIGN_SLOTS,
    pack_filename,
    validate_campaign_slots,
)
from wordgame_pipeline.validate import SchemaRegistry

PIPELINE = Path(__file__).resolve().parents[2]


def _manifest(first: int, last: int, filename: str) -> dict:
    return {
        "schema_version": 1,
        "lang": "pl",
        "content_version": 3,
        "pipeline": "0.1.0",
        "slots": last,
        "packs": [
            {
                "file": filename,
                "kind": "campaign",
                "first": first,
                "last": last,
                "sha256": "a" * 64,
            }
        ],
    }


def test_campaign_slot_boundaries_reject_bool_and_beyond_target() -> None:
    assert MAX_CAMPAIGN_SLOTS == 30_000
    for slots in (1, 9_999, 10_000, 10_001, 30_000):
        assert validate_campaign_slots(slots) == slots
    assert validate_campaign_slots(10_000, minimum=15) == 10_000
    for bad in (None, False, True, 0, -1, 1.0, "10000", 30_001):
        with pytest.raises(ValueError, match="Campaign slots"):
            validate_campaign_slots(bad)
    for bad in (None, 0, False, 30_001):
        with pytest.raises(ValueError, match="minimum"):
            validate_campaign_slots(100, minimum=bad)


@pytest.mark.parametrize(
    ("first", "last", "expected"),
    [
        (1, 100, "packs/c-0001-0100.json"),
        (9_901, 9_999, "packs/c-9901-9999.json"),
        (9_901, 10_000, "packs/c-9901-10000.json"),
        (10_001, 10_100, "packs/c-10001-10100.json"),
        (29_901, 30_000, "packs/c-29901-30000.json"),
    ],
)
def test_legacy_and_five_digit_pack_paths_round_trip(
    first: int, last: int, expected: str
) -> None:
    assert pack_filename(first, last) == expected
    SchemaRegistry(PIPELINE).validate_schema("manifest", _manifest(first, last, expected))


@pytest.mark.parametrize(
    ("first", "last"),
    [(0, 1), (1, 0), (10_001, 10_000), (1, 30_001), (30_001, 30_001)],
)
def test_invalid_pack_ranges_rejected(first: int, last: int) -> None:
    with pytest.raises(ValueError):
        pack_filename(first, last)


@pytest.mark.parametrize(
    "bad_filename",
    [
        "packs/c-00001-00100.json",
        "packs/c-100000-100001.json",
        "packs/c-10000-100000.json",
        "packs/c-10001-10100.json/../secret",
        "../packs/c-10001-10100.json",
        "packs/c-10001-10100.JSON",
        "packs/c-10001-10100.json\n",
    ],
)
def test_schema_rejects_unsafe_or_nonconforming_pack_paths(bad_filename: str) -> None:
    with pytest.raises(ValueError):
        SchemaRegistry(PIPELINE).validate_schema(
            "manifest", _manifest(10_001, 10_100, bad_filename)
        )


def test_shipped_legacy_manifest_remains_schema_compatible() -> None:
    import json

    manifest = json.loads((PIPELINE.parent / "game/content/pl/manifest.json").read_text())
    SchemaRegistry(PIPELINE).validate_schema("manifest", manifest)
    assert manifest["packs"][0]["file"] == pack_filename(1, 65)
