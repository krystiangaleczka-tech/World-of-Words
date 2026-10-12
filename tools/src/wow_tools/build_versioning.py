"""Collect task metadata required for every Android export."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

TASK_ID_PATTERN = re.compile(r"(?<![A-Za-z0-9])T-\d{4}(?!\d)", re.IGNORECASE)
BRANCH_TASK_PATTERN = re.compile(r"(?:^|/)t/(\d{4})(?:-|$)", re.IGNORECASE)


def _task_id_from_ci(root: Path) -> str:
    reference = " ".join(
        (
            os.environ.get("GITHUB_HEAD_REF", ""),
            os.environ.get("GITHUB_REF_NAME", ""),
        )
    )
    branch_match = BRANCH_TASK_PATTERN.search(reference)
    match = TASK_ID_PATTERN.search(reference)
    task_id = f"T-{branch_match.group(1)}" if branch_match is not None else ""
    if not task_id and match is None:
        result = subprocess.run(
            ["git", "show", "-s", "--format=%s", "HEAD"],
            cwd=root,
            capture_output=True,
            check=False,
            text=True,
        )
        if result.returncode != 0:
            raise ValueError("Could not read the CI commit subject for build metadata")
        match = TASK_ID_PATTERN.search(result.stdout)
    if not task_id and match is not None:
        task_id = match.group(0).upper()
    if not task_id:
        raise ValueError("Could not find a T-NNNN task ID in the CI ref or commit subject")
    return task_id


def _task_id_from_local_checkout(root: Path) -> str:
    branch_result = subprocess.run(
        ["git", "branch", "--show-current"],
        cwd=root,
        capture_output=True,
        check=False,
        text=True,
    )
    if branch_result.returncode != 0:
        raise ValueError("Could not identify the current task branch")
    branch_match = BRANCH_TASK_PATTERN.search(branch_result.stdout.strip())
    if branch_match is not None:
        return f"T-{branch_match.group(1)}"

    result = subprocess.run(
        ["git", "show", "-s", "--format=%s", "HEAD"],
        cwd=root,
        capture_output=True,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        raise ValueError("Could not read the current commit for build metadata")
    match = TASK_ID_PATTERN.search(result.stdout)
    if match is None:
        raise ValueError("Could not find the current task ID in the branch or commit subject")
    return match.group(0).upper()


def _task_title(root: Path, task_id: str) -> str:
    candidates = sorted((root / "tasks").glob(f"{task_id}-*.md"))
    if len(candidates) != 1:
        raise ValueError(f"Expected one task file for {task_id}, found {len(candidates)}")
    content = candidates[0].read_text(encoding="utf-8")
    front_matter = content.split("---", 2)
    if len(front_matter) < 3:
        raise ValueError(f"Task file has no front matter: {candidates[0]}")
    match = re.search(r"^title:\s*(.*?)\s*$", front_matter[1], re.MULTILINE)
    if match is None:
        raise ValueError(f"Task file has no title: {candidates[0]}")
    title = match.group(1).strip().strip("\"'")
    if not title:
        raise ValueError(f"Task title is empty: {candidates[0]}")
    return title


def _local_metadata() -> tuple[str, str, str]:
    if not sys.stdin.isatty():
        raise ValueError(
            "Build metadata is required. Run the export in a terminal or use GitHub Actions."
        )
    task_id = input("Latest task number (T-NNNN): ").strip().upper()
    task_name = input("Task name: ").strip()
    built_at = input("Build date and time (ISO 8601 with timezone): ").strip()
    return task_id, task_name, built_at


def collect_build_versioning(root: Path, build_kind: str) -> dict[str, str]:
    """Prompt locally or resolve CI task metadata, then write the artifact record."""
    if os.environ.get("GITHUB_ACTIONS", "").lower() == "true":
        task_id = _task_id_from_ci(root)
        task_name = _task_title(root, task_id)
        built_at = datetime.now().astimezone().isoformat(timespec="seconds")
    else:
        task_id, task_name, built_at = _local_metadata()

    if TASK_ID_PATTERN.fullmatch(task_id) is None:
        raise ValueError("Task number must use the T-NNNN format")
    if os.environ.get("GITHUB_ACTIONS", "").lower() != "true":
        current_task_id = _task_id_from_local_checkout(root)
        if task_id != current_task_id:
            raise ValueError(f"Enter the current task number {current_task_id}")
        expected_task_name = _task_title(root, current_task_id)
        if task_name != expected_task_name:
            raise ValueError(f"Task name must match the current title: {expected_task_name}")
    if not task_name or "\n" in task_name or "\r" in task_name:
        raise ValueError("Task name must be a non-empty single line")
    try:
        parsed_datetime = datetime.fromisoformat(built_at)
    except ValueError as exc:
        raise ValueError("Build date/time must be valid ISO 8601") from exc
    if parsed_datetime.tzinfo is None or parsed_datetime.utcoffset() is None:
        raise ValueError("Build date/time must include a timezone offset")

    record = {
        "task_id": task_id,
        "task_name": task_name,
        "built_at": parsed_datetime.isoformat(timespec="seconds"),
        "build_kind": build_kind,
    }
    output = root / "builds" / "build-versioning.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, str]] = []
    if output.exists():
        try:
            existing: object = json.loads(output.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise ValueError("Build versioning file contains invalid JSON") from exc
        if (
            not isinstance(existing, dict)
            or existing.get("schema_version") != 1
            or not isinstance(existing.get("builds"), list)
        ):
            raise ValueError("Build versioning file has an unsupported structure")
        for entry in existing["builds"]:
            if not isinstance(entry, dict) or not all(
                isinstance(key, str) and isinstance(value, str) for key, value in entry.items()
            ):
                raise ValueError("Build versioning file contains an invalid build record")
            records.append(entry)
    records.append(record)
    output.write_text(
        json.dumps({"schema_version": 1, "builds": records}, indent=2) + "\n",
        encoding="utf-8",
    )
    return record
