"""Synthetic session fixtures; no real participant or phone results."""

import copy
import json

import pytest

from tools.playtest_summary import build_summary, render_summary
from tools.playtest_worksheet import build_worksheet


def observed():
    packet = build_worksheet()
    packet["build"].update(source_sha="a" * 40, apk_sha256="b" * 64, content_sha256="c" * 64)
    for session in packet["sessions"]:
        session.update(
            **packet["build"],
            date="2026-10-11",
            device="synthetic phone",
            android_version="16",
            refresh_hz=60,
            power_saving=False,
            outsider=True,
            clean_campaign=True,
            answers_hidden=True,
            instructions_given=False,
            help_given=False,
            wants_continue=True,
            start_slot=1,
            final_slot=8,
            active_seconds=1200,
            first_word="KOT",
            stalls=[],
            notes="fixture",
        )
    return packet


def test_blank_records_retain_missing_evidence_and_unknown_continue_counts():
    report = build_summary(build_worksheet())
    assert set(report) == {"schema_version", "operator_supplied", "build", "sessions", "totals"}
    assert report["operator_supplied"] is True
    assert report["totals"] == dict(
        recorded_sessions=5,
        sessions_with_missing=5,
        sessions_with_deviations=0,
        sessions_with_complete_protocol_record=0,
        active_seconds_observed=0,
        wants_continue_yes=0,
        wants_continue_no=0,
        wants_continue_unknown=5,
    )
    assert "build.apk_sha256" in report["sessions"][0]["missing"]
    assert "active_seconds" in report["sessions"][0]["missing"]
    assert report["sessions"][0]["deviations"] == []


def test_complete_five_records_are_counts_not_gate_verdicts():
    packet = observed()
    for session in packet["sessions"][:2]:
        session["wants_continue"] = False
    report = build_summary(packet)
    assert report["totals"] == dict(
        recorded_sessions=5,
        sessions_with_missing=0,
        sessions_with_deviations=0,
        sessions_with_complete_protocol_record=5,
        active_seconds_observed=6000,
        wants_continue_yes=3,
        wants_continue_no=2,
        wants_continue_unknown=0,
    )
    assert all(row["missing"] == row["deviations"] == [] for row in report["sessions"])
    assert not {"pass", "go", "qualifying", "fun_gate"} & report.keys()
    assert json.loads(json.dumps(report)) == report


@pytest.mark.parametrize(
    ("field", "value", "code"),
    [
        ("outsider", False, "insider"),
        ("clean_campaign", False, "campaign_not_clean"),
        ("start_slot", 2, "start_not_one"),
        ("answers_hidden", False, "answers_visible"),
        ("instructions_given", True, "instructions_given"),
        ("help_given", True, "help_given"),
        ("active_seconds", 1199, "under_20_active_minutes"),
        ("source_sha", "d" * 40, "mismatched_source_sha"),
        ("apk_sha256", "e" * 64, "mismatched_apk_sha256"),
        ("content_sha256", "f" * 64, "mismatched_content_sha256"),
    ],
)
def test_known_protocol_departures_preserve_observations(field, value, code):
    packet = observed()
    packet["sessions"][0][field] = value
    row = build_summary(packet)["sessions"][0]
    assert row["deviations"] == [code]
    assert row["missing"] == []
    assert row["observations"][field] == value


def test_missing_is_separate_from_departures_and_zero_is_observed():
    packet = observed()
    packet["sessions"][0].update(outsider=None, active_seconds=0, wants_continue=None)
    report = build_summary(packet)
    row = report["sessions"][0]
    assert row["missing"] == ["outsider", "wants_continue"]
    assert row["deviations"] == ["under_20_active_minutes"]
    assert report["totals"]["active_seconds_observed"] == 4800
    assert report["totals"]["wants_continue_unknown"] == 1
    assert report["totals"]["sessions_with_complete_protocol_record"] == 4


def test_unrecorded_hash_is_never_reported_as_a_mismatch():
    packet = observed()
    packet["build"]["source_sha"] = None
    packet["sessions"][0]["apk_sha256"] = None
    row = build_summary(packet)["sessions"][0]
    assert row["missing"] == ["apk_sha256", "build.source_sha"]
    assert row["deviations"] == []


def test_no_word_no_stalls_differ_from_unknown():
    packet = observed()
    packet["sessions"][0].update(first_word="", stalls=[])
    packet["sessions"][1].update(first_word=None, stalls=None)
    report = build_summary(packet)
    assert report["sessions"][0]["missing"] == []
    assert report["sessions"][1]["missing"] == ["first_word", "stalls"]
    text = render_summary(packet)
    assert "`first_word`: none observed" in text and "`first_word`: not recorded" in text
    assert "`stalls`: none observed" in text and "`stalls`: not recorded" in text


def test_summary_deep_copies_records_and_does_not_mutate_input():
    packet = observed()
    before = copy.deepcopy(packet)
    report = build_summary(packet)
    assert packet == before
    report["sessions"][0]["observations"]["stalls"].append("synthetic")
    report["build"]["source_sha"] = None
    assert packet == before
    packet["sessions"][1]["notes"] = "changed"
    assert report["sessions"][1]["observations"]["notes"] == "fixture"


def test_markdown_escapes_notes_and_observations_and_remains_deterministic():
    packet = observed()
    unsafe = "Żółć | `code` [link](x) \\ **bold**\n<script>alert(1)</script>\r\n# fake"
    packet["sessions"][0].update(notes=unsafe, device=unsafe, first_word=unsafe, stalls=[unsafe])
    before = copy.deepcopy(packet)
    text = render_summary(packet)
    assert text == render_summary(packet) and packet == before
    assert "<script>" not in text and unsafe not in text
    for escaped in (r"\|", r"\`", r"\[", r"\\", "&lt;script&gt;", "<br>", "Żółć"):
        assert escaped in text
    assert "Operator-supplied" in text and "not human acceptance" in text


@pytest.mark.parametrize("function", [build_summary, render_summary])
def test_invalid_input_is_rejected_before_any_report(function):
    packet = observed()
    packet["sessions"][0]["active_seconds"] = True
    with pytest.raises(ValueError, match="active_seconds"):
        function(packet)
