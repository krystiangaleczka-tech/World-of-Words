"""Read source-backed editorial familiarity judgments without inferring approval."""

import csv
import unicodedata
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class WordReview:
    word: str
    band: int | None
    status: str
    reviewer: str
    rationale: str


def load_catalog(path: Path, tiers: Mapping[str, str]) -> dict[str, WordReview]:
    """Validate an ordered UTF-8 CSV; native eligibility remains authoritative."""
    result: dict[str, WordReview] = {}
    row_number = 1
    try:
        with path.open(encoding="utf-8", newline="") as stream:
            reader = csv.reader(stream, strict=True)
            if next(reader, None) != ["word", "band", "status", "reviewer", "rationale"]:
                raise ValueError("catalog row 1: expected word,band,status,reviewer,rationale")
            previous = ""
            for row_number, row in enumerate(reader, 2):
                if len(row) != 5:
                    raise ValueError(f"catalog row {row_number}: expected five cells")
                word, band_text, status, reviewer, rationale = row
                if (
                    not word.isalpha()
                    or not word.isupper()
                    or unicodedata.normalize("NFC", word) != word
                    or word <= previous
                ):
                    raise ValueError(
                        f"catalog row {row_number}: invalid or unordered word {word!r}"
                    )
                if tiers.get(word) not in ("level_ok", "bonus_ok"):
                    raise ValueError(f"catalog row {row_number}: ineligible native word {word!r}")
                if band_text not in ("", "1", "2", "3", "4", "5"):
                    raise ValueError(f"catalog row {row_number}: invalid band {band_text!r}")
                if status not in ("proposed", "reviewed"):
                    raise ValueError(f"catalog row {row_number}: invalid status {status!r}")
                if status == "reviewed" and not band_text:
                    raise ValueError(f"catalog row {row_number}: reviewed word needs a band")
                if any(not value or value != value.strip() for value in (reviewer, rationale)):
                    raise ValueError(
                        f"catalog row {row_number}: reviewer/rationale must be trimmed"
                    )
                result[word] = WordReview(
                    word, int(band_text) if band_text else None, status, reviewer, rationale
                )
                previous = word
    except (csv.Error, UnicodeDecodeError) as error:
        raise ValueError(f"catalog row {row_number}: malformed CSV or UTF-8: {error}") from error
    if not result:
        raise ValueError("catalog row 2: no review data")
    return result
