class_name AtomicProgressPort
extends ProgressCommitPort
## @api Explicit concrete coordinator. It never replaces P1 or activates itself in boot.

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")
const ECONOMY_SCRIPT: Script = preload("res://services/economy.gd")

var _save: SAVE_SCRIPT
var _progress: PROGRESS_SCRIPT
var _economy: ECONOMY_SCRIPT
var _pending: Dictionary = {}
var _busy: bool = false


## @api Bind one concrete owner pair through Save before load; reconfiguration is forbidden.
func configure(save: SAVE_SCRIPT, progress: PROGRESS_SCRIPT, economy: ECONOMY_SCRIPT) -> Error:
	if _save != null or _busy:
		return ERR_ALREADY_IN_USE
	if (
		not is_instance_valid(save)
		or not is_instance_valid(progress)
		or not is_instance_valid(economy)
	):
		return ERR_UNCONFIGURED
	if not progress.atomic_save_matches(save) or not economy.atomic_save_matches(save):
		return ERR_INVALID_PARAMETER
	var error: Error = save.configure_atomic(progress, economy)
	if error != OK:
		return error
	_save = save
	_progress = progress
	_economy = economy
	return OK


func is_available() -> bool:
	return (
		is_instance_valid(_save)
		and is_instance_valid(_progress)
		and is_instance_valid(_economy)
		and _progress.atomic_save_matches(_save)
		and _economy.atomic_save_matches(_save)
		and _progress.atomic_available()
		and _economy.atomic_available()
	)


func read_committed(language: String, context: Dictionary) -> Dictionary:
	if not is_instance_valid(_progress) or not is_instance_valid(_economy):
		return _unavailable()
	var result: Dictionary = _progress.read_atomic(language, context)
	if result.error != OK:
		return result
	return result if is_available() else _unavailable()


func transact(request: Dictionary) -> Dictionary:
	if _busy:
		return _result(ERR_BUSY, "pending", str(request.get("language", "")))
	if not AtomicRequest.valid(request):
		return _result(ERR_INVALID_PARAMETER, "rejected", str(request.get("language", "")))
	_busy = true
	var result: Dictionary = _transact(request)
	_busy = false
	return result


func _transact(request: Dictionary) -> Dictionary:
	var hash: String = AtomicRequest.hash_value(request)
	if not _pending.is_empty():
		return _retry() if hash == _pending.hash else _result(ERR_BUSY, "pending", request.language)
	if not is_available():
		return _availability_result(request.language, request.context)
	var started: Dictionary = _save.begin_transaction(request)
	if started.state != "preparing":
		return _map(started, request.language)
	var transaction: SaveTransaction = started.transaction
	var progress: ProgressPrepared = _progress.prepare_completion(transaction)
	var economy: EconomyPrepared = _economy.prepare_commands(transaction, progress)
	if (
		not _save.validates_progress(progress, transaction)
		or not _economy.validates_prepared(economy, transaction)
	):
		_save.abort_transaction(transaction)
		return _result(ERR_INVALID_DATA, "rejected", request.language)
	_pending = {
		"transaction": transaction,
		"progress": progress,
		"economy": economy,
		"operation_id": request.operation_id,
		"language": request.language,
		"hash": hash
	}
	return _commit_pending()


func recover(operation_id: String, context: Dictionary) -> Dictionary:
	if _busy:
		return _result(ERR_BUSY, "pending", "")
	if (
		not AtomicRequest.closed(context, ["request_hash"])
		or not AtomicRequest.valid_hash(context.request_hash)
	):
		return _result(ERR_INVALID_PARAMETER, "rejected", "")
	if not is_instance_valid(_save):
		return _unavailable()
	_busy = true
	var result: Dictionary = _recover(operation_id, context.request_hash)
	_busy = false
	return result


func _recover(operation_id: String, hash: String) -> Dictionary:
	if not _pending.is_empty():
		if operation_id != _pending.operation_id or hash != _pending.hash:
			return _result(ERR_BUSY, "pending", _pending.language)
		var result: Dictionary = _save.recover_transaction(operation_id, hash)
		return _finish(result)
	var result: Dictionary = _save.recover_transaction(operation_id, hash)
	var language: String = str(result.receipt.get("language", ""))
	return _map(result, language)


func _retry() -> Dictionary:
	var result: Dictionary = _save.recover_transaction(_pending.operation_id, _pending.hash)
	if (
		result.error == ERR_BUSY
		and result.state == "pending"
		and _save.validates_transaction(_pending.transaction)
	):
		return _commit_pending()
	return _finish(result)


func _commit_pending() -> Dictionary:
	var result: Dictionary = _save.commit_transaction(
		_pending.transaction, _pending.progress, _pending.economy
	)
	return _finish(result)


func _finish(result: Dictionary) -> Dictionary:
	var language: String = _pending.language
	if result.error == OK or not _save.validates_transaction(_pending.transaction):
		_pending.clear()
	elif result.state == "rejected" and _save.abort_transaction(_pending.transaction) == OK:
		_pending.clear()
	return _map(result, language)


func _map(result: Dictionary, language: String) -> Dictionary:
	var receipt: Dictionary = result.receipt.duplicate(true)
	if result.error == OK and not receipt.is_empty():
		# Idempotent owner publication; failure never changes durable success.
		_save.publish_receipt(receipt)
	return {
		"error": result.error,
		"state": result.state,
		"snapshot": _snapshot(result.view, language),
		"receipt": receipt
	}


func _availability_result(language: String, context: Dictionary) -> Dictionary:
	var read_context: Dictionary = {
		"content_version": context.content_version, "manifest_hash": context.manifest_hash
	}
	var result: Dictionary = read_committed(language, read_context)
	return result if result.state == "needs_migration" else _unavailable()


func _result(error: Error, state: String, language: String) -> Dictionary:
	var snapshot: Dictionary = (
		_snapshot(_save.committed_view(), language) if is_instance_valid(_save) else {}
	)
	return {"error": error, "state": state, "snapshot": snapshot, "receipt": {}}


func _snapshot(view: Dictionary, language: String) -> Dictionary:
	if view.get("error") != OK or language.is_empty():
		return {}
	var state: Dictionary = view.sections.progress.by_lang.get(language, SaveSchema.LANGUAGE_STATE)
	return ProgressSaveAdapter.domain(state)


func certifies(save: Node, progress: Node) -> bool:
	return (
		is_instance_valid(_save)
		and is_instance_valid(_progress)
		and is_instance_valid(_economy)
		and _save == save
		and _progress == progress
		and _progress.atomic_save_matches(_save)
		and _economy.atomic_save_matches(_save)
	)


func completion_commands(language: String, slot: int) -> Array[Dictionary]:
	return _economy.completion_commands(language, slot) if is_available() and not _busy else []


## @api Paid callers use this port's exact Economy owner; no separate wallet injection.
func tool_commands(kind: StringName, complete: bool = false) -> Array[Dictionary]:
	return _economy.tool_commands(kind, complete) if is_available() and not _busy else []
