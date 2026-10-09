"""Candidate stage uses existing pin checks and atomic artifact runner."""

from pathlib import Path

from ..annotate.sources import load_pin as annotation_pin
from ..config import LanguageConfig
from ..ingest.source import load_pin as source_pin
from ..stages import StageHandler
from .core import WordIndex
from .handmade import load_handmade


def handlers_for(root: Path) -> dict[str, StageHandler]:
    def candidates(config: LanguageConfig, previous: object) -> object:
        if (
            not isinstance(previous, dict)
            or previous.get("source") != source_pin(root).to_dict()
            or previous.get("annotation_sources") != annotation_pin(root)
        ):
            raise ValueError("Candidates require pinned tier provenance")
        index = WordIndex(previous.get("records"), config)
        handmade, digest = load_handmade(root, index)
        return {
            **{
                key: previous[key]
                for key in (
                    "source",
                    "annotation_sources",
                    "tier_rules",
                    "tier_rules_sha256",
                    "overrides_sha256",
                )
            },
            "handmade_sha256": digest,
            "automatic": index.automatic(),
            "handmade": handmade,
        }

    return {"candidates": candidates}
