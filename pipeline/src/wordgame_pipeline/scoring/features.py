"""Raw, deterministic difficulty measurements; no calibrated score or I/O."""

import math
from collections import Counter
from collections.abc import Mapping

from ..config import LanguageConfig
from ..grid.geometry import cells_for, validate_geometry
from ..tiers.core import valid_word

FEATURE_NAMES = (
    "letter_count",
    "distinct_letters",
    "word_count",
    "mean_word_length",
    "max_word_length",
    "mean_log_arf",
    "frequency_coverage",
    "anagram_pairs",
    "grid_area",
    "grid_fill",
    "crossings",
    "crossing_fraction",
)


def extract_features(
    level: Mapping, frequencies: Mapping[str, float | None], config: LanguageConfig
) -> dict[str, float]:
    if not isinstance(level, Mapping) or not isinstance(frequencies, Mapping):
        raise ValueError("Expected level and exact-form frequency mappings")
    letters = level.get("letters")
    placements = level.get("words")
    if (
        not isinstance(letters, list)
        or not config.min_length <= len(letters) <= config.max_length
        or any(not isinstance(c, str) or len(c) != 1 or c not in config.alphabet for c in letters)
        or not isinstance(placements, list)
        or not placements
    ):
        raise ValueError("Invalid scoring wheel or placements")
    wheel = Counter(letters)
    layout = []
    for placement in placements:
        if not isinstance(placement, dict) or set(placement) != {"w", "x", "y", "dir"}:
            raise ValueError("Expected w/x/y/dir placement")
        word = placement["w"]
        if not valid_word(word, config) or not Counter(word) <= wheel:
            raise ValueError("Scoring word must be normalized and formable")
        layout.append((word, placement["x"], placement["y"], placement["dir"]))
    selected = tuple(sorted(p[0] for p in layout))
    geometry = validate_geometry(tuple(layout), selected)
    declared = level.get("grid")
    if (
        not isinstance(declared, dict)
        or set(declared) != {"w", "h"}
        or any(type(v) is not int for v in declared.values())
        or declared != geometry
    ):
        raise ValueError("Declared scoring grid does not match geometry")
    if set(frequencies) != set(selected):
        raise ValueError("Frequency keys must match selected words exactly")
    known = []
    for word in selected:
        value = frequencies[word]
        if value is None:
            continue
        if type(value) not in (int, float):
            raise ValueError("ARF must be finite nonnegative numeric evidence or None")
        try:
            value = float(value)
        except (OverflowError, ValueError) as exc:
            raise ValueError("Unrepresentable ARF") from exc
        if not math.isfinite(value) or value < 0:
            raise ValueError("ARF must be finite and nonnegative")
        known.append(math.log1p(value))
    groups = Counter("".join(sorted(word)) for word in selected)
    lengths = [len(word) for word in selected]
    occupied = len(cells_for(tuple(layout)))
    area = geometry["w"] * geometry["h"]
    crossings = sum(lengths) - occupied
    values = (
        len(letters),
        len(set(letters)),
        len(selected),
        sum(lengths) / len(selected),
        max(lengths),
        math.fsum(known) / len(known) if known else 0,
        len(known) / len(selected),
        sum(n * (n - 1) // 2 for n in groups.values()),
        area,
        occupied / area,
        crossings,
        crossings / occupied,
    )
    return dict(zip(FEATURE_NAMES, map(float, values), strict=True))
