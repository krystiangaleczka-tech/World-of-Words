"""Offline outsider worksheet commands. Metadata and human gates remain unverified."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

if __package__:
    from .playtest_summary import build_summary, render_summary
    from .playtest_validation import parse_worksheet
    from .playtest_worksheet import render_worksheet
else:
    from playtest_summary import build_summary, render_summary
    from playtest_validation import parse_worksheet
    from playtest_worksheet import render_worksheet


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("template", help="Print five blank sessions as JSON")
    validate = commands.add_parser("validate", help="Validate worksheet syntax only")
    validate.add_argument("path", type=Path)
    report = commands.add_parser("report", help="Print observations and missing evidence")
    report.add_argument("path", type=Path)
    report.add_argument("--format", choices=("json", "markdown"), default="markdown")
    args = parser.parse_args(argv)
    try:
        if args.command == "template":
            output = render_worksheet()
        else:
            document = parse_worksheet(args.path.read_text(encoding="utf-8"))
            if args.command == "validate":
                output = "Valid worksheet format; observations and gates are unverified.\n"
            elif args.format == "json":
                output = (
                    json.dumps(
                        build_summary(document),
                        ensure_ascii=False,
                        allow_nan=False,
                        sort_keys=True,
                        indent=2,
                    )
                    + "\n"
                )
            else:
                output = render_summary(document)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"Playtest worksheet: {exc}", file=sys.stderr)
        return 1
    print(output, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
