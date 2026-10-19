"""Explicit region-local targets; no slot assignment or production calibration."""

import math
from dataclasses import dataclass
from itertools import pairwise
from pathlib import Path

from ..config import parse_json

MAX_SLOT = 2**53 - 1
ONBOARDING_LAST = 15  # CONTENT.md: handmade, outside the generated curve.


def _count(value: object) -> int:
    if type(value) is not int or not 1 <= value <= MAX_SLOT:
        raise ValueError("Expected positive manifest-safe integer")
    return value


def _unit(value: object) -> float:
    if type(value) not in (int, float) or not 0 <= value <= 1 or not math.isfinite(value):
        raise ValueError("Expected finite numeric value0..1")
    return float(value)


@dataclass(frozen=True)
class CurveConfig:
    first: int
    last: int
    base: float
    trend: float
    period: int
    amplitude: float
    landmark_spike: float
    breather_drop: float
    landmarks: tuple[int, ...]

    def __post_init__(self) -> None:
        _count(self.first)
        _count(self.last)
        _count(self.period)
        if self.last < self.first or self.period < 2:
            raise ValueError("Invalid region bounds or saw period")
        for field in ("base", "trend", "amplitude", "landmark_spike", "breather_drop"):
            object.__setattr__(self, field, _unit(getattr(self, field)))
        if self.landmark_spike == 0 or self.breather_drop == 0:
            raise ValueError("Landmark spike and breather drop must be positive")
        if (
            not isinstance(self.landmarks, tuple)
            or any(type(slot) is not int for slot in self.landmarks)
            or tuple(sorted(set(self.landmarks))) != self.landmarks
            or any(
                not max(ONBOARDING_LAST, self.first - 1) < slot < self.last
                for slot in self.landmarks
            )
            or any(b == a + 1 for a, b in pairwise(self.landmarks))
        ):
            raise ValueError("Expected unique ordered in-region landmarks with separate breathers")

    @classmethod
    def from_dict(cls, data: object) -> "CurveConfig":
        fields = set(cls.__dataclass_fields__)
        if (
            not isinstance(data, dict)
            or set(data) != fields | {"schema_version"}
            or type(data["schema_version"]) is not int
            or data["schema_version"] != 1
            or not isinstance(data["landmarks"], list)
            or any(type(slot) is not int for slot in data["landmarks"])
        ):
            raise ValueError("Expected version1 curve config with exact fields")
        values = {field: data[field] for field in fields}
        values["landmarks"] = tuple(sorted(data["landmarks"]))
        return cls(**values)

    def to_dict(self) -> dict:
        return {
            "schema_version": 1,
            **{field: getattr(self, field) for field in self.__dataclass_fields__},
            "landmarks": list(self.landmarks),
        }


@dataclass(frozen=True)
class CurveTarget:
    slot: int
    kind: str
    target: float | None
    baseline: float | None

    def __post_init__(self) -> None:
        _count(self.slot)
        if self.kind == "onboarding":
            if self.slot > ONBOARDING_LAST or self.target is not None or self.baseline is not None:
                raise ValueError("Onboarding must have no generated target")
        elif self.kind in ("regular", "landmark", "breather") and self.slot > ONBOARDING_LAST:
            object.__setattr__(self, "target", _unit(self.target))
            object.__setattr__(self, "baseline", _unit(self.baseline))
        else:
            raise ValueError("Invalid curve target kind/slot")


def load_curve(path: Path) -> CurveConfig:
    try:
        return CurveConfig.from_dict(parse_json(path.read_text(encoding="utf-8")))
    except (OSError, ValueError) as exc:
        raise ValueError(f"{path}: {exc}") from exc


def _baseline(slot: int, config: CurveConfig) -> float:
    offset = slot - config.first
    saw = (offset % config.period) / (config.period - 1)
    return min(1.0, math.fsum((config.base, config.trend * offset, config.amplitude * saw)))


def target_for_slot(slot: int, config: CurveConfig) -> CurveTarget:
    _count(slot)
    if not isinstance(config, CurveConfig) or not config.first <= slot <= config.last:
        raise ValueError("Expected configured in-region slot")
    if slot <= ONBOARDING_LAST:
        return CurveTarget(slot, "onboarding", None, None)
    baseline = _baseline(slot, config)
    if slot in config.landmarks:
        return CurveTarget(slot, "landmark", min(1.0, baseline + config.landmark_spike), baseline)
    if slot - 1 in config.landmarks:
        previous = min(1.0, _baseline(slot - 1, config) + config.landmark_spike)
        target = max(
            0.0,
            min(
                baseline - config.breather_drop,
                previous - config.breather_drop,
                math.nextafter(previous, 0.0),
            ),
        )
        return CurveTarget(slot, "breather", target, baseline)
    return CurveTarget(slot, "regular", baseline, baseline)
