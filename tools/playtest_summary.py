"""Read-only evidence summaries; operator assertions remain unverified."""

from __future__ import annotations

import copy
import html

if __package__:
    from .playtest_validation import validate_worksheet
else:
    from playtest_validation import validate_worksheet


def build_summary(document: dict) -> dict:
    """Separate missing observations from known departures from the protocol."""
    validate_worksheet(document)
    build = document["build"]
    rows = []
    for session in document["sessions"]:
        missing = [key for key, value in session.items() if value is None]
        missing.extend(f"build.{key}" for key, value in build.items() if value is None)
        deviations = []
        for field, value, code in (
            ("outsider", False, "insider"),
            ("clean_campaign", False, "campaign_not_clean"),
            ("answers_hidden", False, "answers_visible"),
            ("instructions_given", True, "instructions_given"),
            ("help_given", True, "help_given"),
        ):
            if session[field] is value:
                deviations.append(code)
        if session["start_slot"] is not None and session["start_slot"] != 1:
            deviations.append("start_not_one")
        if session["active_seconds"] is not None and session["active_seconds"] < 1200:
            deviations.append("under_20_active_minutes")
        for field, expected in build.items():
            if expected is not None and session[field] is not None and session[field] != expected:
                deviations.append(f"mismatched_{field}")
        rows.append(
            {
                "participant_id": session["participant_id"],
                "observations": copy.deepcopy(session),
                "missing": sorted(missing),
                "deviations": sorted(deviations),
            }
        )
    sessions = document["sessions"]
    totals = {
        "recorded_sessions": len(rows),
        "sessions_with_missing": sum(bool(row["missing"]) for row in rows),
        "sessions_with_deviations": sum(bool(row["deviations"]) for row in rows),
        "sessions_with_complete_protocol_record": sum(
            not row["missing"] and not row["deviations"] for row in rows
        ),
        "active_seconds_observed": sum(s["active_seconds"] or 0 for s in sessions),
        "wants_continue_yes": sum(s["wants_continue"] is True for s in sessions),
        "wants_continue_no": sum(s["wants_continue"] is False for s in sessions),
        "wants_continue_unknown": sum(s["wants_continue"] is None for s in sessions),
    }
    return {
        "schema_version": 1,
        "operator_supplied": True,
        "build": copy.deepcopy(build),
        "sessions": rows,
        "totals": totals,
    }


def _escape(text: str) -> str:
    escaped = html.escape(text, quote=False).replace("\\", "\\\\")
    for character in "`*_{}[]()#+-.!|~":
        escaped = escaped.replace(character, "\\" + character)
    return escaped.replace("\r\n", "\n").replace("\r", "\n").replace("\n", "<br>")


def _value(field: str, value: object) -> str:
    if value is None:
        return "not recorded"
    if value == "" and field == "first_word" or isinstance(value, list) and not value:
        return "none observed"
    if isinstance(value, list):
        return "; ".join(_escape(item) for item in value)
    if isinstance(value, bool):
        return str(value).lower()
    if value == "":
        return "(empty)"
    return _escape(str(value))


def render_summary(document: dict) -> str:
    """Render escaped observations and evidence coverage, leaving gates to Chris."""
    report = build_summary(document)
    lines = [
        "# Outsider playtest observations",
        "",
        "Operator-supplied observations. Format and completeness do not verify truth "
        "or decide FUN GATE.",
        "",
        "## Intended common build",
        "",
    ]
    for field, value in sorted(report["build"].items()):
        lines.append(f"- `{field}`: {_value(field, value)}")
    lines.extend(["", "## Recorded totals", ""])
    for field, value in report["totals"].items():
        lines.append(f"- `{field}`: {value}")
    lines.extend(["", "Complete protocol records are a completeness count, not human acceptance."])
    for row in report["sessions"]:
        lines.extend(["", f"## {row['participant_id']}", ""])
        for field, value in sorted(row["observations"].items()):
            if field != "participant_id":
                lines.append(f"- `{field}`: {_value(field, value)}")
        for field in ("missing", "deviations"):
            values = ", ".join(_escape(item) for item in row[field]) or "none"
            lines.append(f"- {field}: {values}")
    return "\n".join(lines) + "\n"
