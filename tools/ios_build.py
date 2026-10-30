"""Ephemerally configure Godot's iOS preset for unsigned CI builds."""
from __future__ import annotations

import os
import re
from pathlib import Path

TEAM_RE = re.compile(r"[A-Z0-9]{10}\Z")
BUNDLE_RE = re.compile(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\Z")
IOS_HEADER = '[preset.2]\nname="iOS Debug"\n'


def prepare_preset(path: Path, team: str, bundle: str) -> None:
    """Reject bad input atomically; never print owner identifiers."""
    if not TEAM_RE.fullmatch(team):
        raise ValueError("Apple Team ID must contain exactly 10 uppercase letters/digits")
    if not BUNDLE_RE.fullmatch(bundle):
        raise ValueError("Bundle identifier must have reverse-DNS syntax")
    if path.is_symlink() or not path.is_file():
        raise ValueError("Expected regular export_presets.cfg file")
    source = path.read_text(encoding="utf-8")
    if source.count(IOS_HEADER) != 1 or source.count("[preset.2.options]\n") != 1:
        raise ValueError("Expected exactly one iOS Debug preset")
    prefix, ios = source.split("[preset.2]\n", 1)
    for key in ("app_store_team_id", "bundle_identifier"):
        placeholder = f'application/{key}=""'
        if ios.count(placeholder) != 1:
            raise ValueError(f"Missing unconfigured iOS {key}")
    ios = ios.replace('application/app_store_team_id=""', f'application/app_store_team_id="{team}"')
    ios = ios.replace('application/bundle_identifier=""', f'application/bundle_identifier="{bundle}"')
    path.write_text(prefix + "[preset.2]\n" + ios, encoding="utf-8")


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--presets", type=Path, default=Path("game/export_presets.cfg"))
    args = parser.parse_args()
    try:
        prepare_preset(
            args.presets,
            os.environ.get("IOS_APPLE_TEAM_ID", ""),
            os.environ.get("IOS_BUNDLE_IDENTIFIER", ""),
        )
    except ValueError as exc:
        print(f"iOS export preflight failed: {exc}")
        return 2
    print("Ephemeral unsigned iOS preset prepared; no secrets stored.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
