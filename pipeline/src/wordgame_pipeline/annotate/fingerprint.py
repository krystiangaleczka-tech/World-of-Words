"""Read-only manifest identity for the verified morphology and KWJP pins."""

import hashlib
from dataclasses import dataclass
from pathlib import Path

from ..config import canonical_bytes
from .sources import load_pin


@dataclass(frozen=True)
class AnnotationFingerprint:
    dictionary_id: str
    frequency_commit: str
    manifest_sha256: str


def fingerprint_annotation_sources(root: Path) -> AnnotationFingerprint:
    """Use canonical validated source pins, never download or mutate assets."""
    if not isinstance(root, Path):
        raise ValueError("Expected explicit source root Path")
    pin = load_pin(root)
    return AnnotationFingerprint(
        pin["morphology"]["dictionary_id"],
        pin["frequency"]["commit"],
        hashlib.sha256(canonical_bytes(pin)).hexdigest(),
    )
