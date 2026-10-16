"""Compare parallel and serial imports in independent tracked-file project copies."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

POLICY = "import/use_multiple_threads=false"
BAD_LOG = re.compile(r"^(?:ERROR|SCRIPT ERROR|WARNING)", re.M)


def attempt(root: Path, godot: str, mode: str, number: int, logs: Path) -> dict:
    tracked = (
        subprocess.check_output(["git", "ls-files", "-z", "--", "game"], cwd=root)
        .decode()
        .split("\0")
    )
    with tempfile.TemporaryDirectory(prefix=f"wow-import-{mode}-") as directory:
        shadow = Path(directory)
        source_hash = hashlib.sha256()
        for name in filter(None, tracked):
            source = root / name
            destination = shadow / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            source_hash.update(name.encode() + b"\0" + source.read_bytes())
        project = shadow / "game"
        settings = project / "project.godot"
        text = settings.read_text()
        if text.count(POLICY) != 1:
            raise ValueError("source project must declare the canonical serial policy once")
        if mode == "parallel":
            settings.write_text(text.replace(POLICY, POLICY.replace("false", "true")))
        started = time.monotonic()
        try:
            result = subprocess.run(
                [godot, "--headless", "--path", str(project), "--import", "--quit"],
                capture_output=True,
                text=True,
                timeout=120,
                check=False,
            )
            output = result.stdout + result.stderr
            status = result.returncode
        except subprocess.TimeoutExpired as exc:
            output = str(exc)
            status = 124
        elapsed = round(time.monotonic() - started, 3)
        (logs / f"{mode}-{number:02d}.log").write_text(output)
        diagnostics = [line for line in output.splitlines() if BAD_LOG.match(line)]
        translations = {
            path.relative_to(project).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted((project / "locale").glob("*.translation"))
        }
        return {
            "mode": mode,
            "attempt": number,
            "seconds": elapsed,
            "exit_code": status,
            "clean": status == 0 and not diagnostics,
            "diagnostics": diagnostics[:8],
            "source_sha256": source_hash.hexdigest(),
            "translation_sha256": translations,
        }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--logs", type=Path, default=Path("/tmp/wow-t0335-imports"))
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    args.logs.mkdir(parents=True, exist_ok=True)
    report: dict = {
        "engine": subprocess.check_output([args.godot, "--version"], text=True).strip(),
        "baseline_commit": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=root, text=True
        ).strip(),
        "copy_policy": "git-tracked game files only; no .godot or generated translations",
        "attempts": [],
    }
    success = True
    serial_hashes: dict | None = None
    baseline_hashes: dict | None = None
    for mode in ("parallel", "serial"):
        for number in range(1, 11):
            result = attempt(root, args.godot, mode, number, args.logs)
            report["attempts"].append(result)
            print(
                f"{mode} {number}/10: exit={result['exit_code']} "
                f"clean={result['clean']} seconds={result['seconds']}",
                flush=True,
            )
            if mode == "parallel":
                if not result["clean"]:
                    break
                baseline_hashes = result["translation_sha256"]
            else:
                hashes = result["translation_sha256"]
                if not result["clean"] or not hashes:
                    success = False
                    break
                if serial_hashes is None:
                    serial_hashes = hashes
                if hashes != serial_hashes or (baseline_hashes and hashes != baseline_hashes):
                    success = False
                    break
        if not success:
            break
    report["serial_pass"] = success
    report["baseline_reproduced"] = any(
        not row["clean"] for row in report["attempts"] if row["mode"] == "parallel"
    )
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    return int(not success)


if __name__ == "__main__":
    raise SystemExit(main())
