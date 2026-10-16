class_name ConsentFake
extends ConsentAdapter
## @api No SDK. Manual by default; controlled outcomes and analytics decisions are explicit.

var calls: FakeCalls = FakeCalls.new()
var _outcomes: Dictionary[StringName, StringName] = {}
var _immediate: Dictionary[StringName, bool] = {}
var _generation: int = 0
var _analytics_token: int = 0
var _operation: StringName = &""
var _pending: bool = false
var _outcome: StringName = &"manual"


## @api Record request_info; tests emit inherited signals to deliver success/failure/pending.
func request_info() -> void:
	calls.record("request_info", [])
	_begin(&"request_info")


## @api Record show_form_if_required; tests explicitly emit outcome signals.
func show_form_if_required() -> void:
	calls.record("show_form_if_required", [])
	_begin(&"show_form_if_required")


## @api Record request_att; tests emit inherited signals to deliver success/failure/pending.
func request_att() -> void:
	calls.record("request_att", [])
	_begin(&"request_att")


## @api Record show_privacy_options; tests explicitly emit outcome signals.
func show_privacy_options() -> void:
	calls.record("show_privacy_options", [])
	_begin(&"show_privacy_options")


## @api Invalid controls are rejected atomically. Valid changes cancel pending output.
func set_outcome(operation: StringName, outcome: StringName, immediate: bool = true) -> Error:
	var allowed: Array[StringName] = [&"manual", &"error", &"unknown"]
	if operation == &"request_att":
		allowed.append_array([&"not_determined", &"restricted", &"denied", &"authorized"])
	elif operation in [&"request_info", &"show_form_if_required", &"show_privacy_options"]:
		allowed.append_array([&"required", &"not_required", &"obtained"])
	else:
		return ERR_INVALID_PARAMETER
	if outcome not in allowed:
		return ERR_INVALID_PARAMETER
	_cancel()
	_outcomes[operation] = outcome
	_immediate[operation] = immediate
	return OK


func operation_token() -> int:
	return _generation if not _operation.is_empty() else 0


func settle(token: int) -> bool:
	if not _pending or token != _generation or _outcome == &"manual":
		return false
	_pending = false
	if _outcome == &"error":
		operation_failed.emit()
	elif _operation == &"request_att":
		var statuses: Dictionary = {
			&"unknown": AttStatus.UNKNOWN,
			&"not_determined": AttStatus.NOT_DETERMINED,
			&"restricted": AttStatus.RESTRICTED,
			&"denied": AttStatus.DENIED,
			&"authorized": AttStatus.AUTHORIZED
		}
		att_resolved.emit(statuses[_outcome])
	else:
		var states: Dictionary = {
			&"unknown": State.UNKNOWN,
			&"required": State.REQUIRED,
			&"not_required": State.NOT_REQUIRED,
			&"obtained": State.OBTAINED
		}
		consent_resolved.emit(states[_outcome])
	return true


## @api Purpose-specific decision is independent of UMP/ATT; one decision per live UMP token.
func resolve_analytics(token: int, allowed: bool) -> bool:
	if (
		token != _generation
		or token == _analytics_token
		or _operation not in [&"request_info", &"show_form_if_required", &"show_privacy_options"]
	):
		return false
	_analytics_token = token
	analytics_resolved.emit(allowed)
	return true


func reset() -> void:
	_cancel()
	_outcomes.clear()
	_immediate.clear()
	calls.entries.clear()


func _cancel() -> void:
	_generation += 1
	_operation = &""
	_pending = false


func _begin(operation: StringName) -> void:
	_cancel()
	_operation = operation
	_outcome = _outcomes.get(operation, &"manual")
	_pending = true
	if _immediate.get(operation, false):
		settle(_generation)
