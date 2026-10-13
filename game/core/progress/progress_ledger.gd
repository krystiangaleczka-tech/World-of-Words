class_name ProgressLedger
extends RefCounted
## @api Pure per-language owner. Service candidates and durability remain T-0241/T-0242.

var _state: ProgressSnapshot
var _rules: ProgressRules
var _slots: int = 0
var _regions: Array[Dictionary] = []
var _locations: Array[Dictionary] = []


static func from_snapshot(
	source: Dictionary, rules: ProgressRules, metadata: Dictionary
) -> ProgressLedger:
	var state: ProgressSnapshot = ProgressSnapshot.from_dict(source)
	var slots: Variant = metadata.get("slots")
	if (
		state == null
		or rules == null
		or rules.stars_per_level() != 1
		or rules.piece_count() < 1
		or not ProgressSnapshot.valid_count(rules.piece_count())
		or not ProgressSnapshot.valid_count(slots)
		or slots < 1
		or slots == ProgressSnapshot.MAX_SAFE_COUNT
	):
		return null
	var regions: Array[Dictionary] = _records(metadata.get("regions"), false)
	var locations: Array[Dictionary] = _records(metadata.get("locations"), true)
	if not _partition(regions, slots) or not _partition(locations, slots):
		return null
	var data: Dictionary = state.snapshot()
	if data["current_slot"] > slots + 1:
		return null
	for location: Dictionary in locations:
		var region: Dictionary = _by_id(regions, location["region"])
		var completed: int = maxi(
			0, mini(data["current_slot"] - 1, location["last"]) - location["first"] + 1
		)
		if (
			region.is_empty()
			or location["first"] < region["first"]
			or location["last"] > region["last"]
			or data["location_stars"].get(location["id"], 0) > completed
			or (
				data["completed_locations"].has(location["id"])
				and not rules.location_complete(data["current_slot"] - 1, location["last"])
			)
		):
			return null
	data["unlocked"] = Array(
		rules.unlocked_features(data["current_slot"], PackedStringArray(data["unlocked"]))
	)
	var result: ProgressLedger = ProgressLedger.new()
	result._state = ProgressSnapshot.from_dict(data)
	result._rules = rules
	result._slots = slots
	result._regions = regions
	result._locations = locations
	return result


## @api Independent state; unconfigured owner exposes no candidate.
func snapshot() -> Dictionary:
	return _state.snapshot() if _state != null else {}


## @api Advance one current campaign slot. Empty result means invalid, duplicate or overflow.
func complete(slot: int) -> Dictionary:
	if _state == null:
		return {}
	var before: Dictionary = snapshot()
	if slot != before["current_slot"] or slot < 1 or slot > _slots:
		return {}
	var stars: int = _rules.stars_per_level()
	if before["stars"] > ProgressSnapshot.MAX_SAFE_COUNT - stars:
		return {}
	var location: Dictionary = _for_slot(_locations, slot)
	var id: String = location["id"]
	var candidate: Dictionary = before.duplicate(true)
	candidate["current_slot"] = slot + 1
	candidate["stars"] += stars
	candidate["location_stars"][id] = int(candidate["location_stars"].get(id, 0)) + stars
	var prior_pieces: int = candidate["location_pieces"].get(id, 0)
	var complete_location: bool = _rules.location_complete(slot, location["last"])
	candidate["location_pieces"][id] = _rules.revealed_pieces(
		candidate["location_stars"][id], prior_pieces, complete_location
	)
	var completed: Array[String] = []
	if complete_location and not candidate["completed_locations"].has(id):
		candidate["completed_locations"].append(id)
		completed.append(id)
	candidate["unlocked"] = Array(
		_rules.unlocked_features(slot + 1, PackedStringArray(before["unlocked"]))
	)
	var next: ProgressSnapshot = ProgressSnapshot.from_dict(candidate)
	if next == null:
		return {}
	var region_changes: Array[String] = []
	for region: Dictionary in _regions:
		if (
			_rules.region_unlocked(slot + 1, region["first"])
			and not _rules.region_unlocked(slot, region["first"])
		):
			region_changes.append(region["id"])
	var unlocked: Array[String] = []
	for feature: String in candidate["unlocked"]:
		if not before["unlocked"].has(feature):
			unlocked.append(feature)
	var piece_delta: Dictionary = {}
	var delta: int = candidate["location_pieces"][id] - prior_pieces
	if delta > 0:
		piece_delta[id] = delta
	_state = next
	return {
		"slot": slot,
		"stars": stars,
		"piece_delta": piece_delta,
		"completed_locations": completed,
		"unlocked": unlocked,
		"regions_unlocked": region_changes
	}


## @api Query credited values and endpoint completion; never backfills legacy rewards.
func location_status(id: StringName) -> Dictionary:
	if _state == null:
		return {}
	var location: Dictionary = _by_id(_locations, str(id))
	if location.is_empty():
		return {}
	var data: Dictionary = snapshot()
	return {
		"stars": data["location_stars"].get(str(id), 0),
		"pieces": data["location_pieces"].get(str(id), 0),
		"complete": _rules.location_complete(data["current_slot"] - 1, location["last"])
	}


## @api Available region IDs in manifest order, without IO or stored region grants.
func unlocked_regions() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if _state != null:
		var current: int = snapshot()["current_slot"]
		for region: Dictionary in _regions:
			if _rules.region_unlocked(current, region["first"]):
				result.append(region["id"])
	return result


static func _records(value: Variant, location: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var ids: Dictionary[String, bool] = {}
	for item: Variant in value:
		if not item is Dictionary:
			return []
		if (
			not ProgressSnapshot.valid_id(item.get("id"))
			or ids.has(item["id"])
			or not ProgressSnapshot.valid_count(item.get("first"))
			or item["first"] < 1
			or not ProgressSnapshot.valid_count(item.get("last"))
			or item["last"] < item["first"]
		):
			return []
		var record: Dictionary = {"id": item["id"], "first": item["first"], "last": item["last"]}
		if location:
			if not ProgressSnapshot.valid_id(item.get("region")):
				return []
			record["region"] = item["region"]
		ids[item["id"]] = true
		result.append(record)
	return result


static func _partition(records: Array[Dictionary], slots: int) -> bool:
	var next: int = 1
	for record: Dictionary in records:
		if record["first"] != next:
			return false
		next = record["last"] + 1
	return not records.is_empty() and next == slots + 1


static func _by_id(records: Array[Dictionary], id: String) -> Dictionary:
	for record: Dictionary in records:
		if record["id"] == id:
			return record
	return {}


static func _for_slot(records: Array[Dictionary], slot: int) -> Dictionary:
	for record: Dictionary in records:
		if record["first"] <= slot and slot <= record["last"]:
			return record
	return {}
