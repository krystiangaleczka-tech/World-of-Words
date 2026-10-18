"""Embed canonical UTF-8 notices in resources included by Godot all_resources exports."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NOTICES = {
    "game/assets/audio/p1/NOTICE.md": "game/assets/audio/p1/audio_notice.tres",
    "game/content/NOTICE": "game/content/source_notice.tres",
}


def render(notice: str) -> str:
    return (
        '[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/notice = '
        + json.dumps(notice, ensure_ascii=False)
        + "\n"
    )


def generate(root: Path, *, check: bool) -> list[str]:
    stale = []
    for source, target in NOTICES.items():
        expected = render((root / source).read_text(encoding="utf-8"))
        output = root / target
        if not output.is_file() or output.read_text(encoding="utf-8") != expected:
            stale.append(target)
            if not check:
                output.write_text(expected, encoding="utf-8")
    return stale


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    stale = generate(ROOT, check=args.check)
    if args.check and stale:
        print("Stale credits resources: " + ", ".join(stale))
        return 1
    print("Credits resources current" if args.check else "Credits resources generated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
