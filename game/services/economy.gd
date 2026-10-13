extends AtomicSaveOwner
## @api Global wallet owner. Serialize requests and retry an unresolved request before another.

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")

var _save: SAVE_SCRIPT
var _config: CONFIG_SCRIPT
var _events: EVENTS_SCRIPT
var _busy: bool = false
var _pending: Dictionary = {}


## @api Inject owners without I/O; cannot replace owners during unresolved work.
func configure(save: SAVE_SCRIPT, config: CONFIG_SCRIPT, events: EVENTS_SCRIPT) -> void:
	if _busy or not _pending.is_empty() or (is_instance_valid(_save) and _save.writes_blocked()):
		return
	_save = save
	_config = config
	_events = events


## @api Require loaded Save, configured journal bound, Clock and a valid wallet.
func is_ready() -> bool:
	return (
		get_clock() != null
		and is_instance_valid(_save)
		and _save.is_loaded()
		and is_instance_valid(_config)
		and _config.has_key(&"economy.journal.max_entries")
		and _config.get_int(&"economy.journal.max_entries") > 0
		and is_instance_valid(_events)
		and _wallet(_save.get_section(&"economy")) != null
	)


## @api Independent committed wallet value; pending writes remain invisible until retry succeeds.
func snapshot() -> Dictionary:
	if not is_ready():
		return {}
	var section: Dictionary = _visible_section()
	var result: Dictionary = _wallet(section).snapshot()
	result["bonus_counter"] = section["bonus_counter"]
	return result


## @api Independent oldest-first diagnostic history; legacy entries remain opaque.
func journal() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if is_ready():
		for entry: Dictionary in _visible_section()["journal"]:
			result.append(entry.duplicate(true))
	return result


## @api Validate complete amounts; pending or reentrant transactions cannot afford another action.
func can_afford(items: Dictionary) -> bool:
	return (
		is_ready()
		and not _save.writes_blocked()
		and not _busy
		and _pending.is_empty()
		and _wallet(_visible_section()).can_afford(items)
	)


## @api OK means durably persisted and notified; identical failed requests may be retried.
func grant(source: StringName, items: Dictionary) -> Error:
	return _transact(&"grant", source, items)


## @api True means durable success; false includes invalid, insufficient, busy and I/O failures.
func spend(sink: StringName, items: Dictionary) -> bool:
	return _transact(&"spend", sink, items) == OK


func _transact(operation: StringName, reason: StringName, amounts: Dictionary) -> Error:
	if _busy or (is_instance_valid(_save) and _save.writes_blocked()):
		return ERR_BUSY
	if not is_ready():
		return ERR_UNCONFIGURED
	if (
		str(reason).is_empty()
		or str(reason) != str(reason).strip_edges()
		or not WalletSnapshot.valid_amounts(amounts)
	):
		return ERR_INVALID_PARAMETER
	_busy = true
	var error: Error = _apply_or_retry(operation, reason, amounts)
	_busy = false
	return error


func _apply_or_retry(operation: StringName, reason: StringName, amounts: Dictionary) -> Error:
	var current: Dictionary = _save.get_section(&"economy")
	if not _pending.is_empty():
		if current != _pending["candidate"]:
			_pending.clear()
			return ERR_BUSY
		if (
			operation != _pending["operation"]
			or reason != _pending["reason"]
			or amounts != _pending["amounts"]
		):
			return ERR_BUSY
		return _flush_pending()
	var wallet: WalletSnapshot = _wallet(current)
	var changed: WalletSnapshot = (
		wallet.granted(amounts) if operation == &"grant" else wallet.spent(amounts)
	)
	if changed == null:
		return ERR_INVALID_DATA
	var candidate: Dictionary = current.duplicate(true)
	candidate.merge(changed.snapshot(), true)
	candidate["journal"].append(
		{
			"timestamp": get_clock().unix_time_seconds(),
			"operation": str(operation),
			"reason": str(reason),
			"amounts": amounts.duplicate(true)
		}
	)
	var limit: int = _config.get_int(&"economy.journal.max_entries")
	var history: Array = candidate["journal"]
	if history.size() > limit:
		candidate["journal"] = history.slice(history.size() - limit)
	var error: Error = _save.set_section(&"economy", candidate)
	if error != OK:
		return error
	_pending = {
		"before": current,
		"candidate": candidate,
		"operation": operation,
		"reason": reason,
		"amounts": amounts.duplicate(true)
	}
	return _flush_pending()


func _flush_pending() -> Error:
	var error: Error = _save.flush()
	if error != OK:
		return error
	if _save.get_section(&"economy") != _pending["candidate"]:
		_pending.clear()
		return ERR_BUSY
	var transaction: Dictionary = _pending
	_pending = {}
	_events.economy_changed.emit(
		transaction["operation"],
		transaction["reason"],
		transaction["amounts"].duplicate(true),
		snapshot()
	)
	return OK


func _visible_section() -> Dictionary:
	return _save.get_section(&"economy") if _pending.is_empty() else _pending["before"]


func _wallet(section: Dictionary) -> WalletSnapshot:
	return WalletSnapshot.from_dict({"coins": section["coins"], "items": section["items"]})


func atomic_has_pending() -> bool:
	return _busy or not _pending.is_empty()
