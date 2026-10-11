"""Synthetic diagnostic records only; no phone observations or gate evidence."""

import copy
import json

import pytest

from tools.performance_report import build_report
from tools.performance_validation import parse_report, validate_report


def report(**updates):
    stats = dict(
        samples=2,
        pending=1,
        dropped=0,
        latency_window_samples=2,
        mean_ms=2.0,
        max_ms=3.0,
        p50_ms=1.0,
        p95_ms=3.0,
        frame_intervals=2,
        frame_over_budget=1,
        frame_budget_usec=16667,
        frame_mean_ms=20.0,
        frame_max_ms=30.0,
        fps=50.0,
    )
    stats.update(updates)
    return build_report(
        [dict(schema_version=1, reason="background", stats=stats)],
        "Synthetic Żółć phone",
        "a" * 64,
        "b" * 40,
    )


def test_existing_report_roundtrip_normalizes_identity_without_mutation_or_aliases():
    packet = report()
    packet["operator_supplied"]["device"] = "  Synthetic Żółć phone  "
    before = copy.deepcopy(packet)
    result = validate_report(packet)
    assert packet == before
    assert result["operator_supplied"]["device"] == "Synthetic Żółć phone"
    result["windows"][0]["stats"]["samples"] = 99
    result["operator_supplied"]["device"] = "changed"
    result["summary"]["samples"] = 99
    assert packet == before
    parsed = parse_report(json.dumps(before, ensure_ascii=False))
    assert parsed["summary"]["samples"] == 2
    assert parsed["windows"] == before["windows"]


@pytest.mark.parametrize(
    "field",
    [
        "samples",
        "pending",
        "dropped",
        "frame_intervals",
        "frame_over_budget",
        "window_count",
        "max_frame_ms",
        "max_latency_ms",
        "max_window_p95_ms",
    ],
)
def test_every_tampered_summary_value_is_rejected(field):
    packet = report()
    packet["summary"][field] += 1
    with pytest.raises(ValueError, match=f"summary.{field}"):
        validate_report(packet)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("samples", True),
        ("window_count", 1.0),
        ("max_frame_ms", True),
        ("max_frame_ms", float("nan")),
        ("max_latency_ms", float("inf")),
        ("max_window_p95_ms", 10**400),
    ],
)
def test_summary_numeric_types_are_strict(field, value):
    packet = report()
    packet["summary"][field] = value
    with pytest.raises(ValueError, match=field):
        validate_report(packet)


@pytest.mark.parametrize("path", ["root", "identity", "summary"])
def test_exact_shapes_reject_unknown_and_missing_keys(path):
    packet = report()
    target = (
        packet
        if path == "root"
        else packet["operator_supplied"]
        if path == "identity"
        else packet["summary"]
    )
    original = copy.deepcopy(target)
    target["extra"] = 1
    with pytest.raises(ValueError):
        validate_report(packet)
    target.clear()
    target.update(original)
    target.pop(next(iter(original)))
    with pytest.raises(ValueError):
        validate_report(packet)


@pytest.mark.parametrize(
    "fragment", ['"schema_version": 1', '"device": "Synthetic Żółć phone"', '"pending": 1']
)
def test_duplicate_keys_at_root_identity_and_nested_windows(fragment):
    text = json.dumps(report(), ensure_ascii=False)
    text = text.replace(fragment, fragment + ", " + fragment, 1)
    with pytest.raises(ValueError, match="duplicate key"):
        parse_report(text)


@pytest.mark.parametrize(
    ("field", "value"),
    [("device", " "), ("device", True), ("apk_sha256", "A" * 64), ("source_sha", "b" * 39)],
)
def test_identity_validation_reuses_original_contract(field, value):
    packet = report()
    packet["operator_supplied"][field] = value
    with pytest.raises(ValueError, match="identity"):
        validate_report(packet)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("pending", True),
        ("frame_budget_usec", 1),
        ("p95_ms", float("inf")),
        ("fps", 1),
        ("mean_ms", 10**400),
    ],
)
def test_original_window_validation_remains_required(field, value):
    packet = report()
    packet["windows"][0]["stats"][field] = value
    with pytest.raises(ValueError, match="windows"):
        validate_report(packet)


@pytest.mark.parametrize("value", [[], {}, None])
def test_nonempty_window_array_is_required(value):
    packet = report()
    packet["windows"] = value
    with pytest.raises(ValueError, match="windows"):
        validate_report(packet)


@pytest.mark.parametrize("text", ["{", "null", "[]", '{"x":NaN}', '{"x":Infinity}'])
def test_malformed_shapes_and_nonfinite_json(text):
    with pytest.raises(ValueError):
        parse_report(text)


def test_unavailable_and_valid_zero_values_survive_validation():
    packet = report(
        samples=0,
        latency_window_samples=0,
        mean_ms=-1,
        max_ms=-1,
        p50_ms=-1,
        p95_ms=-1,
        frame_intervals=0,
        frame_over_budget=0,
        fps=-1,
        frame_mean_ms=-1,
        frame_max_ms=-1,
    )
    assert validate_report(packet) == packet
    zero = report(mean_ms=0, max_ms=0, p50_ms=0, p95_ms=0)
    assert parse_report(json.dumps(zero)) == zero
    numeric = report()
    numeric["summary"]["max_frame_ms"] = 30
    assert validate_report(numeric)["summary"]["max_frame_ms"] == 30.0


@pytest.mark.parametrize("value", [True, 1.0, 2])
def test_schema_version_is_exact_integer_one(value):
    packet = report()
    packet["schema_version"] = value
    with pytest.raises(ValueError, match="schema_version"):
        validate_report(packet)
