"""Descriptive two-capture differences; no causal or acceptance verdict."""

from __future__ import annotations

if __package__:
    from .performance_markdown import render_report
    from .performance_validation import MAXIMA, validate_report
else:
    from performance_markdown import render_report
    from performance_validation import MAXIMA, validate_report


def compare_reports(baseline: dict, candidate: dict) -> dict:
    """Keep validated copies and subtract only available summary values."""
    first = validate_report(baseline)
    second = validate_report(candidate)
    differences = sorted(
        key
        for key in first["operator_supplied"]
        if first["operator_supplied"][key] != second["operator_supplied"][key]
    )
    deltas = {}
    for field, value in first["summary"].items():
        next_value = second["summary"][field]
        deltas[field] = (
            None if field in MAXIMA and (value == -1 or next_value == -1) else next_value - value
        )
    return {
        "schema_version": 1,
        "operator_supplied": True,
        "baseline": first,
        "candidate": second,
        "metadata_differences": differences,
        "deltas": deltas,
    }


def _cell(field: str, value: int | float | None, delta: bool = False) -> str:
    if value is None or (not delta and field in MAXIMA and value == -1):
        return "not available"
    unit = "ms" if field in MAXIMA else "count"
    return f"{'0' if value == 0 else value} {unit}"


def render_comparison(baseline: dict, candidate: dict) -> str:
    """Render descriptive deltas and full windows without aligning observations."""
    comparison = compare_reports(baseline, candidate)
    differences = ", ".join(comparison["metadata_differences"]) or "none"
    lines = [
        "# Performance capture comparison",
        "",
        "Operator-supplied context remains unverified. "
        "Differences are descriptive, not causal evidence.",
        "No winner or human acceptance decision is inferred. "
        "Check device/OS/refresh/scenarios and coverage.",
        "",
        f"Metadata differences: {differences}",
        "",
        "Deltas are candidate minus baseline; unavailable maxima are not subtracted.",
        "",
        "| Summary field | Baseline | Candidate | Delta |",
        "|---|---|---|---|",
    ]
    for field in sorted(comparison["deltas"]):
        first = _cell(field, comparison["baseline"]["summary"][field])
        second = _cell(field, comparison["candidate"]["summary"][field])
        delta = _cell(field, comparison["deltas"][field], delta=True)
        lines.append(f"| `{field}` | {first} | {second} | {delta} |")
    for name in ("baseline", "candidate"):
        lines.extend(["", f"## {name.title()} capture"])
        for line in render_report(comparison[name]).splitlines()[1:]:
            lines.append("#" + line if line.startswith("## ") else line)
    return "\n".join(lines) + "\n"
