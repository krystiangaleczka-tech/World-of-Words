"""Emit standalone curator review packets; never apply decisions or write files."""

import argparse
import sys
from pathlib import Path

from .config import canonical_bytes
from .familiarity_report import build_report
from .p1 import read_json
from .review_comparison import compare_reviews
from .review_html import render_review
from .review_worksheet import export_worksheet


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("pipeline"))
    parser.add_argument("--content-root", type=Path, default=Path("game/content"))
    parser.add_argument("--catalog", type=Path)
    parser.add_argument("--format", choices=("html", "csv", "comparison"), default="html")
    parser.add_argument("--candidate", type=Path)
    args = parser.parse_args(argv)
    catalog = args.catalog or args.root / "reviews/pl/familiarity.csv"
    try:
        if args.format == "comparison":
            if args.candidate is None:
                raise ValueError("comparison requires --candidate")
            comparison = compare_reviews(args.root, args.content_root, catalog, args.candidate)
            output = canonical_bytes(comparison).decode("utf-8")
        else:
            if args.candidate is not None:
                raise ValueError("--candidate requires --format comparison")
            report = build_report(args.root, args.content_root, catalog)
            if args.format == "csv":
                output = export_worksheet(report)
            else:
                manifest = read_json(args.content_root / "pl/manifest.json")
                levels = {
                    level["slot"]: level
                    for entry in manifest["packs"]
                    for level in read_json(args.content_root / "pl" / entry["file"])["levels"]
                }
                output = render_review(report, levels)
    except (ValueError, OSError, KeyError) as error:
        print(f"Review packet: {error}", file=sys.stderr)
        return 1
    sys.stdout.write(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
