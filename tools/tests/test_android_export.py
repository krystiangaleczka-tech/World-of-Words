from __future__ import annotations

import os
import sys
import zipfile
from pathlib import Path

import pytest

from tools.android_debug_build import run, validate_assets, validate_manifest

BADGING = """package: name='org.worldofwords.prototype.debug' versionCode='1'
sdkVersion:'24'
targetSdkVersion:'36'
application-debuggable
uses-permission: name='android.permission.VIBRATE'
uses-permission: name='android.permission.INTERNET'
"""
TREE = "A: android:screenOrientation(0x0101001e)=(type 0x10)0x1"


def test_expected_manifest_is_accepted() -> None:
    validate_manifest(BADGING, TREE)


@pytest.mark.parametrize(
    ("old", "new"),
    [
        ("prototype.debug", "prototype"),
        ("sdkVersion:'24'", "sdkVersion:'23'"),
        ("targetSdkVersion:'36'", "targetSdkVersion:'35'"),
        ("application-debuggable", ""),
        ("uses-permission: name='android.permission.VIBRATE'", ""),
        ("uses-permission: name='android.permission.INTERNET'", ""),
    ],
)
def test_wrong_manifest_is_rejected(old: str, new: str) -> None:
    with pytest.raises(ValueError):
        validate_manifest(BADGING.replace(old, new), TREE)


def test_extra_permission_and_landscape_are_rejected() -> None:
    with pytest.raises(ValueError, match="permissions"):
        validate_manifest(BADGING + "uses-permission: name='android.permission.CAMERA'", TREE)
    with pytest.raises(ValueError, match="portrait"):
        validate_manifest(BADGING, TREE.replace("0x1", "0x0"))


@pytest.mark.parametrize("defect", ["content", "audio", "debug", "tests", "corrupt"])
def test_actual_archive_contract(tmp_path: Path, defect: str) -> None:
    apk = tmp_path / "fixture.apk"
    names = [
        "assets/content/pl/manifest.json",
        "assets/data/audio/cues.json",
        "assets/features/debug/debug.tscn.remap",
    ]
    with zipfile.ZipFile(apk, "w", compression=zipfile.ZIP_STORED) as archive:
        for name in names:
            archive.writestr(name, "content")
    validate_assets(apk)
    if defect == "corrupt":
        apk.write_bytes(apk.read_bytes().replace(b"content", b"broken!", 1))
    else:
        with zipfile.ZipFile(apk, "w") as archive:
            for name in names:
                if defect not in name:
                    archive.writestr(name, "content")
            if defect == "tests":
                archive.writestr("assets/tests/integration/test_audio.gd", "test")
    with pytest.raises(ValueError):
        validate_assets(apk)


@pytest.mark.parametrize(
    "script", ["print('ERROR: bad')", "print('SCRIPT ERROR: bad')", "print('bad'); exit(4)"]
)
def test_export_errors_are_fatal_and_readable(script: str) -> None:
    with pytest.raises(RuntimeError, match="bad"):
        run([sys.executable, "-c", script], os.environ.copy())
