"""Offline source pin fingerprint regression, no network required."""

import json
import shutil
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.ingest.fingerprint import fingerprint_source

PIPELINE = Path(__file__).resolve().parents[2]


def pin(tmp_path):
    target = tmp_path / "sources"
    target.mkdir()
    shutil.copyfile(PIPELINE / "sources/sjp-pl.json", target / "sjp-pl.json")
    return target / "sjp-pl.json"


def test_stable_source_pin_and_readonly(tmp_path):
    path = pin(tmp_path)
    before = path.read_bytes()
    first = fingerprint_source(tmp_path)
    assert first == fingerprint_source(tmp_path)
    assert len(first.manifest_sha256) == 64
    assert len(first.archive_sha256) == 64
    assert first.license == "CC-BY-4.0"
    assert path.read_bytes() == before
    with pytest.raises(FrozenInstanceError):
        first.version = "other"


def test_pin_change_or_unapproved_provenance_rejected(tmp_path):
    path = pin(tmp_path)
    data = json.loads(path.read_text())
    data["version"] = "20010101"
    path.write_text(json.dumps(data))
    with pytest.raises(ValueError):
        fingerprint_source(tmp_path)
    data["version"] = path.name
    data["license"] = "unknown"
    path.write_text(json.dumps(data))
    with pytest.raises(ValueError):
        fingerprint_source(tmp_path)


def test_missing_root_and_wrong_type(tmp_path):
    with pytest.raises(FileNotFoundError):
        fingerprint_source(tmp_path)
    with pytest.raises(ValueError):
        fingerprint_source("bad")
