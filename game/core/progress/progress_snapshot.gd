class_name ProgressSnapshot
extends RefCounted
## @api Immutable domain value, not a Save schema or persistence adapter.

const MAX_SAFE_COUNT: int = 9007199254740991
const KEYS: Array[String] = [
	"current_slot", "stars", "location_stars", "location_pieces", "completed_locations", "unlocked"
]
var _data: Dictionary = {
	"current_slot": 1,
	"stars": 0,
	"location_stars": {},
	"location_pieces": {},
	"completed_locations": [],
	"unlocked": []
}


static func from_dict(source: Dictionary) -> ProgressSnapshot:
	if source.size() != KEYS.size():
		return null
	for key: String in KEYS:
		if not source.has(key):
			return null
	if not valid_count(source["current_slot"]) or source["current_slot"] < 1:
		return null
	if not valid_count(source["stars"]):
		return null
	var canonical: Dictionary = source.duplicate(true)
	canonical["current_slot"] = int(source["current_slot"])
	canonical["stars"] = int(source["stars"])
	var total: int = 0
	for field: String in ["location_stars", "location_pieces"]:
		if not source[field] is Dictionary:
			return null
		for id: Variant in source[field]:
			if not valid_id(id) or not valid_count(source[field][id]):
				return null
			var count: int = int(source[field][id])
			if field == "location_stars":
				if count > canonical["stars"] - total:
					return null
				total += count
			canonical[field][id] = count
	for field: String in ["completed_locations", "unlocked"]:
		if not valid_ids(source[field]):
			return null
		canonical[field] = Array(source[field])
	var result: ProgressSnapshot = ProgressSnapshot.new()
	result._data = canonical
	return result


## @api Return copied fields; callers may prepare an independent candidate.
func snapshot() -> Dictionary:
	return _data.duplicate(true)


static func valid_count(value: Variant) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= 0
		and value <= MAX_SAFE_COUNT
		and floorf(float(value)) == float(value)
	)


static func valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value == value.strip_edges()


static func valid_ids(value: Variant) -> bool:
	if not value is Array and not value is PackedStringArray:
		return false
	var seen: Dictionary[String, bool] = {}
	for id: Variant in value:
		if not valid_id(id) or seen.has(id):
			return false
		seen[id] = true
	return true
