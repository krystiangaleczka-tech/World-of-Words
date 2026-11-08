"""P2 location-aware sequence output; no content publication or implicit calibration."""

from dataclasses import dataclass

from ..config import LanguageConfig
from ..dedupe import DuplicatePolicy
from .allocate import ScoredCandidate, allocate
from .slots import SlotPlan


@dataclass(frozen=True)
class CampaignSlot:
    slot: int
    region_id: str
    location_id: str
    candidate_id: str
    score: float
    curve_target: float | None
    curve_kind: str
    mode: str


def sequence_campaign(
    plan: SlotPlan,
    candidates: list[ScoredCandidate] | tuple[ScoredCandidate, ...],
    policy: DuplicatePolicy,
    language: LanguageConfig,
) -> tuple[CampaignSlot, ...]:
    """Expose the validated allocator's exact per-location plan without writes."""
    result = allocate(plan, candidates, policy, language)
    if len(result.assignments) != plan.total:
        raise ValueError("Allocator did not cover every planned campaign slot")
    return tuple(
        CampaignSlot(
            assignment.requirement.slot,
            assignment.requirement.region,
            assignment.requirement.location,
            assignment.candidate.id,
            assignment.candidate.difficulty,
            assignment.requirement.curve.target,
            assignment.requirement.curve.kind,
            assignment.mode,
        )
        for assignment in result.assignments
    )
