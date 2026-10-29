"""Pinned source metadata can be audited offline without API calls."""

import json
import shutil
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest
from wordgame_pipeline.annotate.fingerprint import fingerprint_annotation_sources

PIPELINE = Path(__file__).resolve().parents[2]


def pin(tmp_path):
    folder = tmp_path / "sources"
    folder.mkdir()
    shutil.copyfile(PIPELINE / "sources/annotation-pl.json", folder / "annotation-pl.json")
    return folder / "annotation-pl.json"


def test_deterministic_hash_and_dictionary_identity(tmp_path):
    path = pin(tmp_path)
    before = path.read_bytes()
    first = fingerprint_annotation_sources(tmp_path)
    assert first == fingerprint_annotation_sources(tmp_path)
    assert len(first.frequency_commit) == 40
    assert len(first.manifest_sha256) == 64
    assert first.dictionary_id.startswith("pl.sgjp.sgjp-")
    assert path.read_bytes() == before
    with pytest.raises(FrozenInstanceError):
        first.dictionary_id = "wrong"


def test_changed_pin_digest_and_invalid_source_rejection(tmp_path):
    path = pin(tmp_path)
    original = fingerprint_annotation_sources(tmp_path)
    data = json.loads(path.read_text())
    data["frequency"]["commit"] = "a" * 40
    path.write_text(json.dumps(data))
    assert fingerprint_annotation_sources(tmp_path).manifest_sha256 != original.manifest_sha256
    data["frequency"]["license"] = "wrong"
    path.write_text(json.dumps(data))
    with pytest.raises(ValueError):
        fingerprint_annotation_sources(tmp_path)


def test_bad_root_and_missing_file(tmp_path):
    with pytest.raises(FileNotFoundError):
        fingerprint_annotation_sources(tmp_path)
    with pytest.raises(ValueError):
        fingerprint_annotation_sources(None)
