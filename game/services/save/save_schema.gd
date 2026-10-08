class_name SaveSchema
extends RefCounted
## @api Save v2 structural contract. Content-specific board validation belongs to BoardState.

const VERSION: int = 2
const LANGUAGE_STATE: Dictionary = {
	"current_slot": 1,
	"completed_slot": 0,
	"highest_completed_slot": 0,
	"stars": 0,
	"level_state": null,
	"location_pieces": {}
}
const SECTIONS: Array[StringName] = [
	&"meta", &"settings", &"progress", &"economy", &"daily", &"monetization"
]
const SETTINGS: Array[StringName] = [
	&"sfx_volume",
	&"music_volume",
	&"haptics_enabled",
	&"reduced_motion",
	&"high_contrast",
	&"text_scale",
	&"language"
]
const TEMPLATE: Dictionary = {
	"schema_version": 2,
	"meta": {"install_id": "", "created_at": "", "app_version": ""},
	"settings":
	{
		"sfx_volume": 1.0,
		"music_volume": 0.8,
		"haptics_enabled": true,
		"reduced_motion": false,
		"high_contrast": false,
		"text_scale": 0,
		"language": "pl"
	},
	"progress":
	{"by_lang": {"pl": LANGUAGE_STATE}, "unlocked": [], "coach_marks_seen": [], "bonus_meter": 0},
	"economy": {"coins": 0, "items": {"hint": 0, "reveal": 0}, "journal": []},
	"daily":
	{
		"completed_days": [],
		"last_seen_day": null,
		"level_state": null,
		"freezes": 0,
		"last_freeze_week": null,
		"streak": 0,
		"streak_broken_at": null
	},
	"monetization":
	{
		"remove_forced_ads": false,
		"processed_transactions": [],
		"last_interstitial": null,
		"levels_since_interstitial": 0,
		"levels_since_purchase": null,
		"shop_coins_ads": {}
	}
}


## @api Build an independent clean document with injected identity, time and build version.
static func fresh(install_id: String, created_at: String, app_version: String) -> Dictionary:
	var data: Dictionary = TEMPLATE.duplicate(true)
	data["meta"] = {"install_id": install_id, "created_at": created_at, "app_version": app_version}
	return data


## @api RFC 4122 random UUID v4, generated only when a new save is needed.
static func new_install_id(entropy: PackedByteArray = PackedByteArray()) -> String:
	var bytes: PackedByteArray = entropy.duplicate()
	if bytes.is_empty():
		bytes = Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex: String = bytes.hex_encode()
	return (
		"%s-%s-%s-%s-%s"
		% [
			hex.substr(0, 8),
			hex.substr(8, 4),
			hex.substr(12, 4),
			hex.substr(16, 4),
			hex.substr(20, 12)
		]
	)


## @api Reject invalid structure and values that JSON cannot preserve; allow extension keys.
static func is_valid(data: Dictionary) -> bool:
	if (
		not _matches(TEMPLATE, data)
		or not _json_safe(data)
		or not _valid_progress(data["progress"])
	):
		return false
	var uuid: RegEx = RegEx.new()
	uuid.compile("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	return data["schema_version"] == VERSION and uuid.search(data["meta"]["install_id"]) != null


## @api Convert known numeric fields to their declared types after JSON parsing.
static func canonical(data: Dictionary) -> Dictionary:
	if not is_valid(data):
		return {}
	return _canonical(TEMPLATE, data) as Dictionary


static func _canonical(template: Variant, value: Variant) -> Variant:
	if template is Dictionary:
		var result: Dictionary = value.duplicate(true)
		for key: Variant in template:
			if key == "by_lang":
				for language: String in value[key]:
					result[key][language] = _canonical(LANGUAGE_STATE, value[key][language])
			else:
				result[key] = _canonical(template[key], value[key])
		return result
	if template is int:
		return int(value)
	if template is float:
		return float(value)
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


static func _matches(template: Variant, value: Variant) -> bool:
	if template is Dictionary:
		if not value is Dictionary:
			return false
		for key: Variant in template:
			if not value.has(key):
				return false
			if key == "by_lang":
				if not value[key] is Dictionary:
					return false
				for language: Variant in value[key]:
					if not language is String or language.is_empty():
						return false
					if not _matches(LANGUAGE_STATE, value[key][language]):
						return false
			elif not _matches(template[key], value[key]):
				return false
		return true
	if template == null:
		return true
	if template is int:
		return (
			(value is int or value is float)
			and is_finite(float(value))
			and floor(float(value)) == float(value)
		)
	if template is float:
		return (value is int or value is float) and is_finite(float(value))
	return typeof(template) == typeof(value)


static func _valid_progress(progress: Dictionary) -> bool:
	if progress["bonus_meter"] < 0:
		return false
	for language: String in progress["by_lang"]:
		var state: Dictionary = progress["by_lang"][language]
		if state["current_slot"] < 1:
			return false
		for key: String in ["completed_slot", "highest_completed_slot", "stars"]:
			if state[key] < 0:
				return false
		if not _valid_board_snapshot(state["level_state"]):
			return false
	return true


static func _valid_board_snapshot(snapshot: Variant) -> bool:
	if snapshot == null:
		return true
	if not snapshot is Dictionary:
		return false
	var level_id: Variant = snapshot.get("level_id")
	if not level_id is String or level_id.is_empty():
		return false
	for key: String in ["found_words", "bonus_words"]:
		if not snapshot.get(key) is Array:
			return false
		var seen_words: Dictionary[String, bool] = {}
		for word: Variant in snapshot[key]:
			if not word is String or word.is_empty() or seen_words.has(word):
				return false
			seen_words[word] = true
	if not snapshot.get("revealed_cells") is Array:
		return false
	var seen_cells: Dictionary[Vector2i, bool] = {}
	for entry: Variant in snapshot["revealed_cells"]:
		if not entry is Array or entry.size() != 2:
			return false
		for coordinate: Variant in entry:
			if not _matches(0, coordinate) or coordinate < 0 or coordinate >= LevelData.MAX_GRID:
				return false
		var cell: Vector2i = Vector2i(int(entry[0]), int(entry[1]))
		if seen_cells.has(cell):
			return false
		seen_cells[cell] = true
	return true


static func _json_safe(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _json_safe(value[key]):
				return false
	elif value is Array:
		for item: Variant in value:
			if not _json_safe(item):
				return false
	elif value is int or value is float:
		return is_finite(float(value)) and abs(float(value)) <= 9007199254740991.0
	else:
		return value == null or value is String or value is bool
	return true
