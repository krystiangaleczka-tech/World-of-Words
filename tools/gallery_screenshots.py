"""Render and verify native GalleryShell PR evidence. Standard library only."""

from __future__ import annotations

import argparse
import hashlib
import html
import itertools
import json
import os
import re
import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIZES = {"COMPACT": (1080, 1920), "REGULAR": (1080, 2340), "TABLET": (1440, 1920)}
LANGUAGES = ("PL", "PSEUDO")
STATES = ("default100", "hc130")
PNG = b"\x89PNG\r\n\x1a\n"
ENGINE_ERROR = re.compile(r"^(?:SCRIPT ERROR|ERROR):", re.MULTILINE)


def relevant(path: str) -> bool:
    return path.startswith(("game/ui/", "game/features/", "game/locale/")) or path in {
        ".github/workflows/ci.yml",
        "tools/gallery_screenshots.py",
        "tools/tests/test_gallery_screenshots.py",
    }


def changed(root: Path, base: str) -> bool:
    commit = subprocess.run(
        ["git", "rev-parse", "--verify", "--end-of-options", base + "^{commit}"],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    paths = subprocess.run(
        ["git", "diff", "--name-only", "--no-renames", "-z", commit + "...HEAD", "--"],
        cwd=root,
        check=True,
        capture_output=True,
    ).stdout.split(b"\0")
    return any(relevant(os.fsdecode(path)) for path in paths if path)


def fresh_output(root: Path, requested: Path) -> Path:
    output = (root / requested).resolve()
    builds = (root / "builds").resolve()
    # The builds parent must itself stay inside this checkout, including symlinks.
    if not builds.is_relative_to(root.resolve()) or not output.is_relative_to(builds):
        raise ValueError("output must be under this checkout's builds directory")
    if output == builds or (output.exists() and (not output.is_dir() or any(output.iterdir()))):
        raise ValueError("output must be a fresh empty subdirectory of builds")
    output.mkdir(parents=True, exist_ok=True)
    return output


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if not data.startswith(PNG):
        raise ValueError(f"invalid PNG signature: {path.name}")
    offset = len(PNG)
    dimensions = None
    saw_data = False
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("truncated PNG chunk")
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4 : offset + 8]
        end = offset + 12 + length
        if end > len(data):
            raise ValueError("truncated PNG payload")
        payload = data[offset + 8 : offset + 8 + length]
        crc = struct.unpack_from(">I", data, offset + 8 + length)[0]
        if zlib.crc32(kind + payload) & 0xFFFFFFFF != crc:
            raise ValueError("PNG CRC mismatch")
        if dimensions is None:
            if kind != b"IHDR" or length != 13:
                raise ValueError("PNG must start with IHDR")
            dimensions = struct.unpack_from(">II", payload)
        elif kind == b"IHDR":
            raise ValueError("duplicate PNG header")
        if kind == b"IDAT":
            saw_data = True
        if kind == b"IEND":
            if length or end != len(data) or not saw_data:
                raise ValueError("invalid PNG end")
            return dimensions
        offset = end
    raise ValueError("PNG has no end chunk")


def validate(output: Path) -> dict:
    manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
    if (
        manifest.get("schema") != 1
        or not str(manifest.get("engine", "")).startswith("4.7.2-stable ")
        or manifest.get("display") != "x11"
        or manifest.get("renderer") != "gl_compatibility"
        or not manifest.get("adapter")
    ):
        raise ValueError("incorrect native renderer metadata")
    pages = manifest["pages"]
    if (
        not pages
        or len(set(pages)) != len(pages)
        or any(not re.fullmatch(r"[A-Za-z][A-Za-z0-9]*", page) for page in pages)
    ):
        raise ValueError("invalid page registry")
    expected = set(itertools.product(pages, SIZES, LANGUAGES, STATES))
    seen = set()
    files = set()
    for item in manifest["images"]:
        key = (item["page"], item["layout"], item["locale"], item["state"])
        if key not in expected or key in seen:
            raise ValueError("unexpected or duplicate matrix entry")
        seen.add(key)
        filename = "{}_{}_{}_{}.png".format(key[0].lower(), *key[1:])
        if item["file"] != filename or filename in files:
            raise ValueError("unsafe or duplicate image filename")
        files.add(filename)
        path = output / filename
        if path.is_symlink() or not path.is_file():
            raise ValueError("missing image or symlink")
        if png_size(path) != SIZES[key[1]] or (item["width"], item["height"]) != SIZES[key[1]]:
            raise ValueError("incorrect image dimensions")
        item["bytes"] = path.stat().st_size
        item["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    if seen != expected or {p.name for p in output.glob("*.png")} != files:
        raise ValueError("incomplete matrix or unexpected PNGs")
    return manifest


def write_index(output: Path, manifest: dict) -> None:
    cards = []
    for item in manifest["images"]:
        filename = html.escape(item["file"], quote=True)
        title = html.escape(" / ".join(str(item[k]) for k in ("page", "layout", "locale", "state")))
        cards.append(
            f'<figure><a href="{filename}"><img loading="lazy" src="{filename}" '
            f'alt="{title}" width="270"></a><figcaption>{title}</figcaption></figure>'
        )
    (output / "index.html").write_text(
        '<!doctype html><html lang="en"><meta charset="utf-8"><title>Gallery screenshots</title>'
        "<style>body{font-family:system-ui;background:#eee}main{display:flex;flex-wrap:wrap}"
        "figure{margin:12px}figcaption{max-width:270px}img{height:auto}</style>"
        "<h1>Gallery screenshots</h1>"
        "<p>Desktop Compatibility evidence; no device certification.</p>"
        '<p><a href="manifest.json">Manifest</a></p><main>' + "".join(cards) + "</main></html>",
        encoding="utf-8",
    )


def run_engine(command: list[str], output: Path, name: str, env: dict[str, str]) -> str:
    log = output / name
    try:
        result = subprocess.run(
            command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=600
        )
    except subprocess.TimeoutExpired as exc:
        log.write_bytes((exc.stdout or b"") + (exc.stderr or b""))
        raise ValueError(f"engine timed out; see {log}") from exc
    text = result.stdout + result.stderr
    log.write_text(text, encoding="utf-8")
    if result.returncode or ENGINE_ERROR.search(text):
        raise ValueError(f"engine failed; see {log}")
    return text


def capture(root: Path, output: Path, godot: str) -> None:
    env = dict(os.environ, LIBGL_ALWAYS_SOFTWARE="1", GODOT_SILENCE_ROOT_WARNING="1")
    version = run_engine([godot, "--version"], output, "version.log", env).strip()
    if not version.startswith("4.7.2.stable"):
        raise ValueError("Godot must be pinned 4.7.2.stable")
    run_engine(
        [godot, "--headless", "--path", str(root / "game"), "--editor", "--import", "--quit"],
        output,
        "import.log",
        env,
    )
    command = [
        godot,
        "--path",
        str(root / "game"),
        "--display-driver",
        "x11",
        "--rendering-method",
        "gl_compatibility",
        "--audio-driver",
        "Dummy",
        "--script",
        "res://ui/gallery/capture.gd",
        "--",
        "--output",
        str(output),
    ]
    if not env.get("DISPLAY"):
        command = ["xvfb-run", "-a", "-s", "-screen 0 1600x2400x24", *command]
    run_engine(command, output, "render.log", env)
    manifest = validate(output)
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    write_index(output, manifest)
    print(f"Verified {len(manifest['images'])} native screenshots: {output / 'index.html'}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--filter-only", action="store_true")
    parser.add_argument("--base")
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, default=Path("builds/gallery"))
    args = parser.parse_args()
    try:
        if args.filter_only:
            if not args.base:
                raise ValueError("--base is required for filtering")
            render = changed(ROOT, args.base)
            line = f"render={str(render).lower()}\n"
            if args.github_output:
                with args.github_output.open("a", encoding="utf-8") as stream:
                    stream.write(line)
            print(line.strip())
        else:
            capture(ROOT, fresh_output(ROOT, args.output), args.godot)
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        print(f"gallery: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
