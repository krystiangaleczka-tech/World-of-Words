"""Exact nullable frequency joins; no corpus entry becomes a gameplay word."""

import csv
import gzip
import io
import math
from dataclasses import dataclass


@dataclass(frozen=True)
class Frequency:
    arf: float
    ipm: float

    def to_dict(self) -> dict[str, float]:
        return {"arf": self.arf, "ipm": self.ipm}


def parse_frequency(raw: bytes, kind: str) -> dict[str | tuple[str, str], Frequency]:
    if kind not in {"orth", "lemma"}:
        raise ValueError("Unsupported KWJP frequency kind")
    try:
        text = gzip.decompress(raw).decode("utf-8")
        rows = csv.reader(io.StringIO(text))
        header = next(rows)
        expected = ["", "freq", "ipm", "ARF", "DP", "DP_norm", "1-DP", "total_freq"]
        if kind == "lemma":
            expected.insert(0, "")
        if header != expected:
            raise ValueError("Unexpected KWJP CSV columns")
        result: dict[str | tuple[str, str], Frequency] = {}
        for row in rows:
            if len(row) != len(header) or not row[0] or (kind == "lemma" and not row[1]):
                raise ValueError("Malformed KWJP row")
            key: str | tuple[str, str] = row[0] if kind == "orth" else (row[0], row[1])
            values = [float(row[header.index(column)]) for column in ("ARF", "ipm")]
            if any(not math.isfinite(value) or value < 0 for value in values):
                raise ValueError("KWJP metrics must be finite and nonnegative")
            if key in result:
                raise ValueError("Duplicate KWJP frequency key")
            result[key] = Frequency(*values)
        return result
    except (OSError, UnicodeError, StopIteration, EOFError, csv.Error) as exc:
        raise ValueError(f"Invalid KWJP gzip/CSV: {exc}") from exc
