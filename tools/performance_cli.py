"""Read-only diagnostic report rendering and descriptive two-capture comparison."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

if __package__:
    from .performance_compare import compare_reports, render_comparison
    from .performance_markdown import render_report
    from .performance_validation import parse_report
else:
    from performance_compare import compare_reports, render_comparison
    from performance_markdown import render_report
    from performance_validation import parse_report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    report = commands.add_parser("report", help="Render existing capture JSON as Markdown")
    report.add_argument("path", type=Path)
    compare = commands.add_parser("compare", help="Compare two existing captures")
    compare.add_argument("baseline", type=Path)
    compare.add_argument("candidate", type=Path)
    compare.add_argument("--format", choices=("json", "markdown"), default="markdown")
    args = parser.parse_args(argv)
    try:
        if args.command == "report":
            output = render_report(parse_report(args.path.read_text(encoding="utf-8")))
        else:
            first = parse_report(args.baseline.read_text(encoding="utf-8"))
            second = parse_report(args.candidate.read_text(encoding="utf-8"))
            if args.format == "json":
                output = (
                    json.dumps(
                        compare_reports(first, second),
                        ensure_ascii=False,
                        allow_nan=False,
                        sort_keys=True,
                        indent=2,
                    )
                    + "\n"
                )
            else:
                output = render_comparison(first, second)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"Performance analysis: {exc}", file=sys.stderr)
        return 1
    print(output, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
