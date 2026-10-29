"""Inventory checksum-verified SJP archive words without extracting or writing."""

from collections import Counter
from dataclasses import dataclass

from .source import SourcePin, read_words


@dataclass(frozen=True)
class SourceInventory:
    source_sha256: str
    rows: int
    unique_words: int
    duplicate_rows: int
    repeated_words: tuple[str, ...]
    minimum_length: int
    maximum_length: int


def inspect_source_inventory(archive: bytes, pin: SourcePin) -> SourceInventory:
    """Read only the pinned archive; report duplicate evidence to QA."""
    if not isinstance(archive, bytes) or not isinstance(pin, SourcePin):
        raise ValueError("Expected pinned source archive bytes")
    words = read_words(archive, pin)
    counts = Counter(words)
    return SourceInventory(
        pin.sha256,
        len(words),
        len(counts),
        len(words) - len(counts),
        tuple(sorted(word for word, count in counts.items() if count > 1)),
        min(map(len, words)),
        max(map(len, words)),
    )
