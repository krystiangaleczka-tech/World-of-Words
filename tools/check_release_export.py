"""Inspect the actual unsigned Godot Android Release resource export, not presets."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import struct
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = ("features/debug/", "ui/gallery/", "tests/", "addons/gut/")
REQUIRED = (
    "project.binary",
    ".godot/global_script_class_cache.cfg",
    "content/pl/manifest.json",
    "data/audio/cues.json",
    "services/nav/boot.tscn",
    "features/level/level.tscn",
)


def canonical(name: str) -> str:
    if not name or "\\" in name or any(part in ("", ".", "..") for part in name.split("/")):
        raise ValueError(f"Non-canonical resource path: {name!r}")
    return name


def allowed(name: str) -> None:
    canonical(name)
    normalized = name.casefold()
    if normalized.startswith(FORBIDDEN) or normalized.startswith("features/level/gallery."):
        raise ValueError(f"Developer code/screen in release export: {name}")


def custom_features(data: bytes) -> list[str]:
    """Read Godot 4 ECFG framing and only decode the _custom_features string Variant."""
    position = 0

    def take(size: int) -> bytes:
        nonlocal position
        if position + size > len(data):
            raise ValueError("Truncated project.binary")
        value = data[position : position + size]
        position += size
        return value

    def uint() -> int:
        return struct.unpack("<I", take(4))[0]

    if take(4) != b"ECFG":
        raise ValueError("Unsupported project.binary header")
    count = uint()
    features: list[str] = []
    keys: set[str] = set()
    for _ in range(count):
        key = take(uint()).decode("utf-8")
        if key in keys:
            raise ValueError(f"Duplicate project.binary property: {key}")
        keys.add(key)
        value = take(uint())
        if len(value) < 4:
            raise ValueError(f"Invalid project.binary Variant: {key}")
        if key == "_custom_features":
            if len(value) < 8 or struct.unpack_from("<I", value)[0] != 4:
                raise ValueError("Unsupported _custom_features Variant")
            size = struct.unpack_from("<I", value, 4)[0]
            padded = (size + 3) & ~3
            if len(value) != 8 + padded:
                raise ValueError("Invalid _custom_features string length")
            features = [tag.strip() for tag in value[8 : 8 + size].decode("utf-8").split(",")]
            features = [tag for tag in features if tag]
    if position != len(data):
        raise ValueError("Trailing data in project.binary")
    if any(tag.casefold() == "debug" for tag in features):
        raise ValueError("Release export enables the custom debug feature")
    return features


def inspect_export(path: Path) -> dict[str, object]:
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        names: set[str] = set()
        for entry in entries:
            name = entry.filename.removesuffix("/") if entry.is_dir() else entry.filename
            allowed(name)
            if entry.filename in names:
                raise ValueError(f"Duplicate ZIP entry: {entry.filename}")
            names.add(entry.filename)
        files = {entry.filename for entry in entries if not entry.is_dir()}
        bad = archive.testzip()
        if bad is not None:
            raise ValueError(f"Corrupt release ZIP entry: {bad}")
        for required in REQUIRED:
            if required not in files and not (
                required.endswith(".tscn") and required + ".remap" in files
            ):
                raise ValueError(f"Missing release resource: {required}")
        features = custom_features(archive.read("project.binary"))
        targets: set[str] = set()
        for name in sorted(files):
            if not name.endswith(".remap"):
                continue
            text = archive.read(name).decode("utf-8")
            matches = re.findall(r'^\s*path\s*=\s*"res://([^"\n]+)"\s*$', text, re.MULTILINE)
            if len(matches) != 1:
                raise ValueError(f"Invalid resource remap: {name}")
            target = matches[0]
            allowed(target)
            if target not in files:
                raise ValueError(f"Missing remap target: {name} -> {target}")
            targets.add(target)
        for name in files:
            if (
                name.startswith(".godot/exported/") or name.endswith(".gdc")
            ) and name not in targets:
                raise ValueError(f"Compiled resource has no allowed source remap: {name}")
        classes = archive.read(".godot/global_script_class_cache.cfg").decode("utf-8")
        for source in re.findall(r'"path"\s*:\s*"res://([^"\n]+)"', classes):
            allowed(source)
            if source not in files and source + ".remap" not in files:
                raise ValueError(f"Missing cached class script: {source}")
    return {
        "policy": "T-0138-v1",
        "archive_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "file_count": len(files),
        "custom_features": features,
        "files": sorted(files),
    }


def export_release(path: Path, godot: str) -> None:
    """Fail on engine-reported errors even when the engine returns exit code zero."""

    def run(arguments: list[str]) -> str:
        result = subprocess.run(arguments, text=True, capture_output=True, check=False)
        output = result.stdout + result.stderr
        if result.returncode or "ERROR:" in output:
            raise ValueError(f"Release export command failed: {arguments}\n{output}")
        return output

    version = run([godot, "--headless", "--version"]).strip()
    if not version.startswith("4.7.2.stable."):
        raise ValueError(f"Expected pinned Godot 4.7.2.stable, got {version}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.unlink(missing_ok=True)
    base = [godot, "--headless", "--path", str(ROOT / "game")]
    run([*base, "--import", "--quit"])
    run([*base, "--export-pack", "Android Release", str(path.resolve())])


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument(
        "--export", action="store_true", help="Create a fresh unsigned resource ZIP"
    )
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--report", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.export:
            export_release(args.archive, args.godot)
        report = inspect_export(args.archive)
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(
            f"OK: Android Release resource export: {report['file_count']} files; no developer code"
        )
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
