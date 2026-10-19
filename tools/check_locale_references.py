"""Bounded static localization references and shipped travel-copy audit."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from lark import Tree
from lark.exceptions import LarkError

try:
    from .check_locale import KEY, ROOT, load_catalog
    from .ui_checks import call, gd_parser, scene_errors, string, walk
except ImportError:  # Direct CLI invocation from any working directory.
    from check_locale import KEY, ROOT, load_catalog
    from ui_checks import call, gd_parser, scene_errors, string, walk

SCOPES = ("game/features", "game/ui", "game/services")
FIELDS = {
    name + "_key"
    for name in (
        "title",
        "body",
        "text",
        "caption",
        "a11y_label",
        "label",
        "sublabel",
        "locked_label",
        "action",
        "message",
    )
}


def audit(root: Path) -> dict:
    catalog = load_catalog(root)
    keys = set(catalog)
    areas = {key.split(".")[0] for key in keys}
    errors: list[str] = []
    references: set[tuple[str, int, str]] = set()
    dynamic: set[tuple[str, int, str]] = set()

    def check(label: str, line: int, key: str) -> None:
        references.add((label, line, key))
        if key not in keys:
            errors.append(f"{label}:{line}: unknown translation key {key!r}")

    for scope in SCOPES:
        directory = root / scope
        if not directory.is_dir():
            errors.append(f"{scope}: missing source directory")
        for path in sorted(directory.rglob("*")):
            if path.suffix not in {".gd", ".tscn"}:
                continue
            label = path.relative_to(root).as_posix()
            try:
                source = path.read_text(encoding="utf-8")
                if path.suffix == ".tscn":
                    for line, reason in scene_errors(source, "strings", keys):
                        errors.append(f"{label}:{line}: {reason}")
                    for line, text in enumerate(source.splitlines(), 1):
                        field, separator, value = text.strip().partition("=")
                        if separator and field.strip() in FIELDS:
                            literal = json.loads(value.strip().removeprefix("&"))
                            if not isinstance(literal, str):
                                raise ValueError("scene key must be a literal string")
                            if literal:
                                check(label, line, literal)
                    continue
                tree = gd_parser.parse(source, gather_metadata=True)
                for node in walk(tree):
                    if not isinstance(node, Tree):
                        continue
                    line = node.meta.line
                    if node.data == "string":
                        value = string(node)
                        area = value.split(".")[0]
                        if area in areas and KEY.fullmatch(value):
                            check(label, line, value)
                        elif (area in areas or area == "location") and "." in value:
                            if value.endswith(".") or "%" in value:
                                dynamic.add((label, line, value))
                    if node.data in {"standalone_call", "getattr_call"}:
                        name, args = call(node)
                        target = node.children[0]
                        server = (
                            isinstance(target, Tree)
                            and str(target.children[0]) == "TranslationServer"
                        )
                        if (name == "tr" or (name == "translate" and server)) and args:
                            value = string(args[0])
                            if value is not None:
                                check(label, line, value)
                    if node.data == "assnmnt_expr" or str(node.data).endswith("assgnd"):
                        target, *_, value = node.children
                        field = (
                            str(target.children[-1]) if isinstance(target, Tree) else str(target)
                        )
                        literal = string(value)
                        if field in FIELDS and literal:
                            if literal:
                                check(label, line, literal)
            except (OSError, ValueError, SyntaxError, LarkError) as exc:
                errors.append(f"{label}: cannot parse source: {exc}")

    manifests = sorted((root / "game/content").glob("*/manifest.json"))
    metadata = []
    if not manifests:
        errors.append("game/content: missing shipped manifest")
    for path in manifests:
        label = path.relative_to(root).as_posix()
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                raise ValueError("manifest must be an object")
            fields = {"regions", "locations", "landmarks"} & data.keys()
            record = {
                "path": label,
                "legacy": not fields,
                "named_locations": 0,
                "pending_facts": [],
            }
            if fields:
                if len(fields) != 3 or not isinstance(data["landmarks"], list):
                    raise ValueError("named metadata requires regions/locations/landmarks arrays")
                for kind in ("regions", "locations"):
                    entries = data[kind]
                    if not isinstance(entries, list) or not entries:
                        raise ValueError(f"{kind} must be a nonempty array")
                    for entry in entries:
                        if not isinstance(entry, dict) or not isinstance(
                            entry.get("name_key"), str
                        ):
                            raise ValueError(f"{kind} requires string name_key")
                        if not entry["name_key"]:
                            raise ValueError(f"{kind} requires nonempty name_key")
                        check(label, 1, entry["name_key"])
                        if kind == "locations":
                            identifier = entry.get("id")
                            if not isinstance(identifier, str) or not identifier.strip():
                                raise ValueError("location requires nonempty string id")
                            record["named_locations"] += 1
                            fact = f"location.{identifier}.fact"
                            if fact not in keys:
                                record["pending_facts"].append(fact)
                            else:
                                check(label, 1, fact)
                record["pending_facts"].sort()
            metadata.append(record)
        except (OSError, ValueError, TypeError) as exc:
            errors.append(f"{label}: {exc}")
    return {
        "keys": len(keys),
        "references": [dict(path=p, line=n, key=k) for p, n, k in sorted(references)],
        "dynamic": [dict(path=p, line=n, expression=k) for p, n, k in sorted(dynamic)],
        "metadata": metadata,
        "errors": sorted(set(errors)),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        report = audit(args.root.resolve())
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(
            f"Locale audit: {report['keys']} keys, {len(report['references'])} static references, "
            f"{len(report['dynamic'])} dynamic expressions (not fully resolved)"
        )
    for error in report["errors"]:
        print(error, file=sys.stderr)
    return int(bool(report["errors"]))


if __name__ == "__main__":
    raise SystemExit(main())
