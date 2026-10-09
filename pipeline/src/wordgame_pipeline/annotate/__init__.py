"""Pinned annotation stage; native engine is loaded only when this handler executes."""

from pathlib import Path

from ..config import LanguageConfig
from ..ingest.source import load_pin as load_sjp_pin
from ..stages import StageHandler
from .core import Analyzer, annotate_words
from .frequency import Frequency
from .native import load_native
from .sources import load_frequency, load_pin, verify_engine


def handlers_for(root: Path) -> dict[str, StageHandler]:
    def annotate(config: LanguageConfig, previous: object) -> object:
        pin = load_pin(root)
        analyzer = load_native(pin)
        forms = load_frequency(root, pin, "orth")
        lemmas = load_frequency(root, pin, "lemma")
        return make_handler(root, analyzer, pin, forms, lemmas)(config, previous)

    return {"annotate": annotate}


def make_handler(
    root: Path,
    analyzer: Analyzer,
    pin: dict[str, object],
    form_frequency: dict[str, Frequency],
    lemma_frequency: dict[tuple[str, str], Frequency],
) -> StageHandler:
    def annotate(config: LanguageConfig, previous: object) -> object:
        verify_engine(analyzer, pin)
        if not isinstance(previous, dict) or previous.get("source") != load_sjp_pin(root).to_dict():
            raise ValueError("Annotation requires the pinned SJP normalization payload")
        words = previous.get("words")
        if not isinstance(words, list) or any(not isinstance(word, str) for word in words):
            raise ValueError("Invalid normalized source words")
        return {
            "source": previous["source"],
            "annotation_sources": pin,
            **annotate_words(words, config, analyzer, form_frequency, lemma_frequency),
        }

    return annotate
