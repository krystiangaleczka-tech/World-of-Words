"""Compare two explicit classification passes without inventing model decisions."""

from collections.abc import Mapping
from dataclasses import dataclass

from ..config import LanguageConfig
from ..tiers.core import TIERS, valid_word


@dataclass(frozen=True)
class ClassificationDisagreement:
    word: str
    first: str
    second: str
    crosses_ban_boundary: bool


def compare_classification_passes(
    first: Mapping[str, str], second: Mapping[str, str], config: LanguageConfig
) -> tuple[ClassificationDisagreement, ...]:
    """Flag mismatched tiers; human review remains mandatory, not inferred."""
    if (
        not isinstance(config, LanguageConfig)
        or not isinstance(first, Mapping)
        or not isinstance(second, Mapping)
        or set(first) != set(second)
    ):
        raise ValueError("Expected matching explicit classification records")
    result = []
    for word in sorted(first):
        a, b = first[word], second[word]
        if not valid_word(word, config) or a not in TIERS or b not in TIERS:
            raise ValueError("Invalid normalized word or tier class")
        if a != b:
            result.append(
                ClassificationDisagreement(
                    word, a, b, (a == "banned") != (b == "banned")
                )
            )
    return tuple(result)
