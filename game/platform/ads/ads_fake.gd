class_name AdsFake
extends AdsAdapter
## @api No SDK/grants. Manual by default; controlled outcomes may settle now or by token.

var calls: FakeCalls = FakeCalls.new()
var _outcomes: Dictionary[StringName, StringName] = {}
var _immediate: Dictionary[StringName, bool] = {}
var _generation: int = 0
var _operation: StringName = &""
var _pending: bool = false
var _outcome: StringName = &"manual"


## @api Record initialize; tests emit inherited signals to deliver success/failure/pending.
func initialize(consent: ConsentAdapter.State) -> void:
	calls.record("initialize", [consent])
	_begin(&"initialize")


## @api Record load_rewarded; tests emit inherited signals to deliver success/failure/pending.
func load_rewarded() -> void:
	calls.record("load_rewarded", [])
	_begin(&"load_rewarded")


## @api Record show_rewarded; tests emit inherited signals to deliver success/failure/pending.
func show_rewarded() -> void:
	calls.record("show_rewarded", [])
	_begin(&"show_rewarded")


## @api Record load_interstitial; tests emit inherited signals to deliver success/failure/pending.
func load_interstitial() -> void:
	calls.record("load_interstitial", [])
	_begin(&"load_interstitial")


## @api Record show_interstitial; tests emit inherited signals to deliver success/failure/pending.
func show_interstitial() -> void:
	calls.record("show_interstitial", [])
	_begin(&"show_interstitial")


## @api Changing controls cancels pending controlled output, preserving the call log.
func set_outcome(operation: StringName, outcome: StringName, immediate: bool = true) -> Error:
	var allowed: Array[StringName] = [&"manual", &"error"]
	if operation in [&"initialize", &"load_rewarded", &"load_interstitial"]:
		allowed.append(&"ready")
	elif operation == &"show_rewarded":
		allowed.append_array([&"reward", &"early_close"])
	elif operation == &"show_interstitial":
		allowed.append(&"shown")
	else:
		return ERR_INVALID_PARAMETER
	if operation != &"initialize":
		allowed.append(&"no_fill")
	if outcome not in allowed:
		return ERR_INVALID_PARAMETER
	_cancel()
	_outcomes[operation] = outcome
	_immediate[operation] = immediate
	return OK


func operation_token() -> int:
	return _generation if not _operation.is_empty() else 0


## @api One-shot settlement. Superseded/reset tokens cannot publish callbacks.
func settle(token: int) -> bool:
	if not _pending or token != _generation or _outcome == &"manual":
		return false
	_pending = false
	if _outcome in [&"no_fill", &"error"]:
		ad_failed.emit(str(_outcome))
	elif _operation == &"initialize":
		initialized.emit()
	elif _operation == &"load_rewarded":
		rewarded_loaded.emit()
	elif _operation == &"load_interstitial":
		interstitial_loaded.emit()
	else:
		var reward: bool = _outcome == &"reward"
		ad_opened.emit()
		if _generation != token:
			return true
		if reward:
			reward_earned.emit()
		if _generation == token:
			ad_closed.emit()
	return true


## @api Restore manual defaults and clear the isolated log.
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
