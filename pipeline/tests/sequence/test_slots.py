"""Protected slot ownership; no actual content or release is authored here."""

from dataclasses import FrozenInstanceError, replace

import pytest
from wordgame_pipeline.sequence import CurveConfig
from wordgame_pipeline.sequence.slots import (
    Location,
    Region,
    Reservation,
    SlotPlan,
    SlotRequirement,
)


def curve(first=1, last=20, landmarks=(18,)):
    return CurveConfig(first, last, 0.1, 0.01, 5, 0.2, 0.3, 0.1, landmarks)


def plan():
    return SlotPlan(
        (Region("r1", curve()), Region("r2", curve(21, 30, ()))),
        (Location("l1", "r1", 1, 10), Location("l2", "r1", 11, 20), Location("l3", "r2", 21, 30)),
        tuple(Reservation(s, f"c{s}") for s in [*range(1, 16), 18]),
        tuple(Reservation(s, f"c{s}") for s in range(1, 4)),
    )


def test_exact_partitions_protected_flags_and_target_ownership():
    value = plan()
    assert value.total == 30
    first = value.requirement(1)
    assert (first.region, first.location, first.fixed_id) == ("r1", "l1", "c1")
    assert first.authored and first.released and first.curve.kind == "onboarding"
    assert value.requirement(15).authored and not value.requirement(15).released
    assert value.requirement(16).fixed_id is None
    assert (
        value.requirement(18).curve.kind == "landmark" and value.requirement(18).fixed_id == "c18"
    )
    assert value.requirement(19).curve.kind == "breather"
    assert (value.requirement(21).region, value.requirement(21).location) == ("r2", "l3")
    with pytest.raises(FrozenInstanceError):
        first.fixed_id = "other"
    with pytest.raises(FrozenInstanceError):
        value.authored = ()


def test_huge_plan_query_does_not_allocate_all_slots():
    value = SlotPlan(
        (Region("r", curve(last=2**53 - 1, landmarks=())),),
        (Location("l", "r", 1, 2**53 - 1),),
        tuple(Reservation(s, f"c{s}") for s in range(1, 16)),
        (),
    )
    assert value.requirement(2**53 - 1).slot == value.total


@pytest.mark.parametrize(
    "kind",
    [
        "region_gap",
        "region_overlap",
        "region_id",
        "location_gap",
        "location_overlap",
        "location_id",
        "wrong_region",
        "cross_region",
        "incomplete",
        "onboarding",
        "landmark",
        "conflict",
        "prefix",
        "cross_identity",
        "order",
        "duplicate",
        "outside",
        "mutable",
    ],
)
def test_invalid_plan_shapes_and_reservations_fail(kind):
    value = plan()
    regions, locations, authored, released = (
        value.regions,
        value.locations,
        value.authored,
        value.released,
    )
    if kind == "region_gap":
        regions = (regions[0], Region("r2", curve(22, 30, ())))
    elif kind == "region_overlap":
        regions = (regions[0], Region("r2", curve(20, 30, ())))
    elif kind == "region_id":
        regions = (regions[0], Region("r1", curve(21, 30, ())))
    elif kind == "location_gap":
        locations = (replace(locations[0], last=9), *locations[1:])
    elif kind == "location_overlap":
        locations = (replace(locations[0], last=11), *locations[1:])
    elif kind == "location_id":
        locations = (*locations[:2], replace(locations[2], id="l1"))
    elif kind == "wrong_region":
        locations = (replace(locations[0], region="missing"), *locations[1:])
    elif kind == "cross_region":
        locations = (Location("l", "r1", 1, 30),)
    elif kind == "incomplete":
        locations = locations[:-1]
    elif kind == "onboarding":
        authored = authored[1:]
    elif kind == "landmark":
        authored = authored[:-1]
    elif kind == "conflict":
        released = (Reservation(1, "other"),)
    elif kind == "prefix":
        released = (Reservation(2, "c2"),)
    elif kind == "cross_identity":
        released = (Reservation(1, "c18"),)
    elif kind == "order":
        authored = tuple(reversed(authored))
    elif kind == "duplicate":
        authored = (*authored, authored[-1])
    elif kind == "outside":
        authored = (*authored, Reservation(31, "extra"))
    elif kind == "mutable":
        regions = list(regions)
    with pytest.raises(ValueError):
        SlotPlan(regions, locations, authored, released)


@pytest.mark.parametrize("identity", ["", " x ", "a\x7fb", "a\u0085b", "a\u200bb", None])
def test_identity_validation(identity):
    with pytest.raises(ValueError):
        Region(identity, curve())
    with pytest.raises(ValueError):
        Location(identity, "r", 1, 2)
    with pytest.raises(ValueError):
        Reservation(1, identity)


def test_constructor_and_query_type_checks():
    for slot in (True, 0, 1.0, 2**53):
        with pytest.raises(ValueError):
            Reservation(slot, "c")
        with pytest.raises(ValueError):
            plan().requirement(slot)
    with pytest.raises(ValueError):
        plan().requirement(31)
    with pytest.raises(ValueError):
        Region("r", None)
    with pytest.raises(ValueError):
        Location("l", "r", 2, 1)
    with pytest.raises(ValueError):
        replace(plan(), locations=[])
    with pytest.raises(ValueError):
        replace(plan(), authored=[])
    with pytest.raises(ValueError):
        SlotRequirement(1, "r", "l", plan().requirement(2).curve, "c", True, False)
    with pytest.raises(ValueError):
        replace(plan().requirement(16), fixed_id="x")


def test_unreleased_authored_regular_and_released_onboarding_both_need_proof():
    value = plan()
    extra = (*value.authored, Reservation(25, "c25"))
    assert replace(value, authored=extra).requirement(25).fixed_id == "c25"
    with pytest.raises(ValueError):
        replace(value, authored=value.authored[1:])
    with pytest.raises(ValueError):
        replace(value, released=(Reservation(1, "c1"), Reservation(2, "c1")))


def test_released_regular_slot_cannot_reuse_future_authored_identity():
    value = plan()
    released = tuple(Reservation(s, f"c{s}") for s in range(1, 16)) + (Reservation(16, "c18"),)
    with pytest.raises(ValueError, match="multiple slots"):
        replace(value, released=released)
