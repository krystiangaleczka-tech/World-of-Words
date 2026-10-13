"""Semantic manifest partitions; called after shared structural schema validation."""

from __future__ import annotations

import math


def count(value: object) -> int:
    if type(value) not in (int, float) or not math.isfinite(value) or not 1 <= value <= 2**53 - 1:
        raise ValueError("Invalid manifest metadata count")
    if int(value) != value:
        raise ValueError("Fractional manifest metadata count")
    return int(value)


def partition(records: list[dict], slots: int) -> dict[str, dict]:
    expected, indexed = 1, {}
    for record in records:
        first, last = count(record["first"]), count(record["last"])
        if first != expected or last < first or record["id"] in indexed:
            raise ValueError("Manifest metadata has gaps, overlaps or duplicate IDs")
        expected = last + 1
        indexed[record["id"]] = record
    if not records or expected != slots + 1:
        raise ValueError("Manifest metadata does not cover all slots")
    return indexed


def validate_manifest_metadata(manifest: dict) -> None:
    present = [key in manifest for key in ("regions", "locations", "landmarks")]
    if not any(present):
        return
    if not all(present):
        raise ValueError("Manifest metadata must be all-or-none")
    slots = count(manifest["slots"])
    regions = partition(manifest["regions"], slots)
    partition(manifest["locations"], slots)
    for location in manifest["locations"]:
        region = regions.get(location["region"])
        if (
            region is None
            or location["first"] < region["first"]
            or location["last"] > region["last"]
        ):
            raise ValueError("Location outside its referenced region")
    seen: set[int] = set()
    for record in manifest["landmarks"]:
        slot = count(record["slot"])
        if slot > slots or slot in seen:
            raise ValueError("Duplicate or out-of-range landmark slot")
        seen.add(slot)
