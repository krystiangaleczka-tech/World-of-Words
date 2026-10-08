"""Pinned SJP input and deterministic Polish normalization; no tier decisions."""

from pathlib import Path

from ..config import LanguageConfig
from ..stages import StageHandler
from .normalize import WordEntry, normalize_words
from .source import download_archive, load_pin, read_words

__all__ = ["WordEntry", "handlers_for", "normalize_words"]


def handlers_for(root: Path) -> dict[str, StageHandler]:
    def ingest(config: LanguageConfig, _previous: object) -> object:
        if config.lang != "pl":
            raise ValueError("SJP ingest supports PL only")
        pin = load_pin(root)
        archive = download_archive(root, pin)
        return {"source": pin.to_dict(), "words": read_words(archive.read_bytes(), pin)}

    def normalize(config: LanguageConfig, previous: object) -> object:
        if not isinstance(previous, dict) or set(previous) != {"source", "words"}:
            raise ValueError("normalize requires an SJP ingest payload")
        pin = load_pin(root)
        words = previous["words"]
        if previous["source"] != pin.to_dict() or not isinstance(words, list):
            raise ValueError("Ingest source pin/payload mismatch")
        if len(words) != pin.entry_count or any(not isinstance(word, str) for word in words):
            raise ValueError("Ingest words/count mismatch")
        result = normalize_words((WordEntry(word) for word in words), config)
        return {"source": pin.to_dict(), **result}

    return {"ingest": ingest, "normalize": normalize}
