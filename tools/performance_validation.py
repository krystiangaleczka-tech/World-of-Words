"""Validate exported diagnostic data; operator identity remains unverified."""

from __future__ import annotations

import copy
import json
import math

if __package__:
    from .performance_report import build_report
else:
    from performance_report import build_report

MAXIMA = ("max_frame_ms", "max_latency_ms", "max_window_p95_ms")


def _keys(value: object, expected: set[str], path: str) -> None:
    if not isinstance(value, dict) or set(value) != expected:
        raise ValueError(f"{path}: expected exactly {', '.join(sorted(expected))}")


def validate_report(document: object) -> dict:
    """Recompute the summary and return independent, normalized data."""
    _keys(document, {"schema_version", "operator_supplied", "windows", "summary"}, "report")
    if type(document["schema_version"]) is not int or document["schema_version"] != 1:
        raise ValueError("schema_version: expected integer 1")
    identity = document["operator_supplied"]
    _keys(identity, {"device", "apk_sha256", "source_sha"}, "operator_supplied")
    windows = document["windows"]
    if not isinstance(windows, list) or not windows:
        raise ValueError("windows: expected nonempty array")
    try:
        canonical = build_report(
            windows, identity["device"], identity["apk_sha256"], identity["source_sha"]
        )
    except (ValueError, TypeError, OverflowError, RecursionError) as exc:
        raise ValueError(f"windows/identity: {exc}") from exc
    summary = document["summary"]
    _keys(summary, set(canonical["summary"]), "summary")
    for field, expected in canonical["summary"].items():
        value = summary[field]
        try:
            valid = (
                type(value) in (int, float) and math.isfinite(value)
                if field in MAXIMA
                else type(value) is int
            )
        except OverflowError:
            valid = False
        if not valid or value != expected:
            raise ValueError(f"summary.{field}: does not match computed windows")
    return copy.deepcopy(canonical)


def _unique(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"JSON.{key}: duplicate key")
        result[key] = value
    return result


def _constant(value: str) -> None:
    raise ValueError(f"JSON: nonfinite constant {value}")


def parse_report(text: str) -> dict:
    """Parse strict JSON, then validate recorded counts against the windows."""
    try:
        document = json.loads(text, object_pairs_hook=_unique, parse_constant=_constant)
    except (TypeError, OverflowError, RecursionError) as exc:
        raise ValueError("JSON: invalid performance report") from exc
    return validate_report(document)
