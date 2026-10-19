"""Locale regressions are enforced by the existing tools pytest CI job."""

import csv
import subprocess
import sys

import pytest

from tools.check_locale import ROOT, load_catalog, signature


def source(root, rows=None, text=None):
    path = root / "game/locale/probe.csv"
    path.parent.mkdir(parents=True, exist_ok=True)
    if text is not None:
        path.write_text(text, encoding="utf-8")
    else:
        with path.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(["keys", "pl", "en"])
            writer.writerows(rows or [["probe.main.title", "Tytuł", "Title"]])
    return path


def test_quoted_unicode_multiline_copy_and_readonly(tmp_path):
    path = source(tmp_path, [["probe.main.title", 'Żółć, "cytat"\nLinia', 'Title, "quote"\nLine']])
    before = path.read_bytes()
    assert load_catalog(tmp_path)["probe.main.title"]["pl"] == 'Żółć, "cytat"\nLinia'
    assert path.read_bytes() == before


@pytest.mark.parametrize(
    "text",
    [
        "key,pl,en\nprobe.main.title,T,Title\n",
        "keys,en,pl\nprobe.main.title,Title,T\n",
        "keys,pl,en\n",
        "keys,pl,en\nprobe.main.title,T\n",
        "keys,pl,en\nprobe.main.title,T,Title,Extra\n",
        "keys,pl,en\nwrong.main.title,T,Title\n",
        "keys,pl,en\nprobe.title,T,Title\n",
        "keys,pl,en\nprobe.main.title,,Title\n",
        "keys,pl,en\nprobe.main.title,T, Title\n",
        "keys,pl,en\nprobe.main.title,T,Title\nprobe.main.title,T,Title\n",
        'keys,pl,en\nprobe.main.title,"unfinished,Title\n',
        'keys,pl,en\nprobe.main.title,"quoted"junk,Title\n',
        "keys,pl,en\nprobe.main.title,T,Ti\x00tle\n",
        'keys,pl,en\nprobe.main.title,Ty"tuł,Title\n',
    ],
)
def test_invalid_csv_fails_with_physical_path_and_line(tmp_path, text):
    source(tmp_path, text=text)
    with pytest.raises(ValueError, match=r"game/locale/probe.csv:\d+:"):
        load_catalog(tmp_path)


def test_missing_and_invalid_utf8_fail(tmp_path):
    with pytest.raises(ValueError, match="missing locale"):
        load_catalog(tmp_path)
    path = source(tmp_path)
    path.write_bytes(b"keys,pl,en\nprobe.main.title,\xff,Title\n")
    with pytest.raises(ValueError, match="probe.csv"):
        load_catalog(tmp_path)


@pytest.mark.parametrize("text", ["100%", "115%", "130%", "100% / 130%", "Done %%"])
def test_numeric_and_escaped_percentage_has_no_arguments(text):
    assert signature(text) == ()


def test_format_signature_preserves_order_and_dynamic_arguments():
    assert signature("%s %03d %*.*f %% %v %c %x %o %X") == (
        "s",
        "d",
        "int",
        "int",
        "f",
        "v",
        "c",
        "x",
        "o",
        "X",
    )
    assert signature("%+03d") == signature("%-9d")


@pytest.mark.parametrize("text", ["%q", "%", "%2$", "%*", "%1.", "%d 100%"])
def test_broken_or_unsupported_format_rejected(text):
    with pytest.raises(ValueError):
        signature(text)


@pytest.mark.parametrize("en", ["Count", "%s", "%d %d", "%s %d", "%*d"])
def test_placeholder_contract_mismatch_rejected(tmp_path, en):
    source(tmp_path, [["probe.main.count", "%d %s" if en == "%s %d" else "%d", en]])
    with pytest.raises(ValueError, match="format arguments differ"):
        load_catalog(tmp_path)


def test_multiline_diagnostics_are_sorted_and_physical(tmp_path):
    source(tmp_path, text='keys,pl,en\nprobe.main.title,"a\nb",\nprobe.main.next,,Next\n')
    with pytest.raises(ValueError) as error:
        load_catalog(tmp_path)
    lines = str(error.value).splitlines()
    assert lines == sorted(lines)
    assert ":3:" in lines[0] and ":4:" in lines[1]


def test_actual_repository_catalog():
    assert load_catalog(ROOT)


def test_cli_from_other_cwd_success_and_failure_without_writes(tmp_path):
    command = [sys.executable, str(ROOT / "tools/check_locale.py")]
    result = subprocess.run(command, cwd=tmp_path, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert "bilingual locale keys" in result.stdout
    assert list(tmp_path.iterdir()) == []
    path = source(tmp_path, [["probe.main.title", "%d", "%s"]])
    before = path.read_bytes()
    failed = subprocess.run(command + ["--root", str(tmp_path)], capture_output=True, text=True)
    assert failed.returncode == 1 and "arguments differ" in failed.stderr
    assert path.read_bytes() == before


def test_bare_quote_after_multiline_cell_reports_physical_line(tmp_path):
    source(
        tmp_path, text='keys,pl,en\nprobe.main.title,"a\nb",Title\nprobe.main.next,Ty"tuł,Next\n'
    )
    with pytest.raises(ValueError, match="probe.csv:4: malformed CSV quoting"):
        load_catalog(tmp_path)
