class_name AnalyticsRegistry
extends RefCounted
## @api Event definitions and strict payload validation; no tracking or I/O.

var _events: Dictionary[StringName, Dictionary] = {}


## @api Append a document atomically; reject duplicates and malformed definitions.
func append_document(document: Dictionary) -> Error:
	if document.is_empty():
		return ERR_INVALID_DATA
	var names: RegEx = RegEx.new()
	names.compile("^[a-z][a-z0-9_]*$")
	for key: Variant in document:
		if not key is String or names.search(key) == null or _events.has(StringName(key)):
			return ERR_INVALID_DATA
		if not _valid_definition(document[key], names):
			return ERR_INVALID_DATA
	for key: String in document:
		_events[StringName(key)] = document[key].duplicate(true)
	return OK


## @api Independent copy of an event definition, or {} when unregistered.
func definition(name: StringName) -> Dictionary:
	return _events[name].duplicate(true) if _events.has(name) else {}


## @api Payload must contain exactly the registered params, with their declared types.
func validate(name: StringName, params: Dictionary) -> bool:
	if not _events.has(name):
		return false
	var expected: Dictionary = _events[name]["params"]
	if params.size() != expected.size():
		return false
	for key: Variant in params:
		if not key is String or not expected.has(key) or not _matches(expected[key], params[key]):
			return false
	return true


func _valid_definition(value: Variant, names: RegEx) -> bool:
	if not value is Dictionary or value.size() != 2:
		return false
	if not value.has("params") or not value.has("description"):
		return false
	if (
		not value["params"] is Dictionary
		or not value["description"] is String
		or value["description"].strip_edges().is_empty()
	):
		return false
	for key: Variant in value["params"]:
		if not key is String or names.search(key) == null:
			return false
		if value["params"][key] not in ["int", "float", "bool", "string"]:
			return false
	return true


func _matches(type_name: String, value: Variant) -> bool:
	match type_name:
		"int":
			return value is int and abs(float(value)) <= 9007199254740991.0
		"float":
			return value is float and is_finite(value) and abs(value) <= 9007199254740991.0
		"bool":
			return value is bool
		"string":
			return value is String
	return false
