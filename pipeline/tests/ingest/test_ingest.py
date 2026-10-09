"""Offline tests use authored words and fixed ZIP metadata, never source downloads."""

import hashlib
import io
import json
import shutil
import subprocess
import sys
import zipfile
from dataclasses import replace
from pathlib import Path

import pytest
from wordgame_pipeline.cli import main
from wordgame_pipeline.config import load_config
from wordgame_pipeline.ingest import WordEntry, handlers_for, normalize_words
from wordgame_pipeline.ingest.source import download_archive, load_pin, read_words
from wordgame_pipeline.stages import run_build

PIPELINE = Path(__file__).parents[2]


def workspace(root: Path, words: tuple[str, ...] = ("kot", "żółć", "dom", "kot")):
    (root / "config").mkdir(parents=True)
    (root / "sources").mkdir()
    shutil.copyfile(PIPELINE / "config" / "pl.yaml", root / "config" / "pl.yaml")
    text = "\r\n".join(words).encode() + b"\r\n"
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr(zipfile.ZipInfo("slowa.txt", (2026, 9, 1, 0, 0, 0)), text)
        archive.writestr(zipfile.ZipInfo("../never-extracted", (2026, 9, 1, 0, 0, 0)), b"fixture")
    raw = buffer.getvalue()
    metadata = json.loads((PIPELINE / "sources" / "sjp-pl.json").read_text())
    metadata.update(
        sha256=hashlib.sha256(raw).hexdigest(),
        archive_bytes=len(raw),
        member_bytes=len(text),
        entry_count=len(words),
    )
    (root / "sources" / "sjp-pl.json").write_text(json.dumps(metadata), encoding="utf-8")
    return root, raw


def test_verified_download_cache_and_mismatch(tmp_path):
    root, raw = workspace(tmp_path)
    pin = load_pin(root)
    calls = []

    def fetch(url):
        calls.append(url)
        return raw

    path = download_archive(root, pin, fetch)
    assert path.read_bytes() == raw
    assert read_words(raw, pin) == ["kot", "żółć", "dom", "kot"]
    assert download_archive(root, pin, fetch) == path
    assert calls == [pin.url]
    assert not (root / "never-extracted").exists()
    for invalid_pin in (
        replace(pin, member_bytes=pin.member_bytes + 1),
        replace(pin, entry_count=999),
        replace(pin, sha256="0" * 64),
        replace(pin, archive_bytes=1),
        replace(pin, member="missing"),
    ):
        with pytest.raises(ValueError):
            read_words(raw, invalid_pin)
    invalid_utf8 = io.BytesIO()
    with zipfile.ZipFile(invalid_utf8, "w") as archive:
        archive.writestr(zipfile.ZipInfo("slowa.txt", (2026, 9, 1, 0, 0, 0)), b"\xff\n")
    bad_bytes = invalid_utf8.getvalue()
    bad_pin = replace(
        pin,
        sha256=hashlib.sha256(bad_bytes).hexdigest(),
        archive_bytes=len(bad_bytes),
        member_bytes=2,
        entry_count=1,
    )
    with pytest.raises(ValueError, match="archive/member"):
        read_words(bad_bytes, bad_pin)
    path.write_bytes(b"corrupt cache")
    with pytest.raises(ValueError, match="SHA256 mismatch"):
        download_archive(root, pin, fetch)
    assert path.read_bytes() == b"corrupt cache"
    assert len(calls) == 1
    path.unlink()
    with pytest.raises(ValueError):
        download_archive(root, pin, lambda _url: raw[:-1])
    assert not path.exists()
    metadata_path = root / "sources" / "sjp-pl.json"
    metadata = pin.to_dict()
    for update in (
        {"url": "https://example.com/archive"},
        {"member": "../slowa.txt"},
        {"entry_count": True},
        {"encoding": "latin-1"},
        {"license": "GPL-2.0"},
    ):
        metadata_path.write_text(json.dumps(metadata | update))
        with pytest.raises(ValueError):
            load_pin(root)


def test_normalization_rules_and_determinism(tmp_path):
    root, _raw = workspace(tmp_path)
    config = load_config(root, "pl")
    entries = [
        WordEntry("kot"),
        WordEntry("KOT"),
        WordEntry("z\u0307o\u0301łc\u0301"),
        WordEntry("las"),
        WordEntry("ŻÓŁĆ"),
        WordEntry("poker"),
        WordEntry("kasyno"),
        WordEntry("hazard"),
        WordEntry("baba"),
        WordEntry("a"),
        WordEntry("aaaaaaaaa"),
        WordEntry("qwerty"),
        WordEntry("vox"),
        WordEntry("kot!"),
        WordEntry(" straße "),
        WordEntry("straße"),
        WordEntry("ıkot"),
        WordEntry("ŁÓDŹ", proper_noun=True),
        WordEntry("USA", abbreviation=True),
    ]
    result = normalize_words(entries, config)
    assert result == normalize_words(reversed(entries), config)
    assert result["words"] == ["BABA", "HAZARD", "KASYNO", "KOT", "LAS", "POKER", "ŻÓŁĆ"]
    assert result["counts"]["source_entries"] == len(entries)
    assert result["counts"]["rejected"] == {
        "abbreviation": 1,
        "alphabet": 6,
        "duplicate": 2,
        "long": 1,
        "proper_noun": 1,
        "short": 1,
    }
    assert sum(result["counts"]["by_length"].values()) == len(result["words"])


def test_stage_cli_build_and_resume(tmp_path, capsys):
    root, raw = workspace(tmp_path)
    pin = load_pin(root)
    download_archive(root, pin, lambda _url: raw)
    args = ["build", "--lang", "pl", "--root", str(root), "--to", "normalize"]
    assert main(args) == 0
    paths = [
        root / "build" / "pl" / name / "artifact.json" for name in ("01-ingest", "02-normalize")
    ]
    original = [path.read_bytes() for path in paths]
    assert main(args) == 0
    assert [path.read_bytes() for path in paths] == original
    assert main([*args, "--from", "normalize"]) == 0
    assert [path.read_bytes() for path in paths] == original
    payload = json.loads(original[1])["payload"]
    assert payload["words"] == ["DOM", "KOT", "ŻÓŁĆ"]
    assert payload["source"] == pin.to_dict()
    assert payload["counts"]["source_entries"] == 4
    assert payload["counts"]["normalized_forms"] == 3
    assert payload["annotation"]["status"] == "pending_T-0122"
    result = subprocess.run(
        [sys.executable, "-m", "wordgame_pipeline.ingest", "--root", str(root)],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "build/pl/sources/sjp-20260901.zip"
    assert main([*args, "--to", "grid"]) == 1
    assert "grid is not implemented" in capsys.readouterr().err
    assert [path.read_bytes() for path in paths] == original
    metadata_path = root / "sources" / "sjp-pl.json"
    metadata_path.write_text(json.dumps(pin.to_dict() | {"entry_count": 5}))
    with pytest.raises(ValueError, match="source pin"):
        run_build(root, load_config(root, "pl"), handlers_for(root), "normalize", "normalize")
    assert paths[1].read_bytes() == original[1]


def test_no_unverified_level_candidates(tmp_path):
    root, _raw = workspace(tmp_path)
    config = load_config(root, "pl")
    result = normalize_words(
        [
            WordEntry("kot"),
            WordEntry("USA", abbreviation=True),
            WordEntry("ŁÓDŹ", proper_noun=True),
        ],
        config,
    )
    assert result["words"] == ["KOT"]
    assert result["annotation"]["verified_lemma_count"] == 0
    assert result["annotation"]["verified_level_candidate_count"] == 0
    assert result["annotation"]["status"] == "pending_T-0122"
    assert "tier" not in result
