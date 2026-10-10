from __future__ import annotations

import hashlib
import json
import struct
import subprocess
import zipfile
from pathlib import Path

import pytest

from tools.check_release_export import custom_features, export_release, inspect_export, main


def binary(features: str | None = None) -> bytes:
    if features is None:
        return b"ECFG" + struct.pack("<I", 0)
    key = b"_custom_features"
    text = features.encode()
    value = struct.pack("<II", 4, len(text)) + text + b"\0" * (-len(text) % 4)
    return b"ECFG" + struct.pack("<II", 1, len(key)) + key + struct.pack("<I", len(value)) + value


def resources() -> dict[str, bytes]:
    files = {
        "project.binary": binary(),
        ".godot/global_script_class_cache.cfg": b"list=[]\n",
        "content/pl/manifest.json": b"{}",
        "data/audio/cues.json": b"{}",
        # Inert translated copy may retain the word debug in release.
        "locale/debug.pl.translation": b"copy",
    }
    for source, target in (
        ("services/nav/boot.tscn", ".godot/exported/1/export-boot.scn"),
        ("features/level/level.tscn", ".godot/exported/1/export-level.scn"),
        ("services/nav.gd", "services/nav.gdc"),
    ):
        files[source + ".remap"] = f'[remap]\n\npath="res://{target}"\n'.encode()
        files[target] = b"compiled"
    return files


def write_zip(path: Path, files: dict[str, bytes]) -> Path:
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as archive:
        for name, content in files.items():
            archive.writestr(name, content)
    return path


def test_actual_zip_and_remaps_are_accepted_and_reported(tmp_path: Path) -> None:
    files = resources()
    files["project.binary"] = binary("prototype,release")
    archive = write_zip(tmp_path / "release.zip", files)
    report_path = tmp_path / "report.json"
    assert main([str(archive), "--report", str(report_path)]) == 0
    report = json.loads(report_path.read_text())
    assert report["files"] == sorted(files)
    assert report["file_count"] == len(files)
    assert report["custom_features"] == ["prototype", "release"]
    assert report["archive_sha256"] == hashlib.sha256(archive.read_bytes()).hexdigest()


@pytest.mark.parametrize(
    "path",
    [
        "features/debug/debug.gd",
        "features/debug/performance_overlay.gdc",
        "features/debug/debug.tscn.remap",
        "ui/gallery/controls.tscn",
        "features/level/gallery.gdc",
        "addons/gut/gut.gdc",
        "tests/integration/test_boot.gd.remap",
        "FEATURES/DEBUG/debug.gdc",
    ],
)
def test_developer_files_are_rejected(tmp_path: Path, path: str) -> None:
    files = resources()
    files[path] = b"developer"
    with pytest.raises(ValueError, match="Developer code/screen"):
        inspect_export(write_zip(tmp_path / "bad.zip", files))


@pytest.mark.parametrize("feature", ["debug", "release,debug", "release, DEBUG "])
def test_debug_feature_in_binary_metadata_is_rejected(feature: str) -> None:
    with pytest.raises(ValueError, match="custom debug feature"):
        custom_features(binary(feature))


@pytest.mark.parametrize("data", [b"text", b"ECFG", binary("release")[:-1], binary() + b"extra"])
def test_invalid_binary_metadata_fails_closed(data: bytes) -> None:
    with pytest.raises(ValueError, match="project.binary|_custom_features"):
        custom_features(data)


def test_custom_features_invalid_type_and_duplicate_property_are_rejected() -> None:
    data = binary("release")
    # Swap the string Variant's type, retaining otherwise valid ECFG framing.
    offset = 12 + len(b"_custom_features") + 4
    with pytest.raises(ValueError, match="Variant"):
        custom_features(data[:offset] + struct.pack("<I", 2) + data[offset + 4 :])
    duplicate = b"ECFG" + struct.pack("<I", 2) + data[8:] + data[8:]
    with pytest.raises(ValueError, match="Duplicate"):
        custom_features(duplicate)


@pytest.mark.parametrize("target", ["features/debug/debug.scn", "missing.scn"])
def test_bad_remap_targets_are_rejected(tmp_path: Path, target: str) -> None:
    files = resources()
    files["services/nav/boot.tscn.remap"] = f'[remap]\npath="res://{target}"'.encode()
    with pytest.raises(ValueError, match="Developer code/screen|Missing remap target"):
        inspect_export(write_zip(tmp_path / "bad.zip", files))


@pytest.mark.parametrize("source", ["features/debug/debug.gd", "missing.gd"])
def test_bad_class_cache_reference_is_rejected(tmp_path: Path, source: str) -> None:
    files = resources()
    files[".godot/global_script_class_cache.cfg"] = f'list=[{{"path": "res://{source}"}}]'.encode()
    with pytest.raises(ValueError, match="Developer code/screen|Missing cached class"):
        inspect_export(write_zip(tmp_path / "bad.zip", files))


@pytest.mark.parametrize("compiled", [".godot/exported/1/export-hidden.scn", "hidden.gdc"])
def test_orphan_compiled_resources_are_rejected(tmp_path: Path, compiled: str) -> None:
    files = resources()
    files[compiled] = b"compiled"
    with pytest.raises(ValueError, match="no allowed source remap"):
        inspect_export(write_zip(tmp_path / "bad.zip", files))


@pytest.mark.parametrize(
    "missing", ["project.binary", "content/pl/manifest.json", "data/audio/cues.json"]
)
def test_incomplete_export_is_rejected(tmp_path: Path, missing: str) -> None:
    files = resources()
    del files[missing]
    with pytest.raises(ValueError, match="Missing release resource"):
        inspect_export(write_zip(tmp_path / "bad.zip", files))


@pytest.mark.parametrize("path", ["../features/debug/a.gd", "/a.gd", "a\\b.gd", "a/./b.gd"])
def test_noncanonical_paths_are_rejected(tmp_path: Path, path: str) -> None:
    files = resources()
    files[path] = b"bad"
    with pytest.raises(ValueError, match="Non-canonical"):
        inspect_export(write_zip(tmp_path / "bad.zip", files))


def test_duplicate_and_corrupt_zip_are_rejected(tmp_path: Path) -> None:
    path = write_zip(tmp_path / "bad.zip", resources())
    with zipfile.ZipFile(path, "a") as archive, pytest.warns(UserWarning, match="Duplicate"):
        archive.writestr("project.binary", binary())
    with pytest.raises(ValueError, match="Duplicate ZIP"):
        inspect_export(path)
    write_zip(path, resources())
    path.write_bytes(path.read_bytes().replace(b"compiled", b"corrupt!", 1))
    with pytest.raises(ValueError, match="Corrupt"):
        inspect_export(path)


def test_missing_archive_fails_cli_readably(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    assert main([str(tmp_path / "missing.zip")]) == 1
    assert "ERROR:" in capsys.readouterr().err


@pytest.mark.parametrize("engine_result", [(0, "ERROR: export failed"), (1, "export failed")])
def test_engine_error_removes_stale_archive_and_fails(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, engine_result: tuple[int, str]
) -> None:
    archive = write_zip(tmp_path / "stale.zip", resources())
    results = iter([(0, "4.7.2.stable.official.test"), (0, "import OK"), engine_result])

    def run(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        code, output = next(results)
        return subprocess.CompletedProcess(args, code, output, "")

    monkeypatch.setattr(subprocess, "run", run)
    with pytest.raises(ValueError, match="export failed"):
        export_release(archive, "godot")
    assert not archive.exists()


def test_wrong_engine_version_is_rejected(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        subprocess, "run", lambda args, **kwargs: subprocess.CompletedProcess(args, 0, "4.7.1", "")
    )
    with pytest.raises(ValueError, match="pinned Godot"):
        export_release(tmp_path / "bad.zip", "godot")


def test_raw_metadata_cannot_be_replaced_by_a_remap(tmp_path: Path) -> None:
    files = resources()
    files["project.binary.remap"] = files.pop("project.binary")
    with pytest.raises(ValueError, match="Missing release resource"):
        inspect_export(write_zip(tmp_path / "bad.zip", files))


@pytest.mark.parametrize(
    "text", ["[remap]", 'path="res://services/nav.gdc"\npath="res://services/nav.gdc"']
)
def test_missing_or_ambiguous_remap_fails(tmp_path: Path, text: str) -> None:
    files = resources()
    files["services/nav.gd.remap"] = text.encode()
    with pytest.raises(ValueError, match="Invalid resource remap"):
        inspect_export(write_zip(tmp_path / "bad.zip", files))


def test_allowed_cached_script_with_compiled_remap_is_accepted(tmp_path: Path) -> None:
    files = resources()
    files[".godot/global_script_class_cache.cfg"] = b'list=[{"path": "res://services/nav.gd"}]'
    inspect_export(write_zip(tmp_path / "release.zip", files))
