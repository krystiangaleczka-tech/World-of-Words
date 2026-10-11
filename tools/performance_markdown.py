"""Readable engine diagnostics; no physical-latency or acceptance conclusion."""

from __future__ import annotations

import html

if __package__:
    from .performance_validation import validate_report
else:
    from performance_validation import validate_report


def _escape(text: str) -> str:
    escaped = html.escape(text, quote=False).replace("\\", "\\\\")
    for character in "`*_{}[]()#+-.!|~":
        escaped = escaped.replace(character, "\\" + character)
    return escaped.replace("\r\n", "\n").replace("\r", "\n").replace("\n", "<br>")


def _value(field: str, value: int | float) -> str:
    if value == -1:
        return "not available"
    unit = (
        "ms"
        if field.endswith("_ms")
        else "Hz"
        if field == "fps"
        else "us"
        if field == "frame_budget_usec"
        else "count"
    )
    return f"{'0' if value == 0 else value} {unit}"


def render_report(document: dict) -> str:
    """Keep every ordered window and its coverage in an escaped Markdown report."""
    report = validate_report(document)
    lines = [
        "# Diagnostic performance report",
        "",
        "Operator-supplied device/APK/source identity; measurements and context are unverified.",
        "",
        "## Identity",
        "",
    ]
    for field, value in sorted(report["operator_supplied"].items()):
        lines.append(f"- `{field}`: {_escape(value)}")
    lines.extend(["", "## Summary", ""])
    for field, value in sorted(report["summary"].items()):
        lines.append(f"- `{field}`: {_value(field, value)}")
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "Input timing covers accepted dispatch to engine post-draw, "
            "not physical finger-to-photon latency.",
            "Window p50/p95 cover the latest 512 consumed inputs; mean/max cover the whole window.",
            "max_window_p95_ms is the maximum of window p95 values, not a capture percentile.",
            "The fixed 16667 us frame budget is diagnostic, not an NFR acceptance threshold.",
            "fps in Hz describes rendered frame frequency, not detected display refresh rate.",
            "Pending and dropped inputs expose coverage gaps. "
            "No capture FPS average is synthesized.",
            "Actual A15 feel, word review, outsider sessions and Chris's FUN GATE remain separate.",
        ]
    )
    for index, window in enumerate(report["windows"], 1):
        lines.extend(["", f"## Window {index}: {window['reason']}", ""])
        for field, value in sorted(window["stats"].items()):
            lines.append(f"- `{field}`: {_value(field, value)}")
    return "\n".join(lines) + "\n"
