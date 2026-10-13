class_name AtomicSave
extends RefCounted
## Save's private coordinator. No caller-supplied document or approval flag is persisted.

var _storage: SaveStorage
var _publish: Callable
var _progress: AtomicSaveOwner
var _economy: AtomicSaveOwner
var _committed: Dictionary = {}
var _lease: SaveTransaction
var _request: Dictionary = {}
var _baseline: Dictionary = {}
var _view: Dictionary = {}
var _candidate: Dictionary = {}
var _proof: Dictionary = {}
var _progress_approval: ProgressPrepared
var _economy_approval: EconomyPrepared
var _started: bool = false
var _notifying: bool = false
var _writing: bool = false
var _issued: Dictionary = {}


func configure(storage: SaveStorage, publish: Callable) -> void:
	_storage = storage
	_publish = publish


func bind(progress: AtomicSaveOwner, economy: AtomicSaveOwner) -> Error:
	if _progress != null or _economy != null:
		return ERR_ALREADY_IN_USE
	if not _concrete(progress, "res://services/progress.gd"):
		return ERR_INVALID_PARAMETER
	if not _concrete(economy, "res://services/economy.gd"):
		return ERR_INVALID_PARAMETER
	_progress = progress
	_economy = economy
	return OK


func observe(document: Dictionary) -> void:
	_committed = document.duplicate(true)
	_issued.clear()


func blocked() -> bool:
	return _lease != null or _notifying


func view() -> Dictionary:
	if _committed.is_empty():
		return {"error": ERR_UNCONFIGURED, "lineage": 0, "revision": 0, "sections": {}}
	var sections: Dictionary = {}
	for section: StringName in SaveSchema.SECTIONS:
		sections[str(section)] = _committed[str(section)].duplicate(true)
	var atomic: Dictionary = (
		_committed.meta.atomic if _committed.schema_version == SaveSchema.VERSION else {}
	)
	return {
		"error": OK if _committed.schema_version == SaveSchema.VERSION else ERR_UNAVAILABLE,
		"lineage": atomic.get("lineage", 0),
		"revision": atomic.get("revision", 0),
		"sections": sections
	}


func begin(request: Dictionary, dirty: bool) -> Dictionary:
	if blocked() or dirty or _owner_pending():
		return _result(ERR_BUSY, "pending")
	if not _available():
		return _result(
			ERR_UNCONFIGURED if _committed.is_empty() else ERR_UNAVAILABLE, "unavailable"
		)
	if not AtomicRequest.valid(request):
		return _result(ERR_INVALID_PARAMETER, "rejected")
	var proof: Dictionary = _lookup(request.operation_id)
	if not proof.is_empty():
		return _replay(proof, AtomicRequest.hash_value(request))
	var language: Dictionary = _committed.progress.by_lang.get(request.language, {})
	var context: Dictionary = request.context
	if (
		context.slot <= language.get("highest_completed_slot", 0)
		or context.slot != language.get("current_slot", 1)
		or context.expected_current_slot != language.get("current_slot", 1)
		or context.expected_highest_completed_slot != language.get("highest_completed_slot", 0)
		or context.expected_progress_hash != AtomicRequest.hash_value(_domain(language))
		or request.language != _committed.settings.language
	):
		return _result(ERR_INVALID_DATA, "rejected")
	_lease = SaveTransaction.new()
	_request = request.duplicate(true)
	_baseline = _committed.duplicate(true)
	_lease._request = _request.duplicate(true)
	_view = view()
	_lease._view = _view.duplicate(true)
	var result: Dictionary = _result(OK, "preparing")
	result["transaction"] = _lease
	return result


func validates(transaction: SaveTransaction) -> bool:
	return (
		transaction != null
		and transaction == _lease
		and transaction.request() == _request
		and transaction.committed_view() == _baseline_view()
	)


func validates_progress(value: ProgressPrepared, transaction: SaveTransaction) -> bool:
	return (
		validates(transaction)
		and value != null
		and value.error == OK
		and is_instance_valid(_progress)
		and _progress.validates_prepared(value, transaction)
	)


func commit(
	transaction: SaveTransaction, progress: ProgressPrepared, economy: EconomyPrepared
) -> Dictionary:
	if _writing or _notifying:
		return _result(ERR_BUSY, "pending")
	var rejected: Dictionary = _commit_validation(transaction, progress, economy)
	if not rejected.is_empty():
		return rejected
	var candidate: Dictionary = _assemble(transaction, progress, economy)
	if candidate.is_empty() or (_started and not _same(candidate, _candidate)):
		return _result(ERR_INVALID_DATA, "pending" if _started else "rejected")
	if _started:
		var recovered: Dictionary = recover(
			_request.operation_id, AtomicRequest.hash_value(_request)
		)
		if _lease == null or recovered.error != ERR_BUSY or recovered.state != "pending":
			return recovered
	return _write(candidate, progress, economy)


func _write(
	candidate: Dictionary, progress: ProgressPrepared, economy: EconomyPrepared
) -> Dictionary:
	var selected: Dictionary = _selected()
	if selected.is_empty():
		return _result(ERR_UNAVAILABLE, "pending")
	if not _same(selected.document, _baseline):
		return _replacement(selected)
	var rotate: bool = selected.suffix.is_empty()
	if selected.suffix == ".tmp":
		if _storage.promote_temp() != OK:
			return _result(ERR_UNAVAILABLE, "pending")
		rotate = true
	# Revalidate owners at the final boundary, after any storage read or promotion callbacks.
	if not _approved(_lease, progress, economy):
		return _result(ERR_INVALID_DATA, "pending" if _started else "rejected")
	_candidate = candidate
	_proof = candidate.meta.atomic.processed[_key(_request.operation_id)]
	_progress_approval = progress
	_economy_approval = economy
	_started = true
	_writing = true
	var error: Error = _storage.commit(JSON.stringify(candidate, "", true, true), rotate)
	_writing = false
	if error == OK:
		return _resolve(candidate, _proof, "committed")
	return recover(_request.operation_id, AtomicRequest.hash_value(_request))


func recover(operation_id: String, request_hash: String) -> Dictionary:
	if _notifying or _writing:
		return _result(ERR_BUSY, "pending")
	if not AtomicRequest.valid_hash(request_hash):
		return _result(ERR_INVALID_PARAMETER, "rejected")
	if _lease == null:
		return _recover_resolved(operation_id, request_hash)
	if operation_id != _request.operation_id or request_hash != AtomicRequest.hash_value(_request):
		return _result(ERR_BUSY, "pending")
	if not _started:
		return _result(ERR_BUSY, "pending")
	return _recover_started(operation_id)


func _recover_resolved(operation_id: String, request_hash: String) -> Dictionary:
	if _committed.is_empty():
		return _result(ERR_UNCONFIGURED, "unavailable")
	if _committed.schema_version != SaveSchema.VERSION:
		return _result(ERR_UNAVAILABLE, "unavailable")
	if _owner_pending():
		return _result(ERR_BUSY, "pending")
	return _replay(_lookup(operation_id), request_hash)


func _recover_started(operation_id: String) -> Dictionary:
	var selected: Dictionary = _selected()
	if selected.is_empty():
		return _result(ERR_UNAVAILABLE, "pending")
	var document: Dictionary = selected.document
	var proof: Dictionary = {}
	if document.schema_version == SaveSchema.VERSION:
		proof = document.meta.atomic.processed.get(_key(operation_id), {})
	if not proof.is_empty() and _same(proof, _proof):
		if document.meta.atomic.revision == _proof.revision and not _same(document, _candidate):
			return _replacement(selected)
		if selected.suffix == ".tmp" and _storage.promote_temp() != OK:
			return _result(ERR_UNAVAILABLE, "pending")
		return _resolve(document, proof, "replayed")
	if _same(document, _baseline):
		return _result(ERR_BUSY, "pending")
	return _replacement(selected)


func abort(transaction: SaveTransaction) -> Error:
	if not validates(transaction):
		return ERR_INVALID_PARAMETER
	if _started:
		return ERR_BUSY
	_clear()
	return OK


func validates_receipt(receipt: Dictionary) -> bool:
	if _committed.is_empty() or _committed.schema_version != SaveSchema.VERSION:
		return false
	var operation_id: String = str(receipt.get("operation_id", ""))
	return (
		_issued.has(operation_id)
		and _same(receipt, _issued[operation_id])
		and _same(receipt, _lookup(operation_id))
	)


func _assemble(
	transaction: SaveTransaction, progress: ProgressPrepared, economy: EconomyPrepared
) -> Dictionary:
	var p: Dictionary = _progress.prepared_payload(progress, transaction)
	var e: Dictionary = _economy.prepared_payload(economy, transaction)
	var result: Dictionary = _candidate_sections(p, e)
	if result.is_empty():
		return {}
	var state: Dictionary = result.progress.get("by_lang", {}).get(_request.language, {})
	var slot: int = _request.context.slot
	if (
		slot >= ProgressSnapshot.MAX_SAFE_COUNT
		or _domain(state) != _request.progress_candidate
		or state.get("current_slot") != slot + 1
		or state.get("highest_completed_slot") != slot
	):
		return {}
	var old_languages: Dictionary = _baseline.progress.by_lang
	for language: String in old_languages:
		if (
			language != _request.language
			and result.progress.by_lang.get(language) != old_languages[language]
		):
			return {}
	var atomic: Dictionary = result.meta.atomic
	if atomic.revision >= ProgressSnapshot.MAX_SAFE_COUNT:
		return {}
	atomic.revision += 1
	var receipt: Dictionary = {
		"operation_id": _request.operation_id,
		"request_hash": AtomicRequest.hash_value(_request),
		"lineage": atomic.lineage,
		"revision": atomic.revision,
		"language": _request.language,
		"slot": slot,
		"context_hash": AtomicRequest.hash_value(_request.context),
		"committed_snapshot": _request.progress_candidate.duplicate(true),
		"delta": p.delta.duplicate(true),
		"economy_snapshot": e.section.duplicate(true),
		"notifications": e.notifications.duplicate(true)
	}
	atomic.processed[_key(_request.operation_id)] = receipt
	return SaveSchema.canonical(result) if SaveSchema.is_valid(result) else {}


func _approved(
	transaction: SaveTransaction, progress: ProgressPrepared, economy: EconomyPrepared
) -> bool:
	return (
		validates_progress(progress, transaction)
		and economy != null
		and economy.error == OK
		and is_instance_valid(_economy)
		and _economy.validates_prepared(economy, transaction)
		and _economy.approved_progress(economy, transaction) == progress
		and _progress.atomic_context_valid(transaction)
		and _economy.atomic_context_valid(transaction)
	)


func _resolve(document: Dictionary, proof: Dictionary, state: String) -> Dictionary:
	_committed = document.duplicate(true)
	_issued[proof.operation_id] = proof.duplicate(true)
	_clear()
	_notifying = true
	_publish.call(document.duplicate(true), "")
	_publish_receipt_owners(proof)
	_notifying = false
	return _result(OK, state, proof)


func _replacement(selected: Dictionary) -> Dictionary:
	_committed = selected.document.duplicate(true)
	_issued.clear()
	_clear()
	_notifying = true
	_publish.call(_committed.duplicate(true), selected.suffix)
	_notifying = false
	return _result(ERR_BUSY, "rejected")


func _replay(proof: Dictionary, request_hash: String) -> Dictionary:
	if proof.is_empty() or proof.request_hash != request_hash:
		return _result(ERR_INVALID_DATA, "rejected")
	_issued[proof.operation_id] = proof.duplicate(true)
	return _result(OK, "replayed", proof)


func _selected() -> Dictionary:
	for suffix: String in ["", ".tmp", ".bak"]:
		var source: Dictionary = _storage.read_document(suffix)
		var document: Dictionary = SaveMigrations.new().upgrade(source)
		if SaveSchema.is_valid(document):
			return {"document": SaveSchema.canonical(document), "suffix": suffix}
		var legacy: Dictionary = _legacy_candidate(source)
		if not legacy.is_empty():
			return {"document": legacy, "suffix": suffix}
	return {}


func _lookup(operation_id: String) -> Dictionary:
	return _committed.meta.atomic.processed.get(_key(operation_id), {}).duplicate(true)


func _key(operation_id: String) -> String:
	return "%d:%s" % [_committed.meta.atomic.lineage, operation_id]


func _baseline_view() -> Dictionary:
	return _view.duplicate(true) if _lease != null else {}


func _owner_pending() -> bool:
	return (
		(is_instance_valid(_progress) and _progress.atomic_has_pending())
		or (is_instance_valid(_economy) and _economy.atomic_has_pending())
	)


func _available() -> bool:
	return (
		not _committed.is_empty()
		and _committed.schema_version == SaveSchema.VERSION
		and is_instance_valid(_progress)
		and is_instance_valid(_economy)
		and _progress.atomic_available()
		and _economy.atomic_available()
	)


func _clear() -> void:
	_lease = null
	_request = {}
	_baseline = {}
	_view = {}
	_candidate = {}
	_proof = {}
	_progress_approval = null
	_economy_approval = null
	_started = false


func _result(error: Error, state: String, receipt: Dictionary = {}) -> Dictionary:
	return {
		"error": error,
		"state": state,
		"transaction": null,
		"view": view(),
		"receipt": receipt.duplicate(true)
	}


static func _concrete(owner: AtomicSaveOwner, path: String) -> bool:
	if not is_instance_valid(owner):
		return false
	var script: Script = owner.get_script()
	while script != null:
		if script.resource_path == path:
			return true
		script = script.get_base_script()
	return false


static func _same(left: Dictionary, right: Dictionary) -> bool:
	# Validated documents may contain parsed floats for nested integer snapshots/extensions.
	# Normalize comparison through JSON only; never normalize or coerce original requests.
	return (
		JSON.parse_string(JSON.stringify(left, "", true, true))
		== JSON.parse_string(JSON.stringify(right, "", true, true))
	)


static func _domain(state: Dictionary) -> Dictionary:
	var source: Dictionary = SaveSchema.LANGUAGE_STATE if state.is_empty() else state
	return {
		"current_slot": source.get("current_slot", 1),
		"stars": source.get("stars", 0),
		"location_stars": source.get("location_stars", {}).duplicate(true),
		"location_pieces": source.get("location_pieces", {}).duplicate(true),
		"completed_locations": source.get("postcards", []).duplicate(true),
		"unlocked": source.get("unlocked", []).duplicate(true)
	}


func _payloads_valid(progress: Dictionary, economy: Dictionary) -> bool:
	for payload: Dictionary in [progress, economy]:
		if not AtomicRequest.closed(payload, ["section", "delta", "notifications"]):
			return false
		if not payload.section is Dictionary or not payload.delta is Dictionary:
			return false
		if not payload.notifications is Array:
			return false
	return (
		progress.notifications.is_empty()
		and economy.delta.is_empty()
		and progress.delta == _request.delta
	)


func _candidate_sections(progress: Dictionary, economy: Dictionary) -> Dictionary:
	if not _payloads_valid(progress, economy):
		return {}
	var result: Dictionary = _baseline.duplicate(true)
	result.progress = progress.section.duplicate(true)
	result.economy = economy.section.duplicate(true)
	return SaveSchema.canonical(result) if SaveSchema.is_valid(result) else {}


static func _legacy_candidate(source: Dictionary) -> Dictionary:
	var legacy: Dictionary = source.duplicate(true)
	if legacy.get("schema_version") == 1:
		legacy = MigrateV1ToV2.migrate(legacy)
	if legacy.get("schema_version") == 2:
		legacy = MigrateV2ToV3.migrate(legacy)
	return SaveSchemaV3.canonical(legacy) if SaveSchemaV3.is_valid(legacy) else {}


func _commit_validation(
	transaction: SaveTransaction, progress: ProgressPrepared, economy: EconomyPrepared
) -> Dictionary:
	if not validates(transaction):
		return _result(ERR_INVALID_PARAMETER, "rejected")
	if _started and (progress != _progress_approval or economy != _economy_approval):
		return _result(ERR_BUSY, "pending")
	if not _approved(transaction, progress, economy):
		return _result(ERR_INVALID_DATA, "pending" if _started else "rejected")
	return {}


func receipt_publishing() -> bool:
	return _notifying and not _writing and _lease == null


func publish_receipt(receipt: Dictionary) -> Error:
	if blocked() or _writing:
		return ERR_BUSY
	if not validates_receipt(receipt):
		return ERR_INVALID_DATA
	if not is_instance_valid(_economy):
		return ERR_UNCONFIGURED
	_notifying = true
	var error: Error = _publish_receipt_owners(receipt)
	_notifying = false
	return error


func _publish_receipt_owners(receipt: Dictionary) -> Error:
	var error: Error = ERR_UNCONFIGURED
	if is_instance_valid(_economy):
		error = _economy.accept_commit(receipt.duplicate(true))
	if is_instance_valid(_progress):
		_progress.call("_accept_coordinated_commit", receipt.duplicate(true))
	return error
