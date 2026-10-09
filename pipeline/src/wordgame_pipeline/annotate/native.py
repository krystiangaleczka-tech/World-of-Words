"""Lazy optional Morfeusz backend; default tooling remains independent of native code."""

import importlib
from collections.abc import Callable
from types import ModuleType

from .core import Interpretation
from .sources import verify_engine


class NativeAnalyzer:
    def __init__(self, module: ModuleType) -> None:
        self.version: str = module.__version__
        self._engine = module.Morfeusz(
            dict_name="sgjp", generate=False, case_handling=module.IGNORE_CASE
        )
        self.dictionary_id: str = self._engine.dict_id()

    def analyse(self, word: str) -> list[Interpretation]:
        return self._engine.analyse(word)


def load_native(
    pin: dict[str, object], loader: Callable[[str], ModuleType] = importlib.import_module
) -> NativeAnalyzer:
    try:
        module = loader("morfeusz2")
    except ImportError as exc:
        raise ValueError(
            "Annotation requires the optional dependency; "
            "run uv run --all-packages --extra annotate wg"
        ) from exc
    if module.__version__ != pin["morphology"]["version"]:
        raise ValueError("Morfeusz engine version mismatch")
    try:
        analyzer = NativeAnalyzer(module)
    except RuntimeError as exc:
        raise ValueError(f"Cannot load pinned SGJP dictionary: {exc}") from exc
    verify_engine(analyzer, pin)
    return analyzer
