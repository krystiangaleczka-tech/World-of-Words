"""Synthetic report rendering; not phone observations."""

import copy

import pytest

from tools.performance_markdown import render_report
from tools.performance_report import build_report
from tools.tests.test_performance_validation import report


def test_every_summary_and_window_field_is_retained_in_original_order():
    packet = report()
    second = copy.deepcopy(packet["windows"][0])
    second["reason"] = "navigation"
    second["stats"].update(pending=8, dropped=1)
    packet = build_report([packet["windows"][0], second], "Synthetic phone", "a" * 64, "b" * 40)
    before = copy.deepcopy(packet)
    text = render_report(packet)
    assert packet == before
    assert text.index("## Window 1: background") < text.index("## Window 2: navigation")
    for field in packet["summary"]:
        assert f"`{field}`:" in text
    for section in text.split("## Window ")[1:]:
        for field in packet["windows"][0]["stats"]:
            assert f"`{field}`:" in section
    assert "`pending`: 8 count" in text and "`dropped`: 1 count" in text
    assert "`frame_budget_usec`: 16667 us" in text
    assert "`fps`: 50.0 Hz" in text
    assert "`frame_mean_ms`: 20.0 ms" in text
    assert "`max_latency_ms`: 3.0 ms" in text


def test_unavailable_is_distinct_from_valid_zero():
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
    text = render_report(unavailable)
    assert "`fps`: not available" in text and "`max_frame_ms`: not available" in text
    assert "-1 ms" not in text and "`samples`: 0 count" in text
    zero = render_report(report(mean_ms=0, max_ms=0, p50_ms=0, p95_ms=0))
    assert "`mean_ms`: 0 ms" in zero and "`p95_ms`: 0 ms" in zero


def test_identity_escapes_markdown_html_newlines_and_preserves_polish():
    packet = report()
    device = "Żółć | `code` [link](x) \\ **bold**\n# fake <script>x</script>\r\nnext"
    packet["operator_supplied"]["device"] = device
    before = copy.deepcopy(packet)
    text = render_report(packet)
    assert packet == before and device not in text and "<script>" not in text
    for value in (r"\|", r"\`", r"\[", r"\\", "&lt;script&gt;", "<br>", "Żółć"):
        assert value in text
    assert packet["operator_supplied"]["apk_sha256"] in text
    assert packet["operator_supplied"]["source_sha"] in text


def test_determinism_single_newline_and_interpretation_limits():
    text = render_report(report())
    assert text == render_report(report())
    assert text.endswith("\n") and not text.endswith("\n\n")
    for phrase in (
        "Operator-supplied",
        "not physical finger-to-photon",
        "latest 512",
        "not a capture percentile",
        "not an NFR acceptance",
        "coverage gaps",
        "FUN GATE",
    ):
        assert phrase in text
    assert "No capture FPS average is synthesized" in text
    summary = text.split("## Summary")[1].split("## Interpretation")[0]
    assert "`fps`" not in summary


@pytest.mark.parametrize("field", ["samples", "max_window_p95_ms"])
def test_invalid_summary_is_rejected_before_rendering(field):
    packet = report()
    packet["summary"][field] += 1
    with pytest.raises(ValueError, match=field):
        render_report(packet)


def test_bounded_recent_window_and_pending_capacity_remain_visible():
    text = render_report(report(samples=513, latency_window_samples=512, pending=512, dropped=4))
    for field, value in (
        ("samples", 513),
        ("latency_window_samples", 512),
        ("pending", 512),
        ("dropped", 4),
    ):
        assert f"`{field}`: {value} count" in text
