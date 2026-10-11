"""Strict worksheet shape validation; valid syntax is not a playtest verdict."""

from __future__ import annotations

import json
import math
import re
from datetime import date

if __package__:
    from .playtest_worksheet import BOOL_FIELDS, HASH_LENGTHS, INT_FIELDS, build_worksheet
else:
    from playtest_worksheet import BOOL_FIELDS, HASH_LENGTHS, INT_FIELDS, build_worksheet


def _keys(value: object, expected: set[str], path: str) -> None:
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected object")
    missing = expected - value.keys()
    extra = value.keys() - expected
    if missing:
        raise ValueError(f"{path}.{sorted(missing)[0]}: missing field")
    if extra:
        raise ValueError(f"{path}.{sorted(extra, key=str)[0]}: unknown field")


def _hashes(value: dict, path: str) -> None:
    for key, length in HASH_LENGTHS.items():
        item = value[key]
        if item is not None and (
            not isinstance(item, str) or not re.fullmatch(rf"[0-9a-f]{{{length}}}", item)
        ):
            raise ValueError(f"{path}.{key}: expected lowercase {length}-digit hex or null")


def _text(value: object, path: str, allow_empty: bool = False) -> None:
    if not isinstance(value, str) or (not value.strip() and not (allow_empty and value == "")):
        raise ValueError(f"{path}: expected nonblank string")


def validate_worksheet(document: object) -> None:
    """Accept incomplete observations, reject malformed data, leave input intact."""
    _keys(document, {"schema_version", "build", "sessions"}, "worksheet")
    if type(document["schema_version"]) is not int or document["schema_version"] != 1:
        raise ValueError("schema_version: expected integer 1")
    _keys(document["build"], set(HASH_LENGTHS), "build")
    _hashes(document["build"], "build")
    sessions = document["sessions"]
    if not isinstance(sessions, list) or not 1 <= len(sessions) <= 99:
        raise ValueError("sessions: expected one to 99 records")
    expected = set(build_worksheet()["sessions"][0])
    seen = set()
    for index, session in enumerate(sessions):
        path = f"sessions[{index}]"
        _keys(session, expected, path)
        identifier = session["participant_id"]
        if (
            not isinstance(identifier, str)
            or not re.fullmatch(r"P[0-9]{2}", identifier)
            or identifier == "P00"
            or identifier in seen
        ):
            raise ValueError(f"{path}.participant_id: expected unique P01..P99")
        seen.add(identifier)
        _hashes(session, path)
        for key in BOOL_FIELDS:
            if session[key] is not None and type(session[key]) is not bool:
                raise ValueError(f"{path}.{key}: expected boolean or null")
        for key in INT_FIELDS:
            item = session[key]
            minimum = 0 if key == "active_seconds" else 1
            if item is not None and (type(item) is not int or item < minimum):
                raise ValueError(f"{path}.{key}: expected integer >= {minimum} or null")
        for key in ("date", "device", "android_version", "first_word"):
            item = session[key]
            if item is not None:
                _text(item, f"{path}.{key}", allow_empty=key == "first_word")
        if session["date"] is not None:
            try:
                if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", session["date"]):
                    raise ValueError("date shape")
                date.fromisoformat(session["date"])
            except ValueError as exc:
                raise ValueError(f"{path}.date: expected valid YYYY-MM-DD") from exc
        refresh = session["refresh_hz"]
        if refresh is not None:
            try:
                valid = type(refresh) in (int, float) and math.isfinite(refresh) and refresh > 0
            except OverflowError:
                valid = False
            if not valid:
                raise ValueError(f"{path}.refresh_hz: expected finite positive number or null")
        stalls = session["stalls"]
        if stalls is not None:
            if not isinstance(stalls, list):
                raise ValueError(f"{path}.stalls: expected array or null")
            for offset, stall in enumerate(stalls):
                _text(stall, f"{path}.stalls[{offset}]")
        if not isinstance(session["notes"], str):
            raise ValueError(f"{path}.notes: expected string")


def _unique(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"JSON.{key}: duplicate key")
        result[key] = value
    return result


def _constant(value: str) -> None:
    raise ValueError(f"JSON: nonfinite constant {value}")


def parse_worksheet(text: str) -> dict:
    """Parse strict JSON, rejecting duplicate keys even inside nested objects."""
    try:
        document = json.loads(text, object_pairs_hook=_unique, parse_constant=_constant)
    except (TypeError, RecursionError) as exc:
        raise ValueError("JSON: expected valid worksheet text") from exc
    validate_worksheet(document)
    return document
