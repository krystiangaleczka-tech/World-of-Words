"""wg build plans and executes the same injectable stage runner used by tests."""

import argparse
import sys
from pathlib import Path

from .annotate import handlers_for as annotation_handlers
from .candidates import handlers_for as candidate_handlers
from .config import load_config
from .grid import handlers_for as grid_handlers
from .ingest import handlers_for
from .stages import artifact_path, run_build, select_stages
from .tiers import handlers_for as tier_handlers
from .validate import handlers_for as validation_handlers


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="wg")
    commands = parser.add_subparsers(dest="command", required=True)
    build = commands.add_parser("build")
    build.add_argument("--lang", required=True)
    build.add_argument("--root", type=Path, default=Path("pipeline"))
    build.add_argument("--from", dest="first", default="ingest")
    build.add_argument("--to", dest="last", default="export")
    build.add_argument("--plan", action="store_true")
    args = parser.parse_args(argv)
    try:
        config = load_config(args.root, args.lang)
        selected = select_stages(args.first, args.last)
        if args.plan:
            for stage in selected:
                print(artifact_path(args.root, config.lang, stage).relative_to(args.root))
        else:
            for path in run_build(
                args.root,
                config,
                {
                    **handlers_for(args.root),
                    **annotation_handlers(args.root),
                    **tier_handlers(args.root),
                    **candidate_handlers(args.root),
                    **grid_handlers(args.root),
                    **validation_handlers(args.root),
                },
                args.first,
                args.last,
            ):
                print(path.relative_to(args.root))
    except (OSError, ValueError, TypeError) as exc:
        print(f"wg: {exc}", file=sys.stderr)
        return 1
    return 0
