"""Additive manifest structure and semantic partitions; generated content stays untouched."""

import copy
import json
from pathlib import Path

import pytest
from wordgame_pipeline.config import canonical_bytes
from wordgame_pipeline.content import bundle
from wordgame_pipeline.validate.manifest import validate_manifest_metadata
from wordgame_pipeline.validate.schema import SchemaRegistry

ROOT = Path(__file__).resolve().parents[1]


def manifest():
    value = json.loads((ROOT.parent / "game/tests/fixtures/content/pl/manifest.json").read_text())
    value.update(
        regions=[dict(id="r01", name_key="journey.region.r01", first=1, last=3)],
        locations=[
            dict(
                id="r01-l01",
                region="r01",
                name_key="journey.location.r01_l01",
                first=1,
                last=2,
                postcard="postcards/r01-l01.webp",
                pieces=4,
            ),
            dict(
                id="r01-l02",
                region="r01",
                name_key="journey.location.r01_l02",
                first=3,
                last=3,
                postcard="postcards/r01-l02.webp",
                pieces=4,
            ),
        ],
        landmarks=[dict(slot=2, landmark=True)],
    )
    return value


def validate(value):
    SchemaRegistry(ROOT).validate_schema("manifest", value)
    validate_manifest_metadata(value)


def test_additive_metadata_p1_compatibility_integral_numbers_and_no_mutation():
    value = manifest()
    before = copy.deepcopy(value)
    validate(value)
    assert value == before
    value["locations"][0]["pieces"] = 4.0
    value["regions"][0]["last"] = 3.0
    value["landmarks"][0]["slot"] = 2.0
    validate(value)
    for key in ("regions", "locations", "landmarks"):
        del value[key]
    validate(value)
    validate(json.loads((ROOT.parent / "game/content/pl/manifest.json").read_text()))


@pytest.mark.parametrize(
    "case",
    [
        "partial",
        "empty",
        "gap",
        "overlap",
        "duplicate-id",
        "unknown-region",
        "region-crossing",
        "bad-pieces",
        "bad-path",
        "bad-key",
        "unknown-field",
        "duplicate-landmark",
        "invalid-flag",
        "landmark-outside",
        "boolean-count",
        "fraction",
    ],
)
def test_structural_and_semantic_rejection(case):
    value = manifest()
    if case == "partial":
        del value["landmarks"]
    elif case == "empty":
        value["regions"] = []
    elif case == "gap":
        value["locations"][1]["first"] = 4
    elif case == "overlap":
        value["locations"][1]["first"] = 2
    elif case == "duplicate-id":
        value["locations"][1]["id"] = "r01-l01"
    elif case == "unknown-region":
        value["locations"][0]["region"] = "absent"
    elif case == "region-crossing":
        value["regions"][0]["last"] = 1
        value["regions"].append(dict(id="r02", name_key="journey.region.r02", first=2, last=3))
    elif case == "bad-pieces":
        value["locations"][0]["pieces"] = 0
    elif case == "bad-path":
        value["locations"][0]["postcard"] = "postcards/../outside.webp"
    elif case == "bad-key":
        value["regions"][0]["name_key"] = "ui.unknown"
    elif case == "unknown-field":
        value["regions"][0]["extra"] = True
    elif case == "duplicate-landmark":
        value["landmarks"].append(value["landmarks"][0].copy())
    elif case == "invalid-flag":
        value["landmarks"][0]["landmark"] = 1
    elif case == "landmark-outside":
        value["landmarks"][0]["slot"] = 4
    elif case == "boolean-count":
        value["locations"][0]["first"] = True
    elif case == "fraction":
        value["locations"][0]["pieces"] = 1.5
    with pytest.raises(ValueError):
        validate(value)


def test_content_bundle_runs_semantic_gate_before_pack_io(tmp_path):
    value = manifest()
    value["locations"][1]["first"] = 2
    (tmp_path / "manifest.json").write_bytes(canonical_bytes(value))
    with pytest.raises(ValueError, match="gaps, overlaps"):
        bundle(tmp_path, SchemaRegistry(ROOT))
