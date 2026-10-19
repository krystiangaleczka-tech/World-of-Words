"""Immutable slot ownership and reservations, without candidate allocation."""

from dataclasses import dataclass
from unicodedata import category

from .curve import MAX_SLOT, ONBOARDING_LAST, CurveConfig, CurveTarget, target_for_slot


def _identity(value: object) -> None:
    if (
        not isinstance(value, str)
        or not value
        or value != value.strip()
        or any(category(c) in {"Cc", "Cf"} for c in value)
    ):
        raise ValueError("Expected nonempty control-free identity")


def _slot(value: object) -> None:
    if type(value) is not int or not 1 <= value <= MAX_SLOT:
        raise ValueError("Expected manifest-safe positive slot")


@dataclass(frozen=True)
class Region:
    id: str
    curve: CurveConfig

    def __post_init__(self) -> None:
        _identity(self.id)
        if not isinstance(self.curve, CurveConfig):
            raise ValueError("Region requires explicit curve configuration")


@dataclass(frozen=True)
class Location:
    id: str
    region: str
    first: int
    last: int

    def __post_init__(self) -> None:
        _identity(self.id)
        _identity(self.region)
        _slot(self.first)
        _slot(self.last)
        if self.last < self.first:
            raise ValueError("Invalid location bounds")


@dataclass(frozen=True)
class Reservation:
    slot: int
    candidate_id: str

    def __post_init__(self) -> None:
        _slot(self.slot)
        _identity(self.candidate_id)


@dataclass(frozen=True)
class SlotRequirement:
    slot: int
    region: str
    location: str
    curve: CurveTarget
    fixed_id: str | None
    authored: bool
    released: bool

    def __post_init__(self) -> None:
        _slot(self.slot)
        _identity(self.region)
        _identity(self.location)
        if self.fixed_id is not None:
            _identity(self.fixed_id)
        if (
            not isinstance(self.curve, CurveTarget)
            or self.curve.slot != self.slot
            or type(self.authored) is not bool
            or type(self.released) is not bool
            or (self.fixed_id is not None) != (self.authored or self.released)
        ):
            raise ValueError("Invalid slot requirement proof")


@dataclass(frozen=True)
class SlotPlan:
    regions: tuple[Region, ...]
    locations: tuple[Location, ...]
    authored: tuple[Reservation, ...]
    released: tuple[Reservation, ...]

    def __post_init__(self) -> None:
        expected = 1
        region_map = {}
        if not isinstance(self.regions, tuple) or not self.regions:
            raise ValueError("Expected nonempty region tuple")
        for region in self.regions:
            if (
                not isinstance(region, Region)
                or region.id in region_map
                or region.curve.first != expected
            ):
                raise ValueError("Region partition gaps/overlaps/duplicate IDs")
            region_map[region.id] = region
            expected = region.curve.last + 1
        if not isinstance(self.locations, tuple) or not self.locations:
            raise ValueError("Expected nonempty location tuple")
        expected, ids = 1, set()
        for location in self.locations:
            if (
                not isinstance(location, Location)
                or location.id in ids
                or location.first != expected
            ):
                raise ValueError("Location partition gaps/overlaps/duplicate IDs")
            region = region_map.get(location.region)
            if (
                region is None
                or not region.curve.first <= location.first <= location.last <= region.curve.last
            ):
                raise ValueError("Location outside its referenced region")
            expected = location.last + 1
            ids.add(location.id)
        if expected != self.total + 1:
            raise ValueError("Locations must cover every planned slot")
        authored = self._reservations(self.authored)
        released = self._reservations(self.released)
        if any(r.slot != i for i, r in enumerate(self.released, 1)):
            raise ValueError("Released reservations must be a contiguous prefix")
        merged, owners = dict(authored), {}
        for slot, identity in released.items():
            if slot in merged and merged[slot] != identity:
                raise ValueError("Authored reservation conflicts with released identity")
            merged[slot] = identity
        for slot, identity in merged.items():
            if identity in owners:
                raise ValueError("Reserved candidate cannot occupy multiple slots")
            owners[identity] = slot
        required = set(range(1, min(ONBOARDING_LAST, self.total) + 1))
        for region in self.regions:
            required.update(region.curve.landmarks)
        if not required <= authored.keys():
            raise ValueError("Onboarding and landmarks require explicit authored reservations")

    @property
    def total(self) -> int:
        return self.regions[-1].curve.last

    def _reservations(self, values: tuple[Reservation, ...]) -> dict[int, str]:
        if not isinstance(values, tuple) or any(not isinstance(r, Reservation) for r in values):
            raise ValueError("Expected immutable reservation tuple")
        slots = tuple(r.slot for r in values)
        if slots != tuple(sorted(set(slots))) or any(r.slot > self.total for r in values):
            raise ValueError("Reservations must be unique ordered in-range slots")
        if len({r.candidate_id for r in values}) != len(values):
            raise ValueError("Reserved identities must be unique")
        return {r.slot: r.candidate_id for r in values}

    def requirement(self, slot: int) -> SlotRequirement:
        _slot(slot)
        if slot > self.total:
            raise ValueError("Slot outside planned campaign")
        region = next(r for r in self.regions if r.curve.first <= slot <= r.curve.last)
        location = next(p for p in self.locations if p.first <= slot <= p.last)
        authored, released = self._reservations(self.authored), self._reservations(self.released)
        return SlotRequirement(
            slot,
            region.id,
            location.id,
            target_for_slot(slot, region.curve),
            released.get(slot, authored.get(slot)),
            slot in authored,
            slot in released,
        )
