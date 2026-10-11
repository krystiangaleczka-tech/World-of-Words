"""Template checks only; these fixtures do not represent participant observations."""

import json

from tools.playtest_worksheet import build_worksheet, render_worksheet

FIELDS = {
    "participant_id",
    "date",
    "device",
    "android_version",
    "refresh_hz",
    "power_saving",
    "outsider",
    "clean_campaign",
    "answers_hidden",
    "instructions_given",
    "help_given",
    "wants_continue",
    "start_slot",
    "final_slot",
    "active_seconds",
    "source_sha",
    "apk_sha256",
    "content_sha256",
    "first_word",
    "stalls",
    "notes",
}


def test_five_distinct_structural_ids_and_exact_schema():
    packet = build_worksheet()
    assert set(packet) == {"schema_version", "build", "sessions"}
    assert type(packet["schema_version"]) is int and packet["schema_version"] == 1
    assert packet["build"] == dict(source_sha=None, apk_sha256=None, content_sha256=None)
    assert [s["participant_id"] for s in packet["sessions"]] == ["P01", "P02", "P03", "P04", "P05"]
    assert all(set(s) == FIELDS for s in packet["sessions"])


def test_every_observation_is_unrecorded_including_protocol_and_duration():
    for session in build_worksheet()["sessions"]:
        assert session["notes"] == ""
        assert all(session[k] is None for k in FIELDS - {"participant_id", "notes"})
        assert "pass" not in session and "fun_gate" not in session


def test_nested_records_are_independent_between_sessions_and_calls():
    first, second = build_worksheet(), build_worksheet()
    first["sessions"][0]["stalls"] = ["synthetic stall"]
    first["sessions"][0]["notes"] = 'fixture: Żółć | "quoted"\nnew line'
    first["build"]["source_sha"] = "a" * 40
    first["sessions"].append({})
    assert first["sessions"][1]["stalls"] is None
    assert second == build_worksheet()
    assert len(second["sessions"]) == 5
    assert second["build"]["source_sha"] is None


def test_render_roundtrips_deterministically_with_a_single_trailing_newline():
    text = render_worksheet()
    assert text == render_worksheet()
    assert text.endswith("\n") and not text.endswith("\n\n")
    assert json.loads(text) == build_worksheet()
    assert text == json.dumps(build_worksheet(), sort_keys=True, indent=2) + "\n"


def test_render_remains_blank_after_caller_changes_its_worksheet():
    changed = build_worksheet()
    changed["sessions"][0]["notes"] = 'fixture "quote"\nŻółć'
    changed["sessions"][0]["active_seconds"] = 1200
    assert json.loads(render_worksheet())["sessions"][0]["active_seconds"] is None
    assert "\\nŻółć" not in render_worksheet()
