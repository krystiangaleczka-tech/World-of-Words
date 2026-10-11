"""Read-only debug capture diagnostics. No physical-latency or device gate verdict."""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

MARKER = "WOW_PERF_V1"
COUNTS = (
    "samples",
    "pending",
    "dropped",
    "frame_intervals",
    "frame_over_budget",
    "frame_budget_usec",
    "latency_window_samples",
)
MEASURES = ("fps", "mean_ms", "max_ms", "p50_ms", "p95_ms", "frame_mean_ms", "frame_max_ms")


def _unique(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def _validate(window: dict) -> None:
    if (
        not isinstance(window, dict)
        or set(window) != {"schema_version", "reason", "stats"}
        or type(window["schema_version"]) is not int
        or window["schema_version"] != 1
        or window["reason"] not in ("navigation", "background", "exit")
    ):
        raise ValueError("Invalid window schema or reason")
    s = window["stats"]
    if not isinstance(s, dict) or set(s) != set(COUNTS + MEASURES):
        raise ValueError("Invalid snapshot fields")
    if any(type(s[k]) is not int or s[k] < 0 for k in COUNTS):
        raise ValueError("Invalid snapshot counts")
    if any(type(s[k]) not in (int, float) or not math.isfinite(s[k]) for k in MEASURES):
        raise ValueError("Invalid snapshot measures")
    if (
        s["pending"] > 512
        or s["latency_window_samples"] != min(s["samples"], 512)
        or s["frame_budget_usec"] != 16667
        or s["frame_over_budget"] > s["frame_intervals"]
    ):
        raise ValueError("Inconsistent snapshot counts or budget")
    if s["samples"] == 0:
        if any(s[k] != -1 for k in ("mean_ms", "max_ms", "p50_ms", "p95_ms")):
            raise ValueError("Invalid unavailable latency")
    elif not (0 <= s["mean_ms"] <= s["max_ms"] and 0 <= s["p50_ms"] <= s["p95_ms"] <= s["max_ms"]):
        raise ValueError("Invalid latency ranges")
    if s["frame_intervals"] == 0:
        if any(s[k] != -1 for k in ("fps", "frame_mean_ms", "frame_max_ms")):
            raise ValueError("Invalid unavailable frames")
    elif not (
        0 < s["frame_mean_ms"] <= s["frame_max_ms"]
        and math.isclose(s["fps"], 1000 / s["frame_mean_ms"], rel_tol=1e-6, abs_tol=1e-6)
    ):
        raise ValueError("Invalid frame ranges or FPS")
    if s["frame_intervals"] + s["samples"] + s["pending"] + s["dropped"] == 0:
        raise ValueError("Empty diagnostic window")


def parse_capture(text: str) -> list[dict]:
    windows = []
    for number, line in enumerate(text.splitlines(), 1):
        if MARKER not in line:
            continue
        try:
            _, marker, payload = line.partition(MARKER + " ")
            if not marker:
                raise ValueError("Missing marker separator")
            window = json.loads(payload, object_pairs_hook=_unique)
            _validate(window)
        except (ValueError, TypeError, OverflowError) as exc:
            raise ValueError(f"Capture line {number}: {exc}") from exc
        windows.append(window)
    if not windows:
        raise ValueError("No diagnostic windows in capture")
    return windows


def build_report(windows: list[dict], device: str, apk_sha256: str, source_sha: str) -> dict:
    if not isinstance(device, str) or not device.strip():
        raise ValueError("Device description is required")
    if (
        not isinstance(apk_sha256, str)
        or not re.fullmatch(r"[0-9a-f]{64}", apk_sha256)
        or not isinstance(source_sha, str)
        or not re.fullmatch(r"[0-9a-f]{40}", source_sha)
    ):
        raise ValueError("Invalid APK/source hash")
    if not windows:
        raise ValueError("No diagnostic windows")
    for window in windows:
        _validate(window)
    summary = {
        k: sum(w["stats"][k] for w in windows)
        for k in ("samples", "pending", "dropped", "frame_intervals", "frame_over_budget")
    }
    summary.update(
        {
            "window_count": len(windows),
            "max_frame_ms": max(w["stats"]["frame_max_ms"] for w in windows),
            "max_latency_ms": max(w["stats"]["max_ms"] for w in windows),
            "max_window_p95_ms": max(w["stats"]["p95_ms"] for w in windows),
        }
    )
    return {
        "schema_version": 1,
        "operator_supplied": {
            "device": device.strip(),
            "apk_sha256": apk_sha256,
            "source_sha": source_sha,
        },
        "windows": windows,
        "summary": summary,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    for option in ("device", "apk-sha256", "source-sha"):
        parser.add_argument("--" + option, required=True)
    args = parser.parse_args(argv)
    try:
        report = build_report(
            parse_capture(args.capture.read_text(encoding="utf-8")),
            args.device,
            args.apk_sha256,
            args.source_sha,
        )
        output = json.dumps(report, ensure_ascii=False, allow_nan=False, sort_keys=True)
    except (OSError, ValueError, TypeError, OverflowError) as exc:
        print(f"Performance capture: {exc}", file=sys.stderr)
        return 1
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
