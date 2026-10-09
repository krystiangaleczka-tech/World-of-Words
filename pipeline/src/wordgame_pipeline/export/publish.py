"""Publish a complete managed language directory with rollback on I/O failure."""

import hashlib
import os
import shutil
import tempfile
from pathlib import Path

from ..config import canonical_bytes, parse_json
from ..validate import SchemaRegistry


def _existing(output: Path, registry: SchemaRegistry) -> dict[str, bytes]:
    if output.is_symlink() or any(p.is_symlink() for p in output.parents):
        raise ValueError("Content output cannot use symlinks")
    if not output.exists():
        return {}
    if not output.is_dir():
        raise ValueError("Content output must be a directory")
    paths = list(output.rglob("*"))
    if any(p.is_symlink() for p in paths):
        raise ValueError("Content output cannot contain symlinks")
    if any(not p.is_file() and not p.is_dir() for p in paths):
        raise ValueError("Content output has unmanaged special files")
    files = {p.relative_to(output).as_posix(): p.read_bytes() for p in paths if p.is_file()}
    manifest = parse_json(files.get("manifest.json", b"null").decode("utf-8"))
    registry.validate_schema("manifest", manifest)
    expected = {"manifest.json"} | {entry["file"] for entry in manifest["packs"]}
    if set(files) != expected or any(
        p.is_dir() and p.relative_to(output).as_posix() != "packs" for p in paths
    ):
        raise ValueError("Content output has missing or unmanaged files")
    next_slot = 1
    for entry in manifest["packs"]:
        name = entry["file"]
        if (
            entry["first"] != next_slot
            or entry["last"] < entry["first"]
            or name != f"packs/c-{entry['first']:04d}-{entry['last']:04d}.json"
            or hashlib.sha256(files[name]).hexdigest() != entry["sha256"]
        ):
            raise ValueError("Existing pack ranges/hash mismatch")
        pack = parse_json(files[name].decode("utf-8"))
        registry.validate_schema("pack", pack)
        if pack["kind"] != "campaign" or len(pack["levels"]) != entry["last"] - next_slot + 1:
            raise ValueError("Existing pack membership mismatch")
        for level in pack["levels"]:
            if level["slot"] != next_slot or level["id"] != f"pl-c-{next_slot:06d}":
                raise ValueError("Existing level identity mismatch")
            next_slot += 1
    if next_slot != manifest["slots"] + 1:
        raise ValueError("Existing manifest slot count mismatch")
    return files


def publish(payload: dict, output: Path, registry: SchemaRegistry, *, check: bool = False) -> None:
    files = {name: canonical_bytes(document) for name, document in payload["files"].items()}
    # Only an exporter-generated file set may reach disk, even for API callers.
    manifest = payload["files"]["manifest.json"]
    registry.validate_schema("manifest", manifest)
    expected = {"manifest.json"} | {entry["file"] for entry in manifest["packs"]}
    if set(files) != expected:
        raise ValueError("Unexpected export file set")
    for entry in manifest["packs"]:
        registry.validate_schema("pack", payload["files"][entry["file"]])
        if hashlib.sha256(files[entry["file"]]).hexdigest() != entry["sha256"]:
            raise ValueError("Export pack hash mismatch")
    old = _existing(output, registry)
    if check:
        if old != files:
            raise ValueError("Content differs from deterministic export")
        return
    if old:
        old_version = parse_json(old["manifest.json"].decode("utf-8"))["content_version"]
        version = manifest["content_version"]
        if version == old_version and old == files:
            return
        if version != old_version + 1:
            raise ValueError("Changed content requires previous content_version +1")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=f".{output.name}-export-", dir=output.parent))
    staged, backup = temporary / "new", temporary / "old"
    staged.mkdir()
    try:
        for name, data in files.items():
            path = staged / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        _existing(staged, registry)
        had_old = output.exists()
        if had_old:
            os.replace(output, backup)
        try:
            os.replace(staged, output)
        except OSError:
            if had_old:
                os.replace(backup, output)
            raise
    finally:
        # If rollback itself fails, retain the only old copy for recovery.
        if not backup.exists() or output.exists():
            shutil.rmtree(temporary)
