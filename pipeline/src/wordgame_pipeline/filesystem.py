"""Descriptor-based reads for Linux/Docker release tooling; never follow links."""

import os
import stat
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path


@contextmanager
def directory_fd(path: Path) -> Iterator[int]:
    path = path.absolute()
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
    descriptor = os.open(path.anchor, flags)
    try:
        try:
            for component in path.parts[1:]:
                child = os.open(component, flags, dir_fd=descriptor)
                os.close(descriptor)
                descriptor = child
            yield descriptor
        except FileNotFoundError:
            raise
        except OSError as exc:
            raise ValueError("Release paths must use real directories and regular files") from exc
    finally:
        os.close(descriptor)


def read_regular(path: Path) -> bytes | None:
    try:
        with directory_fd(path.parent) as directory:
            descriptor = os.open(
                path.name,
                os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
                dir_fd=directory,
            )
            try:
                if not stat.S_ISREG(os.fstat(descriptor).st_mode):
                    raise ValueError("Release input must be a regular file")
                with os.fdopen(descriptor, "rb", closefd=False) as stream:
                    return stream.read()
            finally:
                os.close(descriptor)
    except FileNotFoundError:
        return None
