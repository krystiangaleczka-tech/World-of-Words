"""NFR-05 warning-only package size report; container sizes are growth proxies."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

BUDGET_BYTES = 80_000_000
WARNING_BYTES = BUDGET_BYTES * 9 // 10
MEASUREMENTS = ("debug-apk", "release-apk", "release-aab", "release-ipa", "store-download")
LIMITATION = (
    "Package/container sizes are growth proxies. Actual per-device store download "
    "with one content language remains a release gate; no split/thinning estimate is made."
)


def measure(path: Path, measurement: str) -> dict:
    """Read the artifact once, measuring the same bytes that are hashed."""
    if measurement not in MEASUREMENTS:
        raise ValueError("unknown measurement label")
    if not path.is_file():
        raise ValueError("artifact must be a regular file")
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            size += len(chunk)
            digest.update(chunk)
    if size == 0:
        raise ValueError("artifact is empty")
    return {
        "schema_version": 1,
        "artifact": path.name,
        "measurement": measurement,
        "size_bytes": size,
        "sha256": digest.hexdigest(),
        "budget_bytes": BUDGET_BYTES,
        "warning_bytes": WARNING_BYTES,
        "budget_percent": size * 100 / BUDGET_BYTES,
        "warning": size >= WARNING_BYTES,
        "over_budget": size > BUDGET_BYTES,
        "limitation": LIMITATION,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--measurement", choices=MEASUREMENTS, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.artifact.resolve() == args.report.resolve() or (
            args.report.exists() and args.artifact.samefile(args.report)
        ):
            raise ValueError("report must not overwrite the artifact")
        result = measure(args.artifact, args.measurement)
        summary = (
            f"App size ({result['measurement']}): {result['size_bytes']} bytes; "
            f"{result['budget_percent']:.2f}% of {BUDGET_BYTES} bytes.\n{LIMITATION}\n"
        )
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        if summary_path := os.environ.get("GITHUB_STEP_SUMMARY"):
            with Path(summary_path).open("a", encoding="utf-8") as output:
                output.write(summary + "\n")
    except (OSError, ValueError) as exc:
        print(f"App size check failed: {exc}", file=sys.stderr)
        return 1
    print(summary, end="")
    if result["warning"]:
        print("::warning title=App size budget::Artifact reached 90% of the 80 MB budget.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
