"""Synthetic capture fixtures; these are not phone measurements."""

import copy
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "performance_report.py"
SPEC = importlib.util.spec_from_file_location("performance_report", SCRIPT)
REPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPORT)


def window(**updates):
    stats = dict(
        samples=2,
        pending=1,
        dropped=0,
        latency_window_samples=2,
        mean_ms=2.0,
        max_ms=3.0,
        p50_ms=1.0,
        p95_ms=3.0,
        frame_intervals=2,
        frame_over_budget=1,
        frame_budget_usec=16667,
        frame_mean_ms=20.0,
        frame_max_ms=30.0,
        fps=50.0,
    )
    stats.update(updates)
    return dict(schema_version=1, reason="navigation", stats=stats)


def line(record):
    return "10-11 12:00:00 I godot: WOW_PERF_V1 " + json.dumps(record)


def test_mixed_capture_order_totals_and_window_p95_without_mutation():
    records = [
        window(),
        window(samples=513, latency_window_samples=512, p95_ms=2.0, dropped=4, frame_max_ms=40.0),
    ]
    before = copy.deepcopy(records)
    parsed = REPORT.parse_capture("noise\n" + "\n".join(map(line, records)))
    report = REPORT.build_report(parsed, " Synthetic fixture ", "a" * 64, "b" * 40)
    assert report["windows"] == before == records
    assert report["operator_supplied"]["device"] == "Synthetic fixture"
    assert report["summary"] == dict(
        samples=515,
        pending=2,
        dropped=4,
        frame_intervals=4,
        frame_over_budget=2,
        window_count=2,
        max_frame_ms=40.0,
        max_latency_ms=3.0,
        max_window_p95_ms=3.0,
    )
    assert "pass" not in report and "fps" not in report["summary"]


def test_pending_only_and_zero_latency_are_available_correctly():
    pending = window(
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
    assert REPORT.parse_capture(line(pending)) == [pending]
    zero = window(mean_ms=0, max_ms=0, p50_ms=0, p95_ms=0)
    assert REPORT.parse_capture(line(zero)) == [zero]


@pytest.mark.parametrize(
    "key,value",
    [
        ("samples", True),
        ("pending", 513),
        ("dropped", -1),
        ("frame_intervals", 1.5),
        ("frame_over_budget", 3),
        ("frame_budget_usec", 16666),
        ("latency_window_samples", 1),
        ("fps", float("inf")),
        ("p95_ms", float("nan")),
        ("mean_ms", True),
        ("mean_ms", 4),
        ("p50_ms", -1),
        ("p95_ms", 0),
        ("frame_mean_ms", 0),
        ("frame_max_ms", 10),
        ("fps", 49),
        ("unknown", 1),
    ],
)
def test_invalid_measures_counts_and_ranges(key, value):
    with pytest.raises(ValueError, match="Capture line 2"):
        REPORT.parse_capture("unrelated\n" + line(window(**{key: value})))


@pytest.mark.parametrize(
    "text",
    [
        "",
        "unrelated",
        "WOW_PERF_V1",
        "WOW_PERF_V1 {}",
        "WOW_PERF_V1 []",
        "WOW_PERF_V1 null",
        "WOW_PERF_V1 {",
        "WOW_PERF_V1 {} trailing",
        'WOW_PERF_V1 {"schema_version":1,"schema_version":1}',
    ],
)
def test_malformed_empty_or_unrelated_capture(text):
    with pytest.raises(ValueError):
        REPORT.parse_capture(text)


@pytest.mark.parametrize(
    "change",
    [
        dict(schema_version=True),
        dict(schema_version=2),
        dict(reason="unknown"),
        dict(extra=1),
        dict(stats=None),
    ],
)
def test_invalid_window_schema(change):
    record = window()
    record.update(change)
    with pytest.raises(ValueError):
        REPORT.parse_capture(line(record))


@pytest.mark.parametrize(
    "changes",
    [
        dict(samples=0, latency_window_samples=0),
        dict(frame_intervals=0, frame_over_budget=0),
        dict(
            pending=0,
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
        ),
    ],
)
def test_unavailable_and_empty_window_consistency(changes):
    with pytest.raises(ValueError):
        REPORT.parse_capture(line(window(**changes)))


@pytest.mark.parametrize(
    "device,apk,source",
    [
        (" ", "a" * 64, "b" * 40),
        ("phone", "A" * 64, "b" * 40),
        ("phone", "a" * 63, "b" * 40),
        ("phone", "a" * 64, "g" * 40),
    ],
)
def test_supplied_identity_validation(device, apk, source):
    with pytest.raises(ValueError):
        REPORT.build_report([window()], device, apk, source)


def test_cli_entrypoint_errors_and_read_only(tmp_path, capsys):
    capture = tmp_path / "capture.log"
    original = (line(window()) + "\n").encode()
    capture.write_bytes(original)
    args = [
        str(capture),
        "--device",
        "Synthetic fixture",
        "--apk-sha256",
        "a" * 64,
        "--source-sha",
        "b" * 40,
    ]
    assert REPORT.main(args) == 0
    assert json.loads(capsys.readouterr().out)["summary"]["window_count"] == 1
    run = subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True)
    assert run.returncode == 0 and json.loads(run.stdout)["schema_version"] == 1
    assert capture.read_bytes() == original and list(tmp_path.iterdir()) == [capture]
    capture.write_text("bad")
    assert REPORT.main(args) == 1
    output = capsys.readouterr()
    assert not output.out and "No diagnostic windows" in output.err
    capture.unlink()
    assert REPORT.main(args) == 1
    assert not capsys.readouterr().out
    with pytest.raises(SystemExit) as exc:
        REPORT.main([])
    assert exc.value.code == 2
