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
var _atomic_prepared_batches: Dictionary = {}
var _atomic_published_receipts: Dictionary = {}


## @api Inject owners without I/O; cannot replace owners during unresolved work.
func configure(save: SAVE_SCRIPT, config: CONFIG_SCRIPT, events: EVENTS_SCRIPT) -> void:
	if _busy or not _pending.is_empty() or (is_instance_valid(_save) and _save.writes_blocked()):
		return
	if _save != save:
		_atomic_published_receipts.clear()
	_atomic_prepared_batches.clear()
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


## @api Specialized grant owner: wallet/entitlement and store key share one durable document.
func grant_purchase(store_key: String, product_id: String) -> Error:
	if _busy or (is_instance_valid(_save) and _save.writes_blocked()):
		return ERR_BUSY
	if not is_ready() or not _config.has_key(&"iap.coins_s.amount"):
		return ERR_UNCONFIGURED
	if (
		store_key.is_empty()
		or store_key != store_key.strip_edges()
		or product_id not in ["nc.remove_forced_ads.v1", "c.coins_s.v1"]
	):
		return ERR_INVALID_PARAMETER
	_busy = true
	var error: Error = _apply_purchase(store_key, product_id)
	_busy = false
	return error


func _apply_purchase(key: String, product: String) -> Error:
	if not _pending.is_empty():
		if _pending.get("purchase_key") != key or _pending.get("product_id") != product:
			return ERR_BUSY
		return _flush_purchase()
	var view: Dictionary = _save.committed_view()
	if view.error != OK:
		return ERR_UNAVAILABLE
	if key in view.sections.monetization.processed_transactions:
		return OK
	var before: Dictionary = _save.get_section(&"economy")
	var monetization: Dictionary = _save.get_section(&"monetization")
	if before != view.sections.economy or monetization != view.sections.monetization:
		return ERR_BUSY
	return _stage_purchase(before, monetization, view, key, product)


func _stage_purchase(
	before: Dictionary, monetization: Dictionary, view: Dictionary, key: String, product: String
) -> Error:
	var amounts: Dictionary = {}
	var commands: Array[Dictionary] = []
	if product == "c.coins_s.v1":
		var coins: int = _config.get_int(&"iap.coins_s.amount")
		if coins < 1:
			return ERR_INVALID_DATA
		amounts = {"coins": coins}
		commands.append({"operation": "grant", "reason": "iap_coins", "amounts": amounts})
	else:
		monetization.remove_forced_ads = true
	var prepared: Dictionary = _build_batch(before, commands)
	if prepared.is_empty():
		return ERR_INVALID_DATA
	monetization.processed_transactions.append(key)
	var language: String = view.sections.settings.language
	monetization.last_purchase_slot = view.sections.progress.by_lang.get(language, {}).get(
		"current_slot", 1
	)
	monetization.levels_since_purchase = 0
	var error: Error = _save.stage_purchase(prepared.section, monetization)
	if error != OK:
		return error
	_pending = {
		"before": before,
		"candidate": prepared.section,
		"purchase_key": key,
		"product_id": product,
		"entitlement": monetization.remove_forced_ads,
		"amounts": amounts.duplicate(true)
	}
	return _flush_purchase()


func _flush_purchase() -> Error:
	var key: String = _pending.purchase_key
	if key not in _save.committed_view().sections.monetization.processed_transactions:
		var error: Error = _persist_purchase()
		if error != OK:
			return error
	var committed: Dictionary = _save.committed_view().sections
	if (
		key not in committed.monetization.processed_transactions
		or committed.economy != _pending.candidate
		or (_pending.entitlement and not committed.monetization.remove_forced_ads)
	):
		return ERR_BUSY
	var amounts: Dictionary = _pending.amounts.duplicate(true)
	_pending = {}
	if not amounts.is_empty():
		_events.economy_changed.emit(&"grant", &"iap_coins", amounts, snapshot())
	return OK


func _persist_purchase() -> Error:
	if _save.get_section(&"economy") != _pending.candidate:
		return ERR_BUSY
	var monetization: Dictionary = _save.get_section(&"monetization")
	if _pending.purchase_key not in monetization.processed_transactions:
		return ERR_BUSY
	if _pending.entitlement and not monetization.remove_forced_ads:
		monetization.remove_forced_ads = true
		var staged: Error = _save.stage_purchase(_pending.candidate, monetization)
		if staged != OK:
			return staged
	return _save.flush()


## @api True means durable success; false includes invalid, insufficient, busy and I/O failures.
func spend(sink: StringName, items: Dictionary) -> bool:
	return _transact(&"spend", sink, items) == OK


func _transact(operation: StringName, reason: StringName, amounts: Dictionary) -> Error:
	if _pending.has("purchase_key"):
		return ERR_BUSY
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
	var commands: Array[Dictionary] = [
		{"operation": str(operation), "reason": str(reason), "amounts": amounts.duplicate(true)}
	]
	var prepared: Dictionary = _build_batch(current, commands)
	if prepared.is_empty():
		return ERR_INVALID_DATA
	var candidate: Dictionary = prepared.section
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


## @api Copied configured proposal. Only approved completed-board preparation can authorize it.
func completion_commands(language: String, slot: int) -> Array[Dictionary]:
	if not atomic_available() or _save.writes_blocked():
		return []
	return _completion_commands(_save.committed_view(), language, slot, _reward_values())


## @api Canonical item-first debit proposal; completion rewards never finance a tool.
func tool_commands(kind: StringName, complete: bool = false) -> Array[Dictionary]:
	if (
		not atomic_available()
		or _save.writes_blocked()
		or atomic_has_pending()
		or kind not in [&"hint", &"reveal"]
	):
		return []
	return _tool_commands(_save.committed_view(), str(kind), complete)


func _tool_commands(view: Dictionary, kind: String, complete: bool) -> Array[Dictionary]:
	var state: Dictionary = view.sections.progress.by_lang.get(
		view.sections.settings.language, SaveSchema.LANGUAGE_STATE
	)
	var wallet: WalletSnapshot = _wallet(view.sections.economy)
	var amounts: Dictionary = (
		{kind: 1}
		if view.sections.economy.items[kind] > 0
		else RewardTable.from_config(_reward_values()).price(StringName(kind))
	)
	if wallet.spent(amounts) == null:
		return []
	var commands: Array[Dictionary] = [{"operation": "spend", "reason": kind, "amounts": amounts}]
	if complete:
		commands.append_array(
			_completion_commands(
				view, view.sections.settings.language, state.current_slot, _reward_values()
			)
		)
	return commands


func atomic_available() -> bool:
	return (
		is_ready()
		and _save.migration_state() == "ready"
		and RewardTable.from_config(_reward_values()) != null
	)


func prepare_commands(transaction: SaveTransaction, progress: ProgressPrepared) -> EconomyPrepared:
	var rejected: EconomyPrepared = EconomyPrepared.new()
	if (
		not atomic_available()
		or atomic_has_pending()
		or not _save.validates_progress(progress, transaction)
	):
		rejected.error = ERR_INVALID_DATA
		return rejected
	for value: EconomyPrepared in _atomic_prepared_batches:
		if (
			validates_prepared(value, transaction)
			and approved_progress(value, transaction) == progress
		):
			return value
	_atomic_prepared_batches.clear()
	var request: Dictionary = transaction.request()
	var view: Dictionary = transaction.committed_view()
	var values: Dictionary = _reward_values()
	var expected: Array[Dictionary] = _completion_commands(
		view, request.language, request.context.slot, values
	)
	if request.kind == "paid_tool":
		expected = _tool_commands(
			view,
			request.tool.kind,
			request.progress_candidate.current_slot == request.context.slot + 1
		)
		if expected.is_empty():
			rejected.error = ERR_INVALID_DATA
			return rejected
	if request.economy_commands != expected:
		rejected.error = ERR_INVALID_DATA
		return rejected
	var payload: Dictionary = _build_batch(view.sections.economy, expected)
	if payload.is_empty():
		rejected.error = ERR_INVALID_DATA
		return rejected
	var value: EconomyPrepared = EconomyPrepared.new()
	value.error = OK
	_atomic_prepared_batches[value] = {
		"save": _save,
		"transaction": transaction,
		"progress": progress,
		"hash": AtomicRequest.hash_value(request),
		"config": values,
		"limit": _config.get_int(&"economy.journal.max_entries"),
		"payload": payload.duplicate(true)
	}
	return value


func validates_prepared(value: RefCounted, transaction: SaveTransaction) -> bool:
	return (
		value is EconomyPrepared
		and value.error == OK
		and _atomic_prepared_batches.has(value)
		and _atomic_prepared_batches[value].save == _save
		and _atomic_prepared_batches[value].transaction == transaction
		and atomic_context_valid(transaction)
		and _save.validates_progress(_atomic_prepared_batches[value].progress, transaction)
		and _atomic_prepared_batches[value].hash == AtomicRequest.hash_value(transaction.request())
		and _atomic_prepared_batches[value].config == _reward_values()
		and _atomic_prepared_batches[value].limit == _config.get_int(&"economy.journal.max_entries")
	)


func prepared_payload(value: RefCounted, transaction: SaveTransaction) -> Dictionary:
	return (
		_atomic_prepared_batches[value].payload.duplicate(true)
		if validates_prepared(value, transaction)
		else {}
	)


func approved_progress(value: EconomyPrepared, transaction: SaveTransaction) -> ProgressPrepared:
	return (
		_atomic_prepared_batches[value].progress if validates_prepared(value, transaction) else null
	)


func atomic_context_valid(transaction: SaveTransaction) -> bool:
	return (
		atomic_available() and not atomic_has_pending() and _save.validates_transaction(transaction)
	)


## @api Publish only an issued/resolved current-lineage receipt, under Save's write barrier.
func accept_commit(receipt: Dictionary) -> Error:
	if _busy or not is_ready() or not _save.validates_receipt(receipt):
		return ERR_INVALID_DATA
	if not _save.receipt_publishing():
		return _save.publish_receipt(receipt)
	var notifications: Array[Dictionary] = _receipt_notifications(receipt)
	if notifications.size() != (receipt.notifications as Array).size():
		return ERR_INVALID_DATA
	var key: String = "%d:%s" % [receipt.lineage, receipt.operation_id]
	if _atomic_published_receipts.has(key):
		return OK
	_atomic_published_receipts[key] = true
	_busy = true
	for notification: Dictionary in notifications:
		_events.economy_changed.emit(
			StringName(notification.operation),
			StringName(notification.reason),
			notification.amounts.duplicate(true),
			snapshot()
		)
	_busy = false
	return OK


func _completion_commands(
	view: Dictionary, language: String, slot: int, values: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rewards: RewardTable = RewardTable.from_config(values)
	if rewards == null or language != view.sections.settings.language:
		return result
	var state: Dictionary = view.sections.progress.by_lang.get(language, SaveSchema.LANGUAGE_STATE)
	if slot != state.current_slot or slot <= state.highest_completed_slot:
		return result
	var base: Dictionary = rewards.reward(&"level_complete")
	if base.coins > 0:
		result.append({"operation": "grant", "reason": "level_complete", "amounts": base})
	if _onboarding_eligible(view, slot, values["unlocks.hint_slot"]):
		var hints: int = values["economy.grant.onboarding_hints"]
		if hints > 0:
			result.append(
				{"operation": "grant", "reason": "onboarding_hints", "amounts": {"hint": hints}}
			)
	return result


func _onboarding_eligible(view: Dictionary, slot: int, threshold: int) -> bool:
	if slot + 1 != threshold or view.sections.progress.unlocked.has("hint"):
		return false
	for state: Dictionary in view.sections.progress.by_lang.values():
		if state.current_slot >= threshold or state.unlocked.has("hint"):
			return false
	for proof: Dictionary in view.sections.meta.atomic.processed.values():
		for notification: Dictionary in proof.notifications:
			if notification.get("reason") == "onboarding_hints":
				return false
	return true


func _reward_values() -> Dictionary:
	if not is_instance_valid(_config):
		return {}
	var values: Dictionary = {}
	var keys: Array[String] = RewardTable.KEYS.duplicate()
	keys.append("unlocks.hint_slot")
	for key: String in keys:
		if not _config.has_key(StringName(key)):
			return {}
		values[key] = _config.get_int(StringName(key))
	return values


func _build_batch(section: Dictionary, commands: Array[Dictionary]) -> Dictionary:
	var candidate: Dictionary = section.duplicate(true)
	var notifications: Array[Dictionary] = []
	for command: Dictionary in commands:
		var wallet: WalletSnapshot = _wallet(candidate)
		var next: WalletSnapshot = (
			wallet.granted(command.amounts)
			if command.operation == "grant"
			else wallet.spent(command.amounts)
		)
		if next == null:
			return {}
		candidate.merge(next.snapshot(), true)
		candidate.journal.append(
			{
				"timestamp": get_clock().unix_time_seconds(),
				"operation": command.operation,
				"reason": command.reason,
				"amounts": command.amounts.duplicate(true)
			}
		)
		notifications.append(command.duplicate(true))
	var limit: int = _config.get_int(&"economy.journal.max_entries")
	if candidate.journal.size() > limit:
		candidate.journal = candidate.journal.slice(candidate.journal.size() - limit)
	return {"section": candidate, "delta": {}, "notifications": notifications}


func _receipt_notifications(receipt: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Variant in receipt.notifications:
		if (
			not source is Dictionary
			or not AtomicRequest.closed(source, ["operation", "reason", "amounts"])
		):
			return []
		if (
			source.operation not in ["grant", "spend"]
			or not ProgressSnapshot.valid_id(source.reason)
			or not source.amounts is Dictionary
		):
			return []
		var amounts: Dictionary = {}
		for key: Variant in source.amounts:
			var count: Variant = source.amounts[key]
			if (
				not (count is int or count is float)
				or not is_finite(float(count))
				or count < 0
				or count > WalletSnapshot.MAX_SAFE_COUNT
				or floorf(float(count)) != float(count)
			):
				return []
			amounts[key] = int(count)
		if not WalletSnapshot.valid_amounts(amounts):
			return []
		result.append({"operation": source.operation, "reason": source.reason, "amounts": amounts})
	return result


func atomic_save_matches(save: SAVE_SCRIPT) -> bool:
	return is_instance_valid(_save) and _save == save
