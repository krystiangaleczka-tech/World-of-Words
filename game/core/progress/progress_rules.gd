class_name ProgressRules
extends RefCounted
## @api Pure injected star, postcard and unlock rules; no side effects.

const FEATURES: Array[String] = [
	"shuffle", "bonus_meter", "hint", "journey", "reveal", "double_reward", "daily"
]
var _values: Dictionary = {}


static func from_config(values: Dictionary) -> ProgressRules:
	var keys: Array[String] = [
		"meta.stars.per_level", "meta.postcard.pieces", "meta.postcard.piece_star_cost"
	]
	for feature: String in FEATURES:
		keys.append("unlocks." + feature + "_slot")
	for key: String in keys:
		if (
			not values.get(key) is int
			or not ProgressSnapshot.valid_count(values[key])
			or values[key] < 1
		):
			return null
	if values["meta.stars.per_level"] != 1:
		return null
	var result: ProgressRules = ProgressRules.new()
	for key: String in keys:
		result._values[key] = values[key]
	return result


func stars_per_level() -> int:
	return _values.get("meta.stars.per_level", 0)


func piece_count() -> int:
	return _values.get("meta.postcard.pieces", 0)


## @api Thresholds never remove prior credits; complete locations fill all configured pieces.
func revealed_pieces(stars: int, previous: int, complete: bool = false) -> int:
	if (
		_values.is_empty()
		or not ProgressSnapshot.valid_count(stars)
		or not ProgressSnapshot.valid_count(previous)
	):
		return -1
	@warning_ignore("integer_division")
	var threshold: int = stars / int(_values["meta.postcard.piece_star_cost"])
	return maxi(previous, piece_count() if complete else mini(piece_count(), threshold))


## @api Newly eligible IDs append in canonical order; previous unknown IDs survive.
func unlocked_features(current_slot: int, previous: PackedStringArray) -> PackedStringArray:
	if (
		_values.is_empty()
		or current_slot < 1
		or not ProgressSnapshot.valid_count(current_slot)
		or not ProgressSnapshot.valid_ids(previous)
	):
		return PackedStringArray()
	var result: PackedStringArray = previous.duplicate()
	for feature: String in FEATURES:
		if current_slot >= _values["unlocks." + feature + "_slot"] and not result.has(feature):
			result.append(feature)
	return result


func location_complete(highest_completed: int, last_slot: int) -> bool:
	return (
		not _values.is_empty()
		and ProgressSnapshot.valid_count(highest_completed)
		and ProgressSnapshot.valid_count(last_slot)
		and last_slot > 0
		and highest_completed >= last_slot
	)


func region_unlocked(current_slot: int, first_slot: int) -> bool:
	return (
		not _values.is_empty()
		and ProgressSnapshot.valid_count(current_slot)
		and ProgressSnapshot.valid_count(first_slot)
		and first_slot > 0
		and current_slot >= first_slot
	)
