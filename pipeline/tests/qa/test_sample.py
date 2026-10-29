"""Required onboarding and marked slots remain in the human review sample."""

import pytest
from wordgame_pipeline.qa.sample import plan_review_slots
from wordgame_pipeline.sequence.curve import CurveConfig
from wordgame_pipeline.sequence.slots import Location, Region, Reservation, SlotPlan


def plan():
    curve = CurveConfig(1, 18, 0.5, 0, 5, 0, 0.25, 0.25, (16,))
    return SlotPlan(
        regions=(Region("r", curve),),
        locations=(Location("l", "r", 1, 18),),
        authored=tuple(Reservation(i, f"pl-c-{i:06d}") for i in range(1, 17)),
        released=(),
    )


def test_mandatory_review_and_explicit_flag():
    sample = plan_review_slots(plan(), (), regular_stride=99)
    assert sample == tuple(range(1, 18))
    assert plan_review_slots(plan(), (18,), regular_stride=99) == tuple(range(1, 19))
    assert plan_review_slots(plan(), (), regular_stride=1) == tuple(range(1, 19))
    assert plan_review_slots(plan(), (18, 1), regular_stride=99) == tuple(range(1, 19))


@pytest.mark.parametrize(
    "flags,stride",
    [
        ((), 0), ((), True), ((), 1.5), ((), "1"),
        ((0,), 1), ((19,), 1), ((1, 1), 1), ((True,), 1), ([1], 1),
    ],
)
def test_invalid_review_requirements_rejected(flags, stride):
    with pytest.raises(ValueError):
        plan_review_slots(plan(), flags, regular_stride=stride)


def test_missing_plan():
    with pytest.raises(ValueError):
        plan_review_slots(None, (), regular_stride=1)
