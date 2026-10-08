"""Download the pinned source independently of the artifact build."""

import argparse
import sys
from pathlib import Path

from .source import download_archive, load_pin


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m wordgame_pipeline.ingest")
    parser.add_argument("--root", type=Path, default=Path("pipeline"))
    args = parser.parse_args(argv)
    try:
        path = download_archive(args.root, load_pin(args.root))
    except (OSError, ValueError) as exc:
        print(f"SJP ingest: {exc}", file=sys.stderr)
        return 1
    print(path.relative_to(args.root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
