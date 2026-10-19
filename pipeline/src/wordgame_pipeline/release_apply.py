"""Explicit reviewed lock update; the operator owns actual release approval."""

import fcntl
import os
import re
import secrets
from pathlib import Path

from .config import canonical_bytes
from .filesystem import directory_fd
from .release_plan import ReleasePlan, plan_release_lock


def apply_release_lock(
    root: Path,
    content_root: Path,
    released_through: int,
    *,
    expected_sha256: str,
    approved: bool = False,
) -> tuple[ReleasePlan, bool]:
    if approved is not True:
        raise ValueError("Release update requires explicit approval")
    if not isinstance(expected_sha256, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
        raise ValueError("Expected reviewed release proposal SHA256")
    root, content_root = root.absolute(), content_root.absolute()

    def checked() -> ReleasePlan:
        plan = plan_release_lock(root, content_root, released_through)
        if plan.sha256 != expected_sha256:
            raise ValueError("Release proposal changed; review a fresh proposal")
        return plan

    checked()
    with directory_fd(root) as parent:
        try:
            os.mkdir("locks", dir_fd=parent)
        except FileExistsError:
            pass
    with directory_fd(root / "locks") as directory:
        try:
            fcntl.flock(directory, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise ValueError("Release update already in progress") from exc
        temporary = None
        try:
            plan = checked()
            if plan.previous == plan.proposed:
                return plan, False
            name = f".pl.lock-{secrets.token_hex(16)}.tmp"
            descriptor = os.open(
                name,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
                0o644,
                dir_fd=directory,
            )
            temporary = name
            try:
                with os.fdopen(descriptor, "wb", closefd=False) as stream:
                    stream.write(canonical_bytes(plan.proposed.to_dict()))
                    stream.flush()
                    os.fsync(descriptor)
            finally:
                os.close(descriptor)
            checked()
            os.replace(temporary, "pl.lock.json", src_dir_fd=directory, dst_dir_fd=directory)
            temporary = None
            return plan, True
        finally:
            try:
                if temporary is not None:
                    try:
                        os.unlink(temporary, dir_fd=directory)
                    except FileNotFoundError:
                        pass
            finally:
                fcntl.flock(directory, fcntl.LOCK_UN)
