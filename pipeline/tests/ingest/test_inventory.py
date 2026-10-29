"""Pinned source inventory checks bytes first and never writes archives."""

import hashlib
import io
import zipfile
from dataclasses import replace

import pytest
from wordgame_pipeline.ingest.inventory import inspect_source_inventory
from wordgame_pipeline.ingest.source import SourcePin


def example(words):
    payload = ("\n".join(words) + "\n").encode("utf-8")
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("slowa.txt", payload)
    raw = output.getvalue()
    pin = SourcePin(
        id="sjp-pl-game",
        version="20260101",
        url="https://sjp.pl/sl/growy/sjp-20260101.zip",
        sha256=hashlib.sha256(raw).hexdigest(),
        archive_bytes=len(raw),
        member="slowa.txt",
        member_bytes=len(payload),
        entry_count=len(words),
        encoding="utf-8",
        license="CC-BY-4.0",
        license_url="https://creativecommons.org/licenses/by/4.0/",
        source_url="https://sjp.pl/sl/growy/",
    )
    return raw, pin


def test_exact_duplicates_and_length_bounds():
    data, pin = example(["KOT", "TOK", "KOT", "DOMY"])
    report = inspect_source_inventory(data, pin)
    assert report.source_sha256 == pin.sha256
    assert (report.rows, report.unique_words, report.duplicate_rows) == (4, 3, 1)
    assert report.repeated_words == ("KOT",)
    assert (report.minimum_length, report.maximum_length) == (3, 4)
    assert inspect_source_inventory(data, pin) == report


def test_clean_source_and_invalid_checksums_fail_closed():
    data, pin = example(["KOT", "DOM"])
    assert inspect_source_inventory(data, pin).repeated_words == ()
    for broken in (data + b"x", data[:-1]):
        with pytest.raises(ValueError):
            inspect_source_inventory(broken, pin)
    with pytest.raises(ValueError):
        inspect_source_inventory(data, replace(pin, entry_count=3))
    with pytest.raises(ValueError):
        inspect_source_inventory(data, None)
