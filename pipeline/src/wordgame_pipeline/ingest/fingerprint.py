"""Read-only canonical digest of a validated pinned SJP archive manifest."""

import hashlib
from dataclasses import dataclass
from pathlib import Path

from ..config import canonical_bytes
from .source import load_pin


@dataclass(frozen=True)
class SourceFingerprint:
    source_id: str
    version: str
    license: str
    archive_sha256: str
    manifest_sha256: str


def fingerprint_source(root: Path) -> SourceFingerprint:
    """Read and hash the approved source pin; never download source bytes."""
    if not isinstance(root, Path):
        raise ValueError("Expected explicit source root Path")
    pin = load_pin(root)
    return SourceFingerprint(
        pin.id,
        pin.version,
        pin.license,
        pin.sha256,
        hashlib.sha256(canonical_bytes(pin.to_dict())).hexdigest(),
    )
