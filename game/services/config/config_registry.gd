class_name ConfigRegistry
extends RefCounted
## @api Validated registry defaults. Remote overrides and cache loading belong to T-0254.

var _entries: Dictionary[StringName, Dictionary] = {}
var _values: Dictionary[StringName, Variant] = {}


## @api Atomically append one prefix document; reject duplicates, bad metadata/types/ranges.
func append_document(prefix: String, document: Dictionary) -> Error:
	if document.is_empty():
		return ERR_INVALID_DATA
	var name_pattern: RegEx = RegEx.new()
	name_pattern.compile("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")
	for raw_key: Variant in document:
		if not raw_key is String or name_pattern.search(raw_key) == null:
			return ERR_INVALID_DATA
		if raw_key.get_slice(".", 0) != prefix or _entries.has(StringName(raw_key)):
			return ERR_INVALID_DATA
		if not document[raw_key] is Dictionary or not _valid_definition(raw_key, document[raw_key]):
			return ERR_INVALID_DATA
	for raw_key: String in document:
		var key: StringName = StringName(raw_key)
		var entry: Dictionary = document[raw_key].duplicate(true)
		_entries[key] = entry
		var value: Variant = entry["default"]
		match entry["type"]:
			"int":
				value = int(value)
			"float":
				value = float(value)
		_values[key] = value
	return OK


## @api Whether a key exists; safe before loading and without emitting errors.
func has_key(key: StringName) -> bool:
	return _entries.has(key)


## @api Independent metadata copy for tooling and future override validation.
func definition(key: StringName) -> Dictionary:
	return _entries[key].duplicate(true) if _entries.has(key) else {}


## @api Strict typed read; debug misuse emits push_error; release returns typed fallback.
func read_value(key: StringName, expected_type: StringName, fallback: Variant) -> Variant:
	if not _entries.has(key) or _entries[key]["type"] != str(expected_type):
		if OS.is_debug_build():
			push_error("Config key '%s' is unknown or is not %s" % [key, expected_type])
		return fallback
	return _values[key]


func _numeric(value: Variant, integer: bool) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return (
		is_finite(number)
		and abs(number) <= 9007199254740991.0
		and (not integer or floor(number) == number)
	)


func _valid_definition(key: String, entry: Dictionary) -> bool:
	var fields: Array[String] = ["default", "type", "range", "description", "owner", "remote"]
	if entry.size() != fields.size():
		return false
	for field: String in fields:
		if not entry.has(field):
			return false
	if not entry["type"] in ["int", "float", "bool", "string"] or not entry["remote"] is bool:
		return false
	if (
		not entry["description"] is String
		or not entry["owner"] is String
		or entry["description"].strip_edges().is_empty()
		or entry["owner"].strip_edges().is_empty()
	):
		return false
	if entry["remote"] and (key.begins_with("unlocks.") or key.begins_with("consent.")):
		return false
	return _valid_default(entry)


func _valid_default(entry: Dictionary) -> bool:
	var value: Variant = entry["default"]
	var bounds: Variant = entry["range"]
	if entry["type"] in ["int", "float"]:
		var integer: bool = entry["type"] == "int"
		if not _numeric(value, integer) or not bounds is Array or bounds.size() != 2:
			return false
		if not _numeric(bounds[0], integer) or not _numeric(bounds[1], integer):
			return false
		return bounds[0] <= bounds[1] and bounds[0] <= value and value <= bounds[1]
	return (
		bounds == null
		and (
			(entry["type"] == "bool" and value is bool)
			or (entry["type"] == "string" and value is String)
		)
	)
