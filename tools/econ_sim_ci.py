"""Fail-closed relevant-path detection for the economy simulation CI job."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
RELATED = {
    "tools/econ_sim.py",
    "tools/econ_sim_ci.py",
    "tools/tests/test_econ_sim.py",
    "tools/tests/test_econ_sim_ci.py",
    ".github/workflows/ci.yml",
}


def relevant(paths: list[str]) -> bool:
    return any(
        path in RELATED
        or (PurePosixPath(path).parent.as_posix() == "game/data/config" and path.endswith(".json"))
        for path in paths
    )


def changed(repo: Path, base: str, head: str = "HEAD") -> bool:
    if not base or set(base) == {"0"}:
        return True
    result = subprocess.run(
        ["git", "diff", "--name-only", base, head, "--"],
        cwd=repo,
        capture_output=True,
        text=True,
        check=True,
    )
    return relevant(result.stdout.splitlines())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=ROOT)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", default="HEAD")
    args = parser.parse_args(argv)
    try:
        run = changed(args.repo, args.base, args.head)
    except (OSError, subprocess.CalledProcessError) as error:
        parser.exit(2, f"econ_sim_ci: cannot determine changed files: {error}\n")
    print("changed=" + str(run).lower())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
