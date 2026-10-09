"""Pure evidence-based tiers; no source words are created here."""

import csv
import io
import math
import unicodedata
from datetime import date

from ..config import LanguageConfig, TierRules

TIERS = ("level_ok", "bonus_ok", "banned")


def valid_word(word: object, config: LanguageConfig) -> bool:
    return (
        isinstance(word, str)
        and config.min_length <= len(word) <= config.max_length
        and word == unicodedata.normalize("NFC", word)
        and all(letter in config.alphabet for letter in word)
    )


def parse_overrides(text: str, config: LanguageConfig) -> dict[str, dict[str, str]]:
    reader = csv.DictReader(io.StringIO(text), strict=True)
    if reader.fieldnames != ["word", "tier", "reason", "date", "by"]:
        raise ValueError("Overrides require word,tier,reason,date,by")
    history: dict[tuple[str, str], dict[str, str]] = {}
    try:
        for row in reader:
            if set(row) != set(reader.fieldnames) or any(
                not isinstance(v, str) or not v.strip() for v in row.values()
            ):
                raise ValueError("Incomplete override decision")
            if not valid_word(row["word"], config) or row["tier"] not in TIERS:
                raise ValueError("Invalid override word/tier")
            if date.fromisoformat(row["date"]).isoformat() != row["date"]:
                raise ValueError("Override date must be YYYY-MM-DD")
            key = (row["word"], row["date"])
            if key in history and history[key] != row:
                raise ValueError("Conflicting same-date override decisions")
            history[key] = row
    except csv.Error as exc:
        raise ValueError("Invalid overrides CSV") from exc
    latest: dict[str, dict[str, str]] = {}
    for (word, _day), row in sorted(history.items()):
        latest[word] = row
    return latest


def arf(metric: object) -> float | None:
    if metric is None:
        return None
    if not isinstance(metric, dict) or set(metric) != {"arf", "ipm"}:
        raise ValueError("Invalid frequency evidence")
    for value in metric.values():
        if type(value) not in (float, int) or not math.isfinite(value) or value < 0:
            raise ValueError("Frequency evidence must be finite and nonnegative")
    return metric["arf"]


def analyses_for(record: dict, config: LanguageConfig) -> list[dict]:
    analyses = record.get("analyses")
    if not isinstance(analyses, list):
        raise ValueError("Invalid analyses")
    for analysis in analyses:
        required = {
            "lemma",
            "lemma_raw",
            "pos",
            "tag",
            "names",
            "labels",
            "is_inflected",
            "frequency",
        }
        if not isinstance(analysis, dict) or not required <= set(analysis):
            raise ValueError("Invalid analysis")
        if (
            not isinstance(analysis.get("lemma"), str)
            or not analysis["lemma"]
            or any(c not in config.alphabet for c in analysis["lemma"])
        ):
            raise ValueError("Invalid lemma")
        for key in ("lemma_raw", "pos", "tag"):
            if not isinstance(analysis.get(key), str) or not analysis[key]:
                raise ValueError("Invalid morphology metadata")
        if (
            unicodedata.normalize("NFC", analysis["lemma_raw"].split(":", 1)[0]).upper()
            != analysis["lemma"]
        ):
            raise ValueError("Inconsistent raw/canonical lemma")
        if analysis["tag"].split(":", 1)[0] != analysis["pos"]:
            raise ValueError("Inconsistent POS/tag")
        if type(analysis.get("is_inflected")) is not bool or analysis["is_inflected"] != (
            analysis["lemma"] != record["word"]
        ):
            raise ValueError("Inconsistent inflection evidence")
        for key in ("names", "labels"):
            values = analysis.get(key)
            if not isinstance(values, list) or any(not isinstance(v, str) or not v for v in values):
                raise ValueError("Invalid names/labels")
        arf(analysis.get("frequency"))
    if type(record.get("has_lemma_evidence")) is not bool or record["has_lemma_evidence"] != bool(
        analyses
    ):
        raise ValueError("Inconsistent lemma evidence")
    return [entry for entry in analyses if entry["pos"] != "ign"]


def rule_tier(record: dict, analyses: list[dict], rules: TierRules) -> tuple[str, str]:
    form_arf = arf(record.get("frequency"))
    if any(set(entry["labels"]) & set(rules.banned_labels) for entry in analyses):
        return "banned", "banned_label"
    ordinary = [
        entry
        for entry in analyses
        if entry["pos"] != "brev" and set(entry["names"]) <= {"nazwa_pospolita", "nazwa pospolita"}
    ]
    if analyses and not ordinary:
        return "banned", "proper_name_or_abbreviation"
    for entry in ordinary:
        if set(entry["labels"]) & set(rules.excluded_level_labels):
            continue
        if not entry["is_inflected"]:
            own_arf = arf(entry.get("frequency"))
            if any(
                value is not None and value >= rules.base_min_arf for value in (form_arf, own_arf)
            ):
                return "level_ok", "common_base"
        elif form_arf is not None and form_arf >= rules.inflected_min_arf:
            return "level_ok", "common_inflection"
    return "bonus_ok", "missing_lemma" if not analyses else "rare_or_missing_frequency"


def assign_tiers(
    records: object, config: LanguageConfig, overrides: dict[str, dict[str, str]]
) -> dict:
    if not isinstance(records, list) or any(
        not isinstance(row, dict)
        or not {"word", "frequency", "analyses", "has_lemma_evidence"} <= set(row)
        or not valid_word(row.get("word"), config)
        for row in records
    ):
        raise ValueError("Tiers require normalized source records")
    words = [row["word"] for row in records]
    if words != sorted(set(words)):
        raise ValueError("Tier records must be sorted and unique")
    result = []
    counts = dict.fromkeys(TIERS, 0)
    for record in records:
        analyses = analyses_for(record, config)
        tier, reason = rule_tier(record, analyses, config.tier_rules or TierRules())
        decision = overrides.get(record["word"])
        if decision is not None:
            if decision["tier"] == "level_ok" and not analyses:
                raise ValueError("level_ok override requires usable lemma evidence")
            tier, reason = decision["tier"], "override"
        result.append({**record, "tier": tier, "tier_reason": reason, "override": decision})
        counts[tier] += 1
    return {
        "records": result,
        "tier_counts": counts,
        "unmatched_overrides": [overrides[word] for word in sorted(set(overrides) - set(words))],
    }
