import copy
from itertools import combinations_with_replacement, islice
from pathlib import Path

import pytest
from wordgame_pipeline.config import load_config
from wordgame_pipeline.dedupe.core import CROSSWORD_SPACING
from wordgame_pipeline.scoring import load_scoring
from wordgame_pipeline.sequence.qa_progression import Progression, plan_progression

PIPELINE = Path(__file__).resolve().parents[2]
WORDS = ("KOT", "DOM", "SOK", "KURA", "ZEGAR", "OBRAZ", "PYTANIE", "GWIAZDA", "KURTYNA", "POMIDOR")


def _level(slot: int, word: str) -> dict:
    return {
        "slot": slot,
        "letters": sorted(word),
        "words": [{"w": word, "x": 0, "y": 0, "dir": "v"}],
        "grid": {"w": 1, "h": len(word)},
    }


def _plan(fixed: list[dict], candidates: list[dict]) -> Progression:
    config = load_config(PIPELINE, "pl")
    scoring = load_scoring(PIPELINE / "config/qa-campaign-scoring.json")
    frequencies = {p["w"]: 100.0 for level in candidates for p in level["words"]}
    return plan_progression(fixed, candidates, frequencies, config, scoring)


def test_progression_keeps_all_layouts_in_five_measured_bands_and_fixes_endpoints() -> None:
    fixed = [_level(1, "CZAS")]
    entries = [_level(slot, word) for slot, word in enumerate(reversed(WORDS), start=2)]
    prior = copy.deepcopy(entries)
    result = _plan(fixed, entries)

    assert _plan(fixed, entries[::-1]) == result
    assert entries == prior
    assert sorted(row.source_slot for row in result.assignments) == list(range(2, 12))
    assert [row.band for row in result.assignments] == [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
    assert [(band.first, band.last) for band in result.bands] == [
        (2, 3),
        (4, 5),
        (6, 7),
        (8, 9),
        (10, 11),
    ]
    for band in result.bands:
        estimates = [row.estimate for row in result.assignments if row.band == band.number]
        assert (min(estimates), max(estimates)) == (band.minimum, band.maximum)
    assert all(a.maximum <= b.minimum for a, b in zip(result.bands, result.bands[1:], strict=False))
    assert result.assignments[0].estimate == result.bands[0].minimum
    assert result.assignments[-1].estimate == result.bands[-1].maximum


def test_progression_rejects_a_band_with_an_unavailable_required_answer() -> None:
    entries = [_level(slot, word) for slot, word in enumerate(WORDS, start=2)]
    result = _plan([_level(1, "CZAS")], entries)
    first_source = result.assignments[0].source_slot
    repeated = WORDS[first_source - 2]

    with pytest.raises(ValueError, match="preserve spacing"):
        _plan([_level(1, repeated)], entries)


def test_crossword_sharing_a_final_answer_is_scheduled_before_its_deadline() -> None:
    count = 5 * (CROSSWORD_SPACING + 1)
    words = islice(combinations_with_replacement("ABCDEFGHIJKL", 4), count - 2)
    entries = [_level(slot, "".join(word)) for slot, word in enumerate(words, start=1)]
    entries.extend(
        [
            {
                "slot": count - 1,
                "letters": list("AAKLOPS"),
                "words": [
                    {"w": "SOK", "x": 0, "y": 0, "dir": "h"},
                    {"w": "KOSA", "x": 2, "y": 0, "dir": "v"},
                ],
                "grid": {"w": 3, "h": 4},
            },
            {
                "slot": count,
                "letters": list("AKOÓSTŁ"),
                "words": [
                    {"w": "SOK", "x": 0, "y": 0, "dir": "h"},
                    {"w": "SOKÓŁ", "x": 0, "y": 0, "dir": "v"},
                ],
                "grid": {"w": 3, "h": 5},
            },
        ]
    )

    result = _plan([], entries)

    assert len(result.assignments) == count
    assert result.assignments[-1].source_slot == count
    prior = next(i for i, row in enumerate(result.assignments, 1) if row.source_slot == count - 1)
    assert count - prior >= CROSSWORD_SPACING
