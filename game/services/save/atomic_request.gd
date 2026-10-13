class_name AtomicRequest
extends RefCounted
## @api Closed campaign request and deterministic full-request hash; never coerce numbers.

const REQUEST_KEYS: Array[String] = [
	"operation_id", "kind", "language", "context", "progress_candidate", "economy_commands", "delta"
]
const CONTEXT_KEYS: Array[String] = [
	"content_version",
	"manifest_hash",
	"level_id",
	"slot",
	"expected_current_slot",
	"expected_highest_completed_slot",
	"board_hash",
	"expected_progress_hash"
]


static func valid(request: Dictionary) -> bool:
	if not closed(request, REQUEST_KEYS) or not json_value(request):
		return false
	if request.kind != "campaign_complete" or not ProgressSnapshot.valid_id(request.language):
		return false
	if not request.context is Dictionary or not closed(request.context, CONTEXT_KEYS):
		return false
	var context: Dictionary = request.context
	for key: String in ["content_version", "slot", "expected_current_slot"]:
		if not ProgressSnapshot.valid_count(context[key]) or context[key] < 1:
			return false
	if not ProgressSnapshot.valid_count(context.expected_highest_completed_slot):
		return false
	for key: String in ["manifest_hash", "board_hash", "expected_progress_hash"]:
		if not valid_hash(context[key]):
			return false
	if not ProgressSnapshot.valid_id(context.level_id):
		return false
	if request.operation_id != "campaign_complete:%s:%d" % [request.language, context.slot]:
		return false
	if not request.progress_candidate is Dictionary:
		return false
	var candidate: Dictionary = request.progress_candidate
	if ProgressSnapshot.from_dict(candidate) == null or not integer_tree(candidate):
		return false
	if not request.delta is Dictionary or not integer_tree(request.delta):
		return false
	if not request.economy_commands is Array:
		return false
	for command: Variant in request.economy_commands:
		if not command is Dictionary or not closed(command, ["operation", "reason", "amounts"]):
			return false
		if command.operation not in ["grant", "spend"]:
			return false
		if not ProgressSnapshot.valid_id(command.reason) or not command.amounts is Dictionary:
			return false
		if not WalletSnapshot.valid_amounts(command.amounts):
			return false
	return true


static func closed(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true


static func valid_hash(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for index: int in value.length():
		if value[index] not in "0123456789abcdef":
			return false
	return true


static func hash_value(value: Dictionary) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()


static func integer_tree(value: Variant) -> bool:
	if value is float:
		return false
	if value is Dictionary:
		for key: Variant in value:
			if not integer_tree(value[key]):
				return false
	if value is Array:
		for item: Variant in value:
			if not integer_tree(item):
				return false
	return true


static func json_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT:
			return (
				value >= -ProgressSnapshot.MAX_SAFE_COUNT
				and value <= ProgressSnapshot.MAX_SAFE_COUNT
			)
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not key is String or not json_value(value[key]):
					return false
			return true
		TYPE_ARRAY:
			for item: Variant in value:
				if not json_value(item):
					return false
			return true
	return false
