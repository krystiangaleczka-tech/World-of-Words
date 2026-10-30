"""Add explicit, reviewer-supplied region/location metadata to a validated manifest."""

from copy import deepcopy
from collections.abc import Mapping

from ..sequence.slots import SlotPlan
from ..validate.manifest import validate_manifest_metadata
from ..validate.schema import SchemaRegistry


def p2_manifest(
    base: dict,
    plan: SlotPlan,
    region_metadata: Mapping[str, dict],
    location_metadata: Mapping[str, dict],
    registry: SchemaRegistry,
) -> dict:
    """Return schema-valid additive v1.1 metadata without writing content or locks."""
    if (
        not isinstance(base, dict)
        or not isinstance(plan, SlotPlan)
        or not isinstance(region_metadata, Mapping)
        or not isinstance(location_metadata, Mapping)
        or not isinstance(registry, SchemaRegistry)
    ):
        raise ValueError("Expected existing manifest, complete slot plan and explicit metadata")
    registry.validate_schema("manifest", base)
    if base.get("slots") != plan.total or any(
        key in base for key in ("regions", "locations", "landmarks")
    ):
        raise ValueError("P2 metadata requires an unmodified matching base manifest")
    if set(region_metadata) != {region.id for region in plan.regions} or set(
        location_metadata
    ) != {location.id for location in plan.locations}:
        raise ValueError("Every planned region and location requires exact editorial metadata")
    regions = []
    for region in plan.regions:
        details = region_metadata[region.id]
        if not isinstance(details, dict) or set(details) != {"name_key"}:
            raise ValueError("Invalid reviewed region metadata")
        regions.append(
            {
                "id": region.id,
                "name_key": details["name_key"],
                "first": region.curve.first,
                "last": region.curve.last,
            }
        )
    locations = []
    for location in plan.locations:
        details = location_metadata[location.id]
        if not isinstance(details, dict) or set(details) != {"name_key", "postcard", "pieces"}:
            raise ValueError("Invalid reviewed location metadata")
        locations.append(
            {
                "id": location.id,
                "region": location.region,
                "name_key": details["name_key"],
                "first": location.first,
                "last": location.last,
                "postcard": details["postcard"],
                "pieces": details["pieces"],
            }
        )
    landmark_slots = [slot for region in plan.regions for slot in region.curve.landmarks]
    result = deepcopy(base)
    result.update(
        regions=regions,
        locations=locations,
        landmarks=[{"slot": slot, "landmark": True} for slot in landmark_slots],
    )
    registry.validate_schema("manifest", result)
    validate_manifest_metadata(result)
    return result
