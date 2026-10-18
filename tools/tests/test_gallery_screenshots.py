from __future__ import annotations

import itertools
import json
import struct
import subprocess
import zlib
from pathlib import Path

import pytest

from tools import gallery_screenshots as gallery


def chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def png(width: int, height: int) -> bytes:
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    rows = (b"\0" + b"\x12\x34\x56" * width) * height
    return (
        gallery.PNG
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(rows))
        + chunk(b"IEND", b"")
    )


def matrix(output: Path) -> dict:
    images = []
    for layout, language, state in itertools.product(
        gallery.SIZES, gallery.LANGUAGES, gallery.STATES
    ):
        width, height = gallery.SIZES[layout]
        filename = f"samples_{layout}_{language}_{state}.png"
        (output / filename).write_bytes(png(width, height))
        images.append(
            dict(
                page="Samples",
                layout=layout,
                locale=language,
                state=state,
                width=width,
                height=height,
                file=filename,
            )
        )
    manifest = dict(
        schema=1,
        engine="4.7.2-stable (official)",
        display="x11",
        renderer="gl_compatibility",
        adapter="llvmpipe",
        pages=["Samples"],
        images=images,
    )
    save(output, manifest)
    return manifest


def save(output: Path, manifest: dict) -> None:
    (output / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")


@pytest.mark.parametrize(
    "path",
    [
        "game/ui/a.gd",
        "game/features/deleted.gd",
        "game/locale/a.csv",
        ".github/workflows/ci.yml",
        "tools/gallery_screenshots.py",
    ],
)
def test_ui_paths_trigger_capture(path: str) -> None:
    assert gallery.relevant(path)


@pytest.mark.parametrize("path", ["docs/UI.md", "game/services/nav.gd", "tasks/T-0327.md"])
def test_unrelated_paths_skip(path: str) -> None:
    assert not gallery.relevant(path)


@pytest.mark.parametrize("rename", [True, False])
def test_git_detects_deleted_or_renamed_out_of_ui(tmp_path: Path, rename: bool) -> None:
    def git(*args: str) -> str:
        return subprocess.run(
            ["git", *args], cwd=tmp_path, check=True, capture_output=True, text=True
        ).stdout.strip()

    git("init", "-b", "main")
    git("config", "user.name", "Test")
    git("config", "user.email", "test@example.com")
    ui = tmp_path / "game/ui/old.gd"
    ui.parent.mkdir(parents=True)
    ui.write_text("unchanged content\n")
    git("add", ".")
    git("commit", "-m", "base")
    base = git("rev-parse", "HEAD")
    assert not gallery.changed(tmp_path, base)
    if rename:
        git("mv", "game/ui/old.gd", "moved.txt")
    else:
        ui.unlink()
    git("add", "-A")
    git("commit", "-m", "move or delete")
    assert gallery.changed(tmp_path, base)
    with pytest.raises(subprocess.CalledProcessError):
        gallery.changed(tmp_path, "--all")


def test_fresh_output_rejects_stale_external_and_symlink_paths(tmp_path: Path) -> None:
    output = gallery.fresh_output(tmp_path, Path("builds/gallery"))
    assert output.is_dir()
    (output / "old.log").write_text("stale")
    for path in (output, tmp_path / "outside", tmp_path / "builds"):
        with pytest.raises(ValueError):
            gallery.fresh_output(tmp_path, path)
    (tmp_path / "outside").mkdir()
    (tmp_path / "builds/link").symlink_to(tmp_path / "outside", target_is_directory=True)
    with pytest.raises(ValueError):
        gallery.fresh_output(tmp_path, Path("builds/link/new"))


def test_manifest_complete_matrix_hashes_and_index(tmp_path: Path) -> None:
    matrix(tmp_path)
    manifest = gallery.validate(tmp_path)
    assert len(manifest["images"]) == 12
    assert all(len(image["sha256"]) == 64 and image["bytes"] > 0 for image in manifest["images"])
    gallery.write_index(tmp_path, manifest)
    page = (tmp_path / "index.html").read_text()
    assert page.count('<img loading="lazy"') == 12
    assert 'href="samples_COMPACT_PL_default100.png"' in page


@pytest.mark.parametrize(
    "mutation",
    ["missing", "duplicate", "unsafe", "wrong_size", "renderer", "engine", "pages", "extra"],
)
def test_manifest_rejects_incomplete_or_unsafe_evidence(tmp_path: Path, mutation: str) -> None:
    manifest = matrix(tmp_path)
    if mutation == "missing":
        manifest["images"].pop()
    elif mutation == "duplicate":
        manifest["images"].append(manifest["images"][0])
    elif mutation == "unsafe":
        manifest["images"][0]["file"] = "../escape.png"
    elif mutation == "wrong_size":
        manifest["images"][0]["width"] = 1
    elif mutation == "renderer":
        manifest["renderer"] = "dummy"
    elif mutation == "engine":
        manifest["engine"] = "4.6.3-stable (official)"
    elif mutation == "pages":
        manifest["pages"].append("Missing")
    else:
        (tmp_path / "extra.png").write_bytes(png(1, 1))
    save(tmp_path, manifest)
    with pytest.raises(ValueError):
        gallery.validate(tmp_path)


@pytest.mark.parametrize(
    "mutation", ["missing", "truncated", "crc", "dimensions", "end", "symlink"]
)
def test_manifest_rejects_damaged_png(tmp_path: Path, mutation: str) -> None:
    manifest = matrix(tmp_path)
    path = tmp_path / manifest["images"][0]["file"]
    data = path.read_bytes()
    if mutation == "missing":
        path.unlink()
    elif mutation == "truncated":
        path.write_bytes(data[:30])
    elif mutation == "crc":
        path.write_bytes(data[:20] + bytes([data[20] ^ 1]) + data[21:])
    elif mutation == "dimensions":
        path.write_bytes(png(1, 1))
    elif mutation == "end":
        path.write_bytes(data[:-12])
    else:
        path.unlink()
        path.symlink_to(tmp_path / manifest["images"][1]["file"])
    with pytest.raises(ValueError):
        gallery.validate(tmp_path)


@pytest.mark.parametrize(
    "code,text", [(1, "failure"), (0, "SCRIPT ERROR: bad script\n"), (0, "ERROR: invalid render\n")]
)
def test_engine_failure_is_preserved_in_log(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, code: int, text: str
) -> None:
    monkeypatch.setattr(
        gallery.subprocess, "run", lambda *a, **k: subprocess.CompletedProcess(a[0], code, text, "")
    )
    with pytest.raises(ValueError, match="engine failed"):
        gallery.run_engine(["godot"], tmp_path, "render.log", {})
    assert (tmp_path / "render.log").read_text() == text


def test_index_escapes_labels(tmp_path: Path) -> None:
    gallery.write_index(
        tmp_path,
        {
            "images": [
                dict(
                    page='<script>"',
                    layout="COMPACT",
                    locale="PL",
                    state="default100",
                    file="safe.png",
                )
            ]
        },
    )
    content = (tmp_path / "index.html").read_text()
    assert "<script>" not in content
    assert "&lt;script&gt;&quot;" in content
    assert 'src="safe.png"' in content


@pytest.mark.parametrize("mutation", ["empty", "invalid", "truncated", "rows", "filter"])
def test_png_rejects_crc_valid_but_undecodable_image(tmp_path: Path, mutation: str) -> None:
    width, height = 2, 2
    rows = (b"\0" + b"\x12\x34\x56" * width) * height
    payload = zlib.compress(rows)
    if mutation == "empty":
        payload = b""
    elif mutation == "invalid":
        payload = b"not a zlib stream"
    elif mutation == "truncated":
        payload = payload[:-2]
    elif mutation == "rows":
        payload = zlib.compress(rows[:-1])
    else:
        payload = zlib.compress(b"\x05" + rows[1:])
    path = tmp_path / "broken.png"
    path.write_bytes(
        gallery.PNG
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", payload)
        + chunk(b"IEND", b"")
    )
    with pytest.raises(ValueError):
        gallery.png_size(path)
