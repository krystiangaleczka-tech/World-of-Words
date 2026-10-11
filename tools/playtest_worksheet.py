"""Blank operator worksheet; structural defaults are not observed playtest results."""

from __future__ import annotations

import json

HASH_LENGTHS = {"source_sha": 40, "apk_sha256": 64, "content_sha256": 64}
BOOL_FIELDS = (
    "power_saving",
    "outsider",
    "clean_campaign",
    "answers_hidden",
    "instructions_given",
    "help_given",
    "wants_continue",
)
INT_FIELDS = ("start_slot", "final_slot", "active_seconds")
TEXT_FIELDS = ("date", "device", "android_version", "first_word")
OBSERVATION_FIELDS = (
    *HASH_LENGTHS,
    *BOOL_FIELDS,
    *INT_FIELDS,
    *TEXT_FIELDS,
    "refresh_hz",
    "stalls",
)


def build_worksheet() -> dict:
    """Return five independent anonymous records with all evidence unrecorded."""
    return {
        "schema_version": 1,
        "build": dict.fromkeys(HASH_LENGTHS),
        "sessions": [
            {
                "participant_id": f"P{index:02d}",
                **dict.fromkeys(OBSERVATION_FIELDS),
                "notes": "",
            }
            for index in range(1, 6)
        ],
    }


def render_worksheet() -> str:
    """Render strict, stable JSON without touching disk or filling observations."""
    return (
        json.dumps(build_worksheet(), ensure_ascii=False, allow_nan=False, sort_keys=True, indent=2)
        + "\n"
    )
