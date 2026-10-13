class_name AnalyticsRegistry
extends RefCounted
## @api Event definitions and strict payload validation; no tracking or I/O.

const EVENT_NAME_PATTERN: String = (
	"^(?!(?:firebase_|google_|ga_))(?!(?:ad_activeview|ad_click|ad_exposure"
	+ "|ad_query|ad_reward|adunit_exposure|app_clear_data|app_exception|app_i"
	+ "nstall|app_remove|app_store_refund|app_update|app_upgrade|dynamic_link"
	+ "_app_open|dynamic_link_app_update|dynamic_link_first_open|error|fireba"
	+ "se_campaign|firebase_in_app_message_action|firebase_in_app_message_dis"
	+ "miss|firebase_in_app_message_impression|first_open|first_visit|notific"
	+ "ation_dismiss|notification_foreground|notification_open|notification_r"
	+ "eceive|notification_send|os_update|session_start|user_engagement|scree"
	+ "n_view|ad_impression)$)[a-z][a-z0-9_]{0,39}(?![\\s\\S])"
)

const PARAM_NAME_PATTERN: String = (
	"^(?!(?:firebase_|google_|ga_))(?!(?:cid|currency|customer_id|customeri"
	+ "d|dclid|gclid|session_id|sessionid|sfmc_id|sid|srsltid|uid|user_id|use"
	+ "rid)$)[a-z][a-z0-9_]{0,39}(?![\\s\\S])"
)

var _events: Dictionary[StringName, Dictionary] = {}


## @api Append a document atomically; reject duplicates and malformed definitions.
func append_document(document: Dictionary) -> Error:
	if document.is_empty():
		return ERR_INVALID_DATA
	var names: RegEx = RegEx.new()
	names.compile(EVENT_NAME_PATTERN)
	var param_names: RegEx = RegEx.new()
	param_names.compile(PARAM_NAME_PATTERN)
	for key: Variant in document:
		if not key is String or names.search(key) == null or _events.has(StringName(key)):
			return ERR_INVALID_DATA
		if not _valid_definition(document[key], param_names):
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
