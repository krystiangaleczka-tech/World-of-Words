"""Descriptive onboarding authored-source evidence, never human approval."""

from collections.abc import Mapping
from dataclasses import dataclass

from ..sequence.curve import ONBOARDING_LAST


@dataclass(frozen=True)
class OnboardingEvidence:
    missing_slots: tuple[int, ...]
    non_handmade_slots: tuple[int, ...]
    unexpected_landmarks: tuple[int, ...]


def audit_onboarding_evidence(levels: list | tuple) -> OnboardingEvidence:
    """Inspect declared source and landmark flags for the first fifteen slots."""
    if not isinstance(levels, (list, tuple)):
        raise ValueError("Expected campaign levels")
    seen: dict[int, Mapping] = {}
    for level in levels:
        if not isinstance(level, Mapping):
            raise ValueError("Expected campaign level mapping")
        slot = level.get("slot")
        if (
            type(slot) is not int
            or slot < 1
            or slot in seen
            or level.get("id") != f"pl-c-{slot:06d}"
            or level.get("source") not in ("generated", "handmade")
            or type(level.get("landmark")) is not bool
        ):
            raise ValueError("Invalid or duplicate campaign proof")
        seen[slot] = level
    onboarding = set(range(1, ONBOARDING_LAST + 1))
    present = onboarding & seen.keys()
    return OnboardingEvidence(
        tuple(sorted(onboarding - present)),
        tuple(sorted(slot for slot in present if seen[slot]["source"] != "handmade")),
        tuple(sorted(slot for slot in present if seen[slot]["landmark"])),
    )
