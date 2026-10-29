"""Source declarations are not human signoff."""

from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.qa.onboarding import OnboardingEvidence, audit_onboarding_evidence


def level(slot, *, source="handmade", landmark=False):
    return {
        "id": f"pl-c-{slot:06d}",
        "slot": slot,
        "source": source,
        "landmark": landmark,
    }


def test_missing_source_and_landmark_are_distinct():
    rows = [level(1), level(3, source="generated", landmark=True), level(16)]
    result = audit_onboarding_evidence(rows)
    assert result.missing_slots == tuple(slot for slot in range(2, 16) if slot != 3)
    assert result.non_handmade_slots == (3,)
    assert result.unexpected_landmarks == (3,)
    assert audit_onboarding_evidence(rows[::-1]) == result
    with pytest.raises(FrozenInstanceError):
        result.missing_slots = ()


def test_full_declared_onboarding_is_empty_not_approval():
    assert audit_onboarding_evidence([level(i) for i in range(1, 16)]) == (
        OnboardingEvidence((), (), ())
    )


@pytest.mark.parametrize(
    "levels",
    [
        None,
        [None],
        [level(1), level(1)],
        [level(1) | {"id": "bad"}],
        [level(1) | {"slot": True}],
        [level(1) | {"source": "unknown"}],
        [level(1) | {"landmark": None}],
    ],
)
def test_invalid_claims_rejected(levels):
    with pytest.raises(ValueError):
        audit_onboarding_evidence(levels)
