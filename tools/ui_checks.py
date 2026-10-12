"""Bounded syntax guards for feature/component UI; no interprocedural inference."""

from __future__ import annotations

import ast
import csv
import re
from pathlib import Path
from typing import Any

from gdtoolkit.parser import parser as gd_parser
from lark import Token, Tree
from lark.exceptions import LarkError

SCOPES = ("game/features", "game/ui/components")
COPY = {"text", "tooltip_text", "placeholder_text", "accessibility_name"}
VISUAL = re.compile(
    r"(?:font_size|content_margin_\w+|corner_radius_\w+|custom_minimum_size|offset_[\w]+)$"
)
HEX = re.compile(r"^#[0-9a-fA-F]{3,8}$")
FORMAT = re.compile(r"%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[sdifgeExXouc%]")


def walk(node: Any):
    yield node
    if isinstance(node, Tree):
        for child in node.children:
            yield from walk(child)


def string(node: Any) -> str | None:
    if isinstance(node, Tree) and node.data in ("expr", "string_name"):
        return string(node.children[0]) if len(node.children) == 1 else None
    if isinstance(node, Tree) and node.data == "string":
        return ast.literal_eval(str(node.children[0]))
    return None


def call(node: Tree) -> tuple[str, list[Any]]:
    target, *args = node.children
    if isinstance(target, Tree):
        target = target.children[-1]
    return str(target), args


def numbers(node: Any) -> list[float]:
    values = []
    for token in walk(node):
        if isinstance(token, Token) and token.type in {"NUMBER", "HEX", "BIN"}:
            text = str(token).replace("_", "")
            values.append(float(int(text, 0)) if token.type in {"HEX", "BIN"} else float(text))
    return values


def copy_literals(node: Any):
    if isinstance(node, Tree) and node.data in ("standalone_call", "getattr_call"):
        name, args = call(node)
        target = node.children[0]
        setting = (
            isinstance(target, Tree)
            and str(target.children[0]) == "ProjectSettings"
            and name == "get_setting"
        )
        if name in {"tr", "tr_n"} or setting:
            # Protect keys only, not concatenated copy or other arguments.
            for arg in args[1:]:
                yield from copy_literals(arg)
            return
    value = string(node)
    if value is not None:
        yield value
    elif isinstance(node, Tree):
        for child in node.children:
            yield from copy_literals(child)


def is_copy(value: str) -> bool:
    return any(c.isalpha() for c in FORMAT.sub("", value))


def gd_errors(source: str, mode: str, keys: set[str]) -> list[tuple[int, str]]:
    tree = gd_parser.parse(source, gather_metadata=True)
    errors = []
    for node in walk(tree):
        if not isinstance(node, Tree):
            continue
        reason = None
        if mode == "tokens" and node.data == "string" and HEX.fullmatch(string(node) or ""):
            reason = "R-UI-3: literal colour; use Palette"
        if node.data in ("standalone_call", "getattr_call"):
            name, args = call(node)
            if mode == "tokens":
                target = node.children[0]
                colour_call = name in {"Color", "Color8"} or (
                    isinstance(target, Tree) and str(target.children[0]) == "Color"
                )
                if colour_call and args and (numbers(args[0]) or string(args[0]) is not None):
                    reason = "R-UI-3: literal colour constructor/factory"
                index = {
                    "tween_property": 3,
                    "tween_method": 3,
                    "tween_interval": 0,
                    "add_theme_font_size_override": 1,
                    "add_theme_constant_override": 1,
                }.get(name)
                if index is not None and len(args) > index:
                    values = numbers(args[index])
                    bad = (
                        any(n > 0 for n in values)
                        if name.startswith("tween_")
                        else any(n not in {-1, 0, 1} for n in values)
                    )
                    if bad:
                        reason = "R-UI-3: numeric visual/duration argument; use Tokens"
            else:
                if name == "tr" and args and string(args[0]) is not None:
                    if string(args[0]) not in keys:
                        reason = "R-UI-4: unknown translation key " + repr(string(args[0]))
                index = {
                    "set_text": 0,
                    "set_tooltip_text": 0,
                    "add_item": 0,
                    "add_tab": 0,
                    "draw_string": 2,
                    "draw_multiline_string": 2,
                }.get(name)
                if (
                    index is not None
                    and len(args) > index
                    and any(is_copy(s) for s in copy_literals(args[index]))
                ):
                    reason = "R-UI-4: literal player copy; use translation keys"
        if node.data == "assnmnt_expr" or str(node.data).endswith("assgnd"):
            target, *_, value = node.children
            field = str(target.children[-1]) if isinstance(target, Tree) else str(target)
            if (
                mode == "strings"
                and field in COPY
                and any(is_copy(s) for s in copy_literals(value))
            ):
                reason = "R-UI-4: literal player copy; use translation keys"
            if (
                mode == "tokens"
                and (
                    VISUAL.fullmatch(field)
                    or (
                        isinstance(target, Tree)
                        and any(VISUAL.fullmatch(str(part)) for part in target.children)
                    )
                )
                and any(n not in {-1, 0, 1} for n in numbers(value))
            ):
                reason = "R-UI-3: numeric visual property; use Tokens"
        if reason:
            errors.append((node.meta.line, reason))
    return errors


def scene_errors(source: str, mode: str, keys: set[str]) -> list[tuple[int, str]]:
    errors = []
    section = False
    header = False
    lines = source.splitlines()
    index = 0
    while index < len(lines):
        line = index + 1
        text = lines[index].strip()
        index += 1
        if not text or text.startswith(";"):
            continue
        if text.startswith("["):
            section = bool(
                re.fullmatch(
                    r"\[(?:gd_scene|ext_resource|sub_resource|node|connection|editable)(?:\s.*)?\]",
                    text,
                )
            )
            header = header or (section and text.startswith("[gd_scene"))
            if not section:
                errors.append((line, "invalid scene section"))
            continue
        if not section or "=" not in text:
            errors.append((line, "invalid scene property"))
            continue
        field, value = (s.strip() for s in text.split("=", 1))
        if not re.fullmatch(r"[A-Za-z_][\w/.:\-]*", field):
            errors.append((line, "invalid scene property name"))
            continue
        # GDScript's expression grammar covers Godot scene literal values, including arrays.
        while True:
            try:
                tree = gd_parser.parse("var scene_value = " + value + "\n", gather_metadata=True)
                break
            except LarkError:
                if (
                    index >= len(lines)
                    or lines[index].lstrip().startswith("[")
                    or "=" in lines[index]
                ):
                    tree = None
                    break
                value += "\n" + lines[index]
                index += 1
        if tree is None:
            errors.append((line, "invalid scene property value"))
            continue
        # The parser variant name is irrelevant: inspect only its value expression.
        assignment = next(
            n
            for n in walk(tree)
            if isinstance(n, Tree) and str(n.data).endswith(("assigned", "assgnd"))
        )
        expression = assignment.children[-1]
        if mode == "strings" and field in COPY:
            literal = string(expression)
            if literal is None:
                errors.append((line, "invalid scene text property"))
            elif is_copy(literal) and literal not in keys:
                errors.append((line, "R-UI-4: literal scene copy"))
        if mode == "tokens":
            visual = (
                VISUAL.fullmatch(field)
                or field.startswith("theme_override_constants/")
                or field.startswith("theme_override_font_sizes/")
            )
            for node in walk(expression):
                if (
                    isinstance(node, Tree)
                    and node.data in {"standalone_call", "getattr_call"}
                    and call(node)[0] == "Color"
                ):
                    errors.append((line, "R-UI-3: literal scene colour"))
                if isinstance(node, Tree) and HEX.fullmatch(string(node) or ""):
                    errors.append((line, "R-UI-3: literal scene colour"))
            if visual and any(n not in {-1, 0, 1} for n in numbers(expression)):
                errors.append((line, "R-UI-3: numeric scene visual property"))
            if field in {"duration", "wait_time"} and any(n > 0 for n in numbers(expression)):
                errors.append((line, "R-UI-3: numeric scene duration"))
    if not header:
        errors.append((1, "missing gd_scene header"))
    return errors


def scan(root: Path, mode: str) -> list[str]:
    errors = []
    keys: set[str] = set()
    if mode == "strings":
        try:
            paths = sorted((root / "game/locale").glob("*.csv"))
            if not paths:
                raise ValueError("missing locale CSV catalogue")
            for path in paths:
                with path.open(newline="", encoding="utf-8") as stream:
                    for row in csv.DictReader(stream):
                        key = row["keys"]
                        if not key:
                            raise ValueError("empty locale key")
                        keys.add(key)
            if not keys:
                raise ValueError("empty locale CSV catalogue")
        except (OSError, KeyError, ValueError) as exc:
            errors.append(f"game/locale: {exc}")
    for scope in SCOPES:
        directory = root / scope
        if not directory.is_dir():
            errors.append(f"{scope}: required scan directory missing")
            continue
        for path in sorted(directory.rglob("*")):
            if path.suffix not in {".gd", ".tscn"}:
                continue
            label = path.relative_to(root).as_posix()
            try:
                source = path.read_text(encoding="utf-8")
                findings = (
                    gd_errors(source, mode, keys)
                    if path.suffix == ".gd"
                    else scene_errors(source, mode, keys)
                )
                errors.extend(f"{label}:{line}: {reason}" for line, reason in findings)
            except (OSError, ValueError, SyntaxError, LarkError) as exc:
                errors.append(f"{label}: cannot parse source: {exc}")
    return sorted(set(errors))


def main(mode: str, argv: list[str] | None = None) -> int:
    import argparse
    import sys

    parser = argparse.ArgumentParser(description=f"Check UI {mode} literals")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    errors = scan(parser.parse_args(argv).root.resolve(), mode)
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    if not errors:
        print(f"OK: UI {mode} guards")
    return int(bool(errors))
