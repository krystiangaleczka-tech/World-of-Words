class_name SaveSchema
extends RefCounted
## @api Save v1 structural contract. Domain services own rules within their sections.

const VERSION: int = 1
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
	"schema_version": 1,
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
	{
		"by_lang":
		{
			"pl":
			{
				"current_slot": 1,
				"completed_slot": 0,
				"stars": 0,
				"level_state": null,
				"location_pieces": {}
			}
		},
		"unlocked": [],
		"coach_marks_seen": [],
		"bonus_meter": 0
	},
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
	if not _matches(TEMPLATE, data) or not _json_safe(data):
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
			result[key] = _canonical(template[key], value[key])
		return result
	if template is int:
		return int(value)
	if template is float:
		return float(value)
	return value


static func _matches(template: Variant, value: Variant) -> bool:
	if template is Dictionary:
		if not value is Dictionary:
			return false
		for key: Variant in template:
			if not value.has(key) or not _matches(template[key], value[key]):
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
