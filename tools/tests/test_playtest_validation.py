"""Synthetic records test structure only, not human acceptance."""

import copy
import json

import pytest

from tools.playtest_validation import parse_worksheet, validate_worksheet
from tools.playtest_worksheet import build_worksheet, render_worksheet


def test_blank_and_partial_records_roundtrip_without_mutation():
    packet = build_worksheet()
    packet["sessions"][0].update(active_seconds=0, help_given=True, first_word="", stalls=[])
    packet["sessions"][1].update(device="synthetic Żółć phone", refresh_hz=59.94, outsider=False)
    before = copy.deepcopy(packet)
    assert validate_worksheet(packet) is None
    assert parse_worksheet(json.dumps(packet)) == before == packet
    assert parse_worksheet(render_worksheet()) == build_worksheet()


@pytest.mark.parametrize("field", ["schema_version", "build", "sessions"])
def test_missing_root_fields_have_a_field_path(field):
    packet = build_worksheet()
    del packet[field]
    with pytest.raises(ValueError, match=field):
        validate_worksheet(packet)


@pytest.mark.parametrize("where", ["root", "build", "session"])
def test_unknown_and_duplicate_keys_at_every_object_depth(where):
    packet = build_worksheet()
    target = (
        packet
        if where == "root"
        else packet["build"]
        if where == "build"
        else packet["sessions"][0]
    )
    target["unexpected"] = None
    with pytest.raises(ValueError, match="unexpected"):
        validate_worksheet(packet)
    text = render_worksheet()
    needle = {
        "root": '"schema_version": 1',
        "build": '"source_sha": null',
        "session": '"participant_id": "P01"',
    }[where]
    duplicate = text.replace(needle, needle + ", " + needle, 1)
    with pytest.raises(ValueError, match="duplicate key"):
        parse_worksheet(duplicate)


@pytest.mark.parametrize("value", [True, 1.0, 0, "1", None])
def test_schema_version_requires_exact_integer_one(value):
    packet = build_worksheet()
    packet["schema_version"] = value
    with pytest.raises(ValueError, match="schema_version"):
        validate_worksheet(packet)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("participant_id", "P00"),
        ("participant_id", "p01"),
        ("participant_id", "P100"),
        ("participant_id", None),
        ("date", "2026-02-30"),
        ("date", "20261011"),
        ("date", "2026-1-1"),
        ("date", 5),
        ("device", "  "),
        ("android_version", True),
        ("first_word", " \n"),
        ("active_seconds", -1),
        ("active_seconds", True),
        ("active_seconds", 1.5),
        ("start_slot", 0),
        ("final_slot", True),
        ("help_given", 1),
        ("outsider", "yes"),
        ("refresh_hz", True),
        ("refresh_hz", 0),
        ("refresh_hz", float("nan")),
        ("refresh_hz", float("inf")),
        ("refresh_hz", 10**400),
        ("notes", None),
        ("stalls", "none"),
        ("stalls", [""]),
        ("stalls", [False]),
        ("source_sha", "A" * 40),
        ("apk_sha256", "a" * 63),
        ("content_sha256", 1),
    ],
)
def test_bad_observation_reports_its_field(field, value):
    packet = build_worksheet()
    packet["sessions"][0][field] = value
    with pytest.raises(ValueError, match=rf"sessions\[0\].{field}"):
        validate_worksheet(packet)


@pytest.mark.parametrize("count", [0, 100])
def test_invalid_session_cardinality(count):
    packet = build_worksheet()
    packet["sessions"] = [copy.deepcopy(packet["sessions"][0]) for _ in range(count)]
    with pytest.raises(ValueError, match="sessions"):
        validate_worksheet(packet)


def test_single_record_and_duplicate_id_and_missing_session_field():
    packet = build_worksheet()
    packet["sessions"] = packet["sessions"][:1]
    validate_worksheet(packet)
    packet["sessions"].append(copy.deepcopy(packet["sessions"][0]))
    with pytest.raises(ValueError, match="participant_id"):
        validate_worksheet(packet)
    packet["sessions"].pop()
    del packet["sessions"][0]["stalls"]
    with pytest.raises(ValueError, match="stalls"):
        validate_worksheet(packet)


@pytest.mark.parametrize("text", ["{", "[]", "null", "true", ' {"x": NaN}', '{"x": Infinity}'])
def test_invalid_json_shape_or_nonfinite_literals(text):
    with pytest.raises(ValueError):
        parse_worksheet(text)


def test_full_evidence_is_valid_even_when_short_or_assisted_or_different_build():
    packet = build_worksheet()
    packet["build"].update(source_sha="a" * 40, apk_sha256="b" * 64, content_sha256="c" * 64)
    packet["sessions"] = packet["sessions"][:1]
    packet["sessions"][0].update(
        date="2024-02-29",
        device="synthetic phone",
        android_version="16",
        refresh_hz=120,
        power_saving=False,
        outsider=False,
        clean_campaign=False,
        answers_hidden=False,
        instructions_given=True,
        help_given=True,
        wants_continue=False,
        start_slot=2,
        final_slot=1,
        active_seconds=1,
        source_sha="d" * 40,
        apk_sha256="e" * 64,
        content_sha256="f" * 64,
        first_word="ŻÓŁĆ",
        stalls=["synthetic stall"],
        notes="fixture",
    )
    validate_worksheet(packet)
    assert parse_worksheet(json.dumps(packet)) == packet


@pytest.mark.parametrize(
    ("field", "value"), [("build", []), ("sessions", {}), ("sessions", [None])]
)
def test_nested_object_shapes(field, value):
    packet = build_worksheet()
    packet[field] = value
    with pytest.raises(ValueError, match=field):
        validate_worksheet(packet)


def test_bad_common_build_hash_and_input_independence():
    packet = build_worksheet()
    packet["build"]["source_sha"] = "unknown"
    before = copy.deepcopy(packet)
    with pytest.raises(ValueError, match="build.source_sha"):
        validate_worksheet(packet)
    assert packet == before
