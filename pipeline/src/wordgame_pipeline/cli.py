"""wg build plans and executes the same injectable stage runner used by tests."""

import argparse
import sys
from pathlib import Path

from .annotate import handlers_for as annotation_handlers
from .candidates import handlers_for as candidate_handlers
from .config import load_config
from .content import validate_content
from .export import handlers_for as export_handlers
from .export.publish import publish
from .grid import handlers_for as grid_handlers
from .ingest import handlers_for
from .stages import P1_STAGES, artifact_path, read_artifact, run_build, select_stages
from .tiers import handlers_for as tier_handlers
from .validate import SchemaRegistry
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
    build.add_argument("--slots", type=int)
    build.add_argument("--content-version", type=int)
    build.add_argument("--output", type=Path)
    build.add_argument("--check", action="store_true")
    validate = commands.add_parser("validate-content")
    validate.add_argument("--lang", default="pl")
    validate.add_argument("--root", type=Path, default=Path("pipeline"))
    validate.add_argument("--content-root", type=Path, default=Path("game/content"))
    validate.add_argument("--prepare-evidence", action="store_true")
    args = parser.parse_args(argv)
    try:
        config = load_config(args.root, args.lang)
        if args.command == "validate-content":
            count = validate_content(
                args.root, config, args.content_root, prepare=args.prepare_evidence
            )
            print(
                "SKIP content-validate: no campaign or evidence yet (T-0131)"
                if count is None
                else f"OK: {count} {config.lang} campaign levels validated"
            )
            return 0
        selected = select_stages(args.first, args.last)
        exporting = selected[-1].name == "export"
        if args.check and (not exporting or selected[0].name != "export" or args.plan):
            raise ValueError("--check requires --from export --to export without --plan")
        if exporting and not args.plan:
            if args.slots is None or args.content_version is None:
                raise ValueError("Export requires --slots and --content-version")
            if not 15 <= args.slots <= 9999 or args.content_version < 1:
                raise ValueError("Export requires slots 15–9999 and positive content version")
        if args.plan:
            for stage in selected:
                print(artifact_path(args.root, config.lang, stage).relative_to(args.root))
        elif args.check:
            previous, _raw = read_artifact(args.root, config, P1_STAGES[-2])
            payload = export_handlers(args.root, args.slots, args.content_version)["export"](
                config, previous
            )
            publish(
                payload,
                args.output or args.root.parent / "game/content/pl",
                SchemaRegistry(args.root),
                check=True,
            )
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
                    **export_handlers(args.root, args.slots, args.content_version),
                },
                args.first,
                args.last,
            ):
                print(path.relative_to(args.root))
            if exporting:
                payload, _raw = read_artifact(args.root, config, P1_STAGES[-1])
                publish(
                    payload,
                    args.output or args.root.parent / "game/content/pl",
                    SchemaRegistry(args.root),
                )
    except (OSError, ValueError, TypeError) as exc:
        print(f"wg: {exc}", file=sys.stderr)
        return 1
    return 0
