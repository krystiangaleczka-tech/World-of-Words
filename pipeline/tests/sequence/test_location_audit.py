"""Location composition fixtures have no production approvals."""

from dataclasses import FrozenInstanceError

import pytest
from wordgame_pipeline.sequence.curve import CurveConfig
from wordgame_pipeline.sequence.location_audit import LocationCurveAudit, audit_location_curve
from wordgame_pipeline.sequence.slots import Location, Region, Reservation, SlotPlan


def plan():
    curve = CurveConfig(1, 18, 0.5, 0, 5, 0, 0.25, 0.25, (16,))
    return SlotPlan(
        regions=(Region("r", curve),),
        locations=(Location("start", "r", 1, 15), Location("end", "r", 16, 18)),
        authored=tuple(Reservation(i, f"pl-c-{i:06d}") for i in range(1, 17)),
        released=tuple(Reservation(i, f"pl-c-{i:06d}") for i in range(1, 3)),
    )


def test_onboarding_and_landmark_regions_and_reservations():
    rows = audit_location_curve(plan())
    assert rows == (
        LocationCurveAudit("start", "r", 15, 15, 0, 0, 0, 15, 2),
        LocationCurveAudit("end", "r", 3, 0, 1, 1, 1, 1, 0),
    )
    assert rows == audit_location_curve(plan())
    with pytest.raises(FrozenInstanceError):
        rows[0].slots = 99


def test_bad_plan():
    with pytest.raises(ValueError):
        audit_location_curve(None)
