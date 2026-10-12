"""Compare generated theme outputs without mutating the source project."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

OUTPUTS = tuple(
    [
        f"game/ui/theme/generated/theme_{mode}_{size}.tres"
        for mode in ("default", "hc")
        for size in (100, 115, 130)
    ]
    + ["game/assets/fonts/Inter.res", "game/assets/fonts/font_license.tres"]
    + [
        f"game/assets/fonts/inter_{name}.tres"
        for name in ("regular", "semibold", "bold", "extrabold", "numeric")
    ]
    + ["docs/design/tokens.css"]
)
REGENERATE = "godot --headless --path game --script res://ui/theme/generate_theme_cli.gd"


def check(root: Path, godot: str) -> list[str]:
    missing = [
        f"{p}: missing generated output; run {REGENERATE}"
        for p in OUTPUTS
        if not (root / p).is_file()
    ]
    if missing:
        return missing
    try:
        with tempfile.TemporaryDirectory(prefix="wow-theme-check-") as directory:
            shadow = Path(directory)
            shutil.copytree(root / "game", shadow / "game", ignore=shutil.ignore_patterns(".godot"))
            (shadow / "docs/design").mkdir(parents=True)
            for args in (
                ["--import", "--quit"],
                ["--script", "res://ui/theme/generate_theme_cli.gd"],
            ):
                result = subprocess.run(
                    [godot, "--headless", "--path", str(shadow / "game"), *args],
                    capture_output=True,
                    text=True,
                    timeout=120,
                )
                log = result.stdout + result.stderr
                if result.returncode or re.search(r"^(?:ERROR|SCRIPT ERROR|WARNING)", log, re.M):
                    return [f"theme engine step {args[0]} failed:\n{log.strip()}"]
            return [
                f"{p}: stale/missing generated output; run {REGENERATE}"
                for p in OUTPUTS
                if not (shadow / p).is_file()
                or (shadow / p).read_bytes() != (root / p).read_bytes()
            ]
    except (OSError, subprocess.TimeoutExpired) as exc:
        return [f"theme verification failed: {exc}"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args(argv)
    errors = check(args.root.resolve(), args.godot)
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    if not errors:
        print(
            f"OK: {len(OUTPUTS)} generated theme/font/CSS outputs current "
            "(temporary clean-cache project)"
        )
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
