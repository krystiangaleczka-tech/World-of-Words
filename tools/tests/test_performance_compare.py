"""Synthetic comparisons; not evidence of device performance changes."""

import copy

import pytest

from tools.performance_compare import compare_reports, render_comparison
from tools.performance_report import build_report
from tools.tests.test_performance_validation import report


def test_positive_negative_zero_deltas_include_all_nine_fields():
    first = report()
    second = report(pending=0, dropped=4, max_ms=2.0, mean_ms=1.0, p50_ms=1.0, p95_ms=2.0)
    result = compare_reports(first, second)
    assert set(result) == {
        "schema_version",
        "operator_supplied",
        "baseline",
        "candidate",
        "metadata_differences",
        "deltas",
    }
    assert result["operator_supplied"] is True
    assert result["deltas"] == dict(
        samples=0,
        pending=-1,
        dropped=4,
        frame_intervals=0,
        frame_over_budget=0,
        window_count=0,
        max_frame_ms=0.0,
        max_latency_ms=-1.0,
        max_window_p95_ms=-1.0,
    )
    assert result["metadata_differences"] == []
    text = render_comparison(first, second)
    assert "| `pending` | 1 count | 0 count | -1 count |" in text
    assert "| `max_latency_ms` | 3.0 ms | 2.0 ms | -1.0 ms |" in text


@pytest.mark.parametrize("side", ["baseline", "candidate", "both"])
def test_unavailable_maxima_produce_null_not_subtracted_sentinels(side):
    available = report()
    unavailable = report(
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
    first = unavailable if side in ("baseline", "both") else available
    second = unavailable if side in ("candidate", "both") else available
    result = compare_reports(first, second)
    for field in ("max_frame_ms", "max_latency_ms", "max_window_p95_ms"):
        assert result["deltas"][field] is None
    assert "not available" in render_comparison(first, second)
    assert type(result["deltas"]["samples"]) is int


def test_metadata_changes_are_exact_sorted_and_not_errors():
    first = report()
    second = report()
    second["operator_supplied"].update(
        device="different synthetic scenario/OS", apk_sha256="c" * 64, source_sha="d" * 40
    )
    result = compare_reports(first, second)
    assert result["metadata_differences"] == ["apk_sha256", "device", "source_sha"]
    assert result["candidate"]["operator_supplied"] == second["operator_supplied"]
    first["operator_supplied"]["device"] = "  " + second["operator_supplied"]["device"] + "  "
    assert compare_reports(first, second)["metadata_differences"] == ["apk_sha256", "source_sha"]


def test_unequal_window_counts_and_coverage_are_retained_without_alignment():
    first = report()
    windows = copy.deepcopy(first["windows"] * 2)
    windows[1]["reason"] = "exit"
    second = build_report(windows, "Synthetic Żółć phone", "a" * 64, "b" * 40)
    result = compare_reports(first, second)
    assert result["deltas"]["window_count"] == 1
    assert result["deltas"]["samples"] == 2
    assert len(result["baseline"]["windows"]) == 1
    assert result["candidate"]["windows"] == windows
    assert "### Window 2: exit" in render_comparison(first, second)
    assert not {"matched_windows", "capture_p95", "average_fps", "winner", "pass"} & result.keys()


def test_outputs_are_deep_independent_even_when_same_input_is_used_twice():
    packet = report()
    before = copy.deepcopy(packet)
    result = compare_reports(packet, packet)
    result["baseline"]["windows"][0]["stats"]["pending"] = 0
    result["candidate"]["operator_supplied"]["device"] = "changed"
    assert packet == before
    assert result["candidate"]["windows"] == before["windows"]
    assert result["baseline"]["operator_supplied"] == before["operator_supplied"]


def test_render_is_deterministic_escaped_and_preserves_original_inputs():
    first = report()
    second = report()
    second["operator_supplied"]["device"] = "Żółć | `code` [link](x)\n<script>x</script>"
    before = copy.deepcopy((first, second))
    text = render_comparison(first, second)
    assert text == render_comparison(first, second) and (first, second) == before
    assert text.endswith("\n") and not text.endswith("\n\n")
    assert "<script>" not in text and "&lt;script&gt;" in text and r"\|" in text
    assert "not causal evidence" in text and "No winner" in text
    assert "## Baseline capture" in text and "## Candidate capture" in text


@pytest.mark.parametrize("side", ["baseline", "candidate"])
@pytest.mark.parametrize("function", [compare_reports, render_comparison])
def test_invalid_either_input_is_rejected(side, function):
    first = report()
    second = report()
    (first if side == "baseline" else second)["summary"]["samples"] += 1
    with pytest.raises(ValueError, match="samples"):
        function(first, second)
