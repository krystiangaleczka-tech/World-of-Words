# gdlint: disable=max-public-methods
# Keep this transaction fault matrix and its isolated owner fixtures together.
extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")
const ECONOMY_SCRIPT: Script = preload("res://services/economy.gd")
const PATH: String = "user://t0332-atomic.json"
const ID: String = "12345678-1234-4234-8234-123456789abc"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class InterruptedStorage:
	extends SaveStorage

	var stop_at: StringName = &""
	var invisible: bool = false
	var promotion_error: bool = false
	var callback: Callable

	func checkpoint(step: StringName) -> Error:
		if callback.is_valid():
			callback.call(step)
		return ERR_BUSY if step == stop_at else OK

	func read_document(suffix: String = "") -> Dictionary:
		return {} if invisible else super.read_document(suffix)

	func promote_temp() -> Error:
		return ERR_CANT_CREATE if promotion_error else super.promote_temp()


class TestProgress:
	extends "res://services/progress.gd"

	var save: Node
	var context_valid: bool = true
	var pending: bool = false
	var payload_override: Dictionary = {}
	var _records: Dictionary = {}

	func atomic_available() -> bool:
		return true

	func atomic_has_pending() -> bool:
		return pending

	func atomic_context_valid(transaction: SaveTransaction) -> bool:
		return context_valid and save.validates_transaction(transaction)

	func issue(transaction: SaveTransaction) -> ProgressPrepared:
		var value: ProgressPrepared = ProgressPrepared.new()
		if not save.validates_transaction(transaction):
			return value
		var request: Dictionary = transaction.request()
		var section: Dictionary = transaction.committed_view().sections.progress
		var state: Dictionary = section.by_lang[request.language]
		state.current_slot = request.context.slot + 1
		state.highest_completed_slot = request.context.slot
		state.completed_slot = request.context.slot
		state.stars = request.progress_candidate.stars
		state.level_state = null
		_records[value] = {"transaction": transaction, "section": section, "delta": request.delta}
		value.error = OK
		return value

	func validates_prepared(value: RefCounted, transaction: SaveTransaction) -> bool:
		return (
			_records.has(value)
			and _records[value].transaction == transaction
			and save.validates_transaction(transaction)
		)

	func prepared_payload(value: RefCounted, transaction: SaveTransaction) -> Dictionary:
		if not validates_prepared(value, transaction):
			return {}
		if not payload_override.is_empty():
			return payload_override.duplicate(true)
		return {
			"section": _records[value].section.duplicate(true),
			"delta": _records[value].delta.duplicate(true),
			"notifications": []
		}


class TestEconomy:
	extends "res://services/economy.gd"

	var save: Node
	var pending: bool = false
	var context_valid: bool = true
	var callback: Callable
	var publications: int = 0
	var lose_notification: bool = false
	var payload_override: Dictionary = {}
	var _records: Dictionary = {}
	var _published: Dictionary = {}

	func atomic_available() -> bool:
		return true

	func atomic_has_pending() -> bool:
		return pending

	func atomic_context_valid(transaction: SaveTransaction) -> bool:
		return context_valid and save.validates_transaction(transaction)

	func issue(transaction: SaveTransaction, progress: ProgressPrepared) -> EconomyPrepared:
		var value: EconomyPrepared = EconomyPrepared.new()
		if not save.validates_progress(progress, transaction):
			return value
		var section: Dictionary = transaction.committed_view().sections.economy
		section.coins += 1
		section.journal.append({"operation": "grant", "amount": 1})
		_records[value] = {"transaction": transaction, "progress": progress, "section": section}
		value.error = OK
		return value

	func validates_prepared(value: RefCounted, transaction: SaveTransaction) -> bool:
		return (
			_records.has(value)
			and _records[value].transaction == transaction
			and save.validates_transaction(transaction)
		)

	func approved_progress(
		value: EconomyPrepared, transaction: SaveTransaction
	) -> ProgressPrepared:
		return _records[value].progress if validates_prepared(value, transaction) else null

	func prepared_payload(value: RefCounted, transaction: SaveTransaction) -> Dictionary:
		if not validates_prepared(value, transaction):
			return {}
		if not payload_override.is_empty():
			return payload_override.duplicate(true)
		return {
			"section": _records[value].section.duplicate(true),
			"delta": {},
			"notifications": [{"operation": "grant"}]
		}

	func accept_commit(receipt: Dictionary) -> Error:
		if lose_notification:
			return ERR_UNAVAILABLE
		if not save.validates_receipt(receipt):
			return ERR_INVALID_DATA
		var key: String = "%d:%s" % [receipt.lineage, receipt.operation_id]
		if not _published.has(key):
			_published[key] = true
			publications += 1
			if callback.is_valid():
				callback.call()
		return OK


var _save: SAVE_SCRIPT
var _progress: TestProgress
var _economy: TestEconomy
var _storage: InterruptedStorage


func before_each() -> void:
	_clean()
	_storage = InterruptedStorage.new(PATH)
	_save = _service(_storage)
	_progress = TestProgress.new()
	_economy = TestEconomy.new()
	add_child_autofree(_progress)
	add_child_autofree(_economy)
	_progress.save = _save
	_economy.save = _save
	_progress.configure(_save, null)
	_economy.configure(_save, null, null)
	assert_eq(_save.configure_atomic(_progress, _economy), OK)
	assert_eq(_save.load(), OK)


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func _service(storage: SaveStorage) -> SAVE_SCRIPT:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(FixedClock.new())
	save.configure(storage, func() -> String: return ID)
	return save


func _request() -> Dictionary:
	var state: Dictionary = _save.get_section(&"progress").by_lang.pl
	var domain: Dictionary = {
		"current_slot": state.current_slot,
		"stars": state.stars,
		"location_stars": state.location_stars,
		"location_pieces": state.location_pieces,
		"completed_locations": state.postcards,
		"unlocked": state.unlocked
	}
	var candidate: Dictionary = domain.duplicate(true)
	candidate.current_slot += 1
	candidate.stars += 1
	return {
		"operation_id": "campaign_complete:pl:%d" % state.current_slot,
		"kind": "campaign_complete",
		"language": "pl",
		"context":
		{
			"content_version": 1,
			"manifest_hash": "a".repeat(64),
			"level_id": "pl-test",
			"slot": state.current_slot,
			"expected_current_slot": state.current_slot,
			"expected_highest_completed_slot": state.highest_completed_slot,
			"board_hash": "b".repeat(64),
			"expected_progress_hash": AtomicRequest.hash_value(domain)
		},
		"progress_candidate": candidate,
		"economy_commands":
		[{"operation": "grant", "reason": "level_complete", "amounts": {"coins": 1}}],
		"delta": {"stars": 1}
	}


func _prepare(request: Dictionary = {}) -> Dictionary:
	var actual: Dictionary = _request() if request.is_empty() else request
	var result: Dictionary = _save.begin_transaction(actual)
	assert_eq(result.error, OK)
	var transaction: SaveTransaction = result.transaction
	var progress: ProgressPrepared = _progress.issue(transaction)
	var economy: EconomyPrepared = _economy.issue(transaction, progress)
	return {"transaction": transaction, "progress": progress, "economy": economy, "request": actual}


func _commit(prepared: Dictionary) -> Dictionary:
	return _save.commit_transaction(prepared.transaction, prepared.progress, prepared.economy)


func _recover(prepared: Dictionary) -> Dictionary:
	return _save.recover_transaction(
		prepared.request.operation_id, AtomicRequest.hash_value(prepared.request)
	)


func test_closed_request_and_immutable_handle_copies() -> void:
	var request: Dictionary = _request()
	assert_true(AtomicRequest.valid(request))
	var reversed: Dictionary = {}
	var keys: Array = request.keys()
	keys.reverse()
	for key: String in keys:
		reversed[key] = request[key]
	assert_eq(AtomicRequest.hash_value(request), AtomicRequest.hash_value(reversed))
	for field: String in request:
		var missing: Dictionary = request.duplicate(true)
		missing.erase(field)
		assert_false(AtomicRequest.valid(missing))
	var invalid: Dictionary = request.duplicate(true)
	invalid.context.slot = 1.0
	assert_eq(_save.begin_transaction(invalid).error, ERR_INVALID_PARAMETER)
	invalid = request.duplicate(true)
	invalid.extra = true
	assert_false(AtomicRequest.valid(invalid))
	var prepared: Dictionary = _prepare(request)
	request.economy_commands[0].amounts.coins = 999
	prepared.transaction.request().economy_commands.clear()
	prepared.transaction.committed_view().sections.economy.coins = 999
	assert_true(_save.validates_transaction(prepared.transaction))
	assert_eq(_commit(prepared).error, OK)
	assert_eq(_save.get_section(&"economy").coins, 1)


func test_direct_save_forged_or_wrong_owner_handles() -> void:
	var prepared: Dictionary = _prepare()
	assert_eq(
		_save.commit_transaction(SaveTransaction.new(), prepared.progress, prepared.economy).error,
		ERR_INVALID_PARAMETER
	)
	var forged: ProgressPrepared = ProgressPrepared.new()
	forged.error = OK
	assert_eq(
		_save.commit_transaction(prepared.transaction, forged, prepared.economy).error,
		ERR_INVALID_DATA
	)
	var wallet: EconomyPrepared = EconomyPrepared.new()
	wallet.error = OK
	assert_eq(
		_save.commit_transaction(prepared.transaction, prepared.progress, wallet).error,
		ERR_INVALID_DATA
	)
	var other: TestProgress = TestProgress.new()
	add_child_autofree(other)
	other.save = _save
	assert_eq(
		(
			_save
			. commit_transaction(
				prepared.transaction, other.issue(prepared.transaction), prepared.economy
			)
			. error
		),
		ERR_INVALID_DATA
	)
	var second: ProgressPrepared = _progress.issue(prepared.transaction)
	assert_eq(
		_save.commit_transaction(prepared.transaction, second, prepared.economy).error,
		ERR_INVALID_DATA
	)
	assert_eq(_save.get_section(&"economy").coins, 0)
	assert_eq(_commit(prepared).error, OK)
	assert_false(_save.validates_transaction(prepared.transaction))


func test_joint_candidate_owner_validation_and_stale_context() -> void:
	var prepared: Dictionary = _prepare()
	_progress.context_valid = false
	assert_eq(_commit(prepared).error, ERR_INVALID_DATA)
	_progress.context_valid = true
	_progress.payload_override = _progress.prepared_payload(prepared.progress, prepared.transaction)
	_progress.payload_override.delta = {"stars": 999}
	assert_eq(_commit(prepared).error, ERR_INVALID_DATA)
	_progress.payload_override.clear()
	_economy.context_valid = false
	assert_eq(_commit(prepared).error, ERR_INVALID_DATA)
	_economy.context_valid = true
	prepared.transaction._request.economy_commands.clear()
	assert_false(_save.validates_transaction(prepared.transaction))
	assert_eq(_commit(prepared).error, ERR_INVALID_PARAMETER)
	assert_eq(_save.get_section(&"economy").coins, 0)


func test_competing_dirty_pending_and_reentrant_writers() -> void:
	var request: Dictionary = _request()
	var economy: Dictionary = _save.get_section(&"economy")
	economy.coins = 4
	assert_eq(_save.set_section(&"economy", economy), OK)
	assert_eq(_save.committed_view().sections.economy.coins, 0)
	assert_eq(_save.begin_transaction(request).error, ERR_BUSY)
	assert_eq(_save.flush(), OK)
	_economy.pending = true
	assert_eq(_save.begin_transaction(request).error, ERR_BUSY)
	_economy.pending = false
	var prepared: Dictionary = _prepare()
	var before: Dictionary = _save.committed_view()
	_assert_writers_busy()
	assert_eq_deep(_save.committed_view(), before)
	_economy.callback = func() -> void:
		assert_false(_save.validates_transaction(prepared.transaction))
		assert_eq(_save.get_section(&"economy").coins, 5)
		assert_eq(_save.get_section(&"progress").by_lang.pl.current_slot, 2)
		_assert_writers_busy()
	assert_eq(_commit(prepared).error, OK)
	assert_eq(_economy.publications, 1)
	assert_eq(_recover(prepared).state, "replayed")
	assert_eq(_economy.publications, 1)


func _assert_writers_busy() -> void:
	assert_eq(_save.set_section(&"economy", _save.get_section(&"economy")), ERR_BUSY)
	assert_eq(_save.set_setting(&"language", "en"), ERR_BUSY)
	assert_eq(_save.flush(), ERR_BUSY)
	assert_eq(_save.debug_reset(), ERR_BUSY)
	assert_eq(_save.begin_transaction(_request()).error, ERR_BUSY)
	# These production methods reject at the barrier even without P1 dependencies configured.
	assert_eq(_progress.complete_level(1), ERR_BUSY)
	assert_eq(_progress.save_level(null), ERR_BUSY)
	assert_eq(_economy.grant(&"level_complete", {"coins": 1}), ERR_BUSY)
	assert_false(_economy.spend(&"hint", {"coins": 1}))
	_save.notification(Node.NOTIFICATION_APPLICATION_PAUSED)


func test_each_storage_checkpoint_restart_old_or_one() -> void:
	for checkpoint: StringName in [
		&"temp_opened", &"temp_written", &"temp_flushed", &"backup_rotated", &"primary_promoted"
	]:
		_clean()
		var baseline: Dictionary = SaveSchema.fresh(ID, "2026-10-02T12:00:00Z", "0.1.0")
		var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(baseline))
		file.close()
		_save = _service(_storage)
		_progress.save = _save
		_economy.save = _save
		_progress.configure(_save, null)
		_economy.configure(_save, null, null)
		assert_eq(_save.configure_atomic(_progress, _economy), OK)
		assert_eq(_save.load(), OK)
		var prepared: Dictionary = _prepare()
		_storage.stop_at = checkpoint
		var result: Dictionary = _commit(prepared)
		var committed: bool = checkpoint in [&"backup_rotated", &"primary_promoted"]
		assert_eq(result.error, OK if committed else ERR_BUSY, str(checkpoint))
		var restart: SAVE_SCRIPT = _service(SaveStorage.new(PATH))
		assert_eq(restart.load(), OK)
		assert_eq(restart.get_section(&"economy").coins, 1 if committed else 0)
		assert_eq(restart.get_section(&"progress").by_lang.pl.current_slot, 2 if committed else 1)
		assert_eq(restart.get_section(&"meta").atomic.processed.size(), 1 if committed else 0)
		_storage.stop_at = &""
		if not committed:
			assert_eq(_save.abort_transaction(prepared.transaction), ERR_BUSY)
			assert_eq(_recover(prepared).state, "pending")
			assert_eq(_commit(prepared).error, OK)
		assert_eq(_save.get_section(&"economy").coins, 1)
		assert_eq(_save.get_section(&"meta").atomic.revision, 1)


func test_error_after_promotion_replays_without_grant() -> void:
	var prepared: Dictionary = _prepare()
	_storage.stop_at = &"primary_promoted"
	assert_eq(_commit(prepared).state, "replayed")
	assert_eq(_economy.publications, 1)
	assert_eq(_save.begin_transaction(prepared.request).state, "replayed")
	assert_eq(_recover(prepared).state, "replayed")
	assert_eq(_save.get_section(&"economy").coins, 1)
	assert_eq(_economy.publications, 1)


func test_unknown_reads_keep_pending_and_temp_promotion_must_succeed() -> void:
	var prepared: Dictionary = _prepare()
	_storage.stop_at = &"temp_flushed"
	assert_eq(_commit(prepared).state, "pending")
	_storage.invisible = true
	assert_eq(_recover(prepared).error, ERR_UNAVAILABLE)
	assert_true(_save.writes_blocked())
	assert_eq(_save.get_section(&"economy").coins, 0)
	_storage.invisible = false
	_storage.stop_at = &"backup_rotated"
	_storage.promotion_error = true
	assert_eq(_commit(prepared).error, ERR_UNAVAILABLE)
	assert_eq(_save.get_section(&"economy").coins, 0)
	assert_eq(_economy.publications, 0)
	_storage.promotion_error = false
	assert_eq(_recover(prepared).state, "replayed")
	assert_eq(_save.get_section(&"economy").coins, 1)


func test_contradictory_valid_replacement_never_overwritten() -> void:
	var prepared: Dictionary = _prepare()
	_storage.stop_at = &"temp_flushed"
	assert_eq(_commit(prepared).state, "pending")
	var replacement: Dictionary = SaveSchema.canonical(_storage.read_document())
	replacement.economy.coins = 100
	replacement.meta.atomic.revision += 1
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(replacement))
	file.close()
	assert_eq(_recover(prepared).error, ERR_BUSY)
	assert_eq(_save.get_section(&"economy").coins, 100)
	assert_false(_save.writes_blocked())
	assert_false(_save.validates_transaction(prepared.transaction))
	assert_eq(_storage.read_document().economy.coins, 100)


func test_processed_proof_survives_journal_trim_and_old_receipt_keeps_current_view() -> void:
	var first: Dictionary = _prepare()
	var receipt: Dictionary = _commit(first).receipt
	var second: Dictionary = _prepare()
	assert_eq(_commit(second).error, OK)
	var economy: Dictionary = _save.get_section(&"economy")
	economy.journal.clear()
	assert_eq(_save.set_section(&"economy", economy), OK)
	assert_eq(_save.flush(), OK)
	var result: Dictionary = _save.begin_transaction(first.request)
	assert_eq(result.state, "replayed")
	assert_eq_deep(
		JSON.parse_string(JSON.stringify(result.receipt)),
		JSON.parse_string(JSON.stringify(receipt))
	)
	assert_eq(result.view.sections.progress.by_lang.pl.current_slot, 3)
	assert_eq(result.view.sections.economy.coins, 2)
	assert_eq(_save.get_section(&"meta").atomic.processed.size(), 2)
	var changed: Dictionary = first.request.duplicate(true)
	changed.economy_commands[0].amounts.coins = 2
	assert_eq(_save.begin_transaction(changed).error, ERR_INVALID_DATA)


func test_historical_completed_slot_without_proof_never_regrants_and_wrong_context() -> void:
	var request: Dictionary = _request()
	var progress: Dictionary = _save.get_section(&"progress")
	progress.by_lang.pl.current_slot = 2
	progress.by_lang.pl.highest_completed_slot = 1
	assert_eq(_save.set_section(&"progress", progress), OK)
	assert_eq(_save.flush(), OK)
	assert_eq(_save.begin_transaction(request).error, ERR_INVALID_DATA)
	request = _request()
	request.context.expected_progress_hash = "c".repeat(64)
	assert_eq(_save.begin_transaction(request).error, ERR_INVALID_DATA)
	request = _request()
	request.language = "en"
	request.operation_id = "campaign_complete:en:2"
	assert_eq(_save.begin_transaction(request).error, ERR_INVALID_DATA)
	assert_eq(_save.get_section(&"economy").coins, 0)


func test_reset_lineage_invalidates_receipts_and_abort_only_before_write() -> void:
	var prepared: Dictionary = _prepare()
	assert_eq(_save.abort_transaction(prepared.transaction), OK)
	assert_false(_save.validates_transaction(prepared.transaction))
	prepared = _prepare()
	var receipt: Dictionary = _commit(prepared).receipt
	assert_true(_save.validates_receipt(receipt))
	var revision: int = _save.committed_view().revision
	assert_eq(_save.debug_reset(), OK)
	assert_eq(_save.committed_view().lineage, 1)
	assert_eq(_save.committed_view().revision, revision + 1)
	assert_false(_save.validates_receipt(receipt))
	assert_eq(_recover(prepared).error, ERR_INVALID_DATA)
	assert_eq(_save.get_section(&"meta").atomic.processed, {})
	assert_eq(_commit(_prepare()).error, OK)
	assert_eq(_save.get_section(&"economy").coins, 1)


func test_production_unavailable_and_boot_binding_rejects_generic_owner() -> void:
	var service: SAVE_SCRIPT = _service(SaveStorage.new(PATH))
	var generic: AtomicSaveOwner = AtomicSaveOwner.new()
	add_child_autofree(generic)
	assert_eq(service.configure_atomic(generic, _economy), ERR_INVALID_PARAMETER)
	var progress: PROGRESS_SCRIPT = PROGRESS_SCRIPT.new()
	var economy: ECONOMY_SCRIPT = ECONOMY_SCRIPT.new()
	add_child_autofree(progress)
	add_child_autofree(economy)
	assert_eq(service.configure_atomic(progress, economy), OK)
	assert_eq(service.load(), OK)
	assert_eq(service.begin_transaction(_request()).error, ERR_UNAVAILABLE)
	assert_eq(service.configure_atomic(_progress, _economy), ERR_ALREADY_IN_USE)
	assert_false(progress.p2_ready())


func test_restart_rebuilds_view_without_reapplying_notifications() -> void:
	_economy.lose_notification = true
	var prepared: Dictionary = _prepare()
	var receipt: Dictionary = _commit(prepared).receipt
	var restarted: SAVE_SCRIPT = _service(SaveStorage.new(PATH))
	assert_eq(restarted.load(), OK)
	var result: Dictionary = restarted.recover_transaction(
		receipt.operation_id, receipt.request_hash
	)
	assert_eq(result.state, "replayed")
	assert_eq(result.view.sections.economy.coins, 1)
	assert_eq(result.view.sections.progress.by_lang.pl.current_slot, 2)
	assert_true(restarted.validates_receipt(result.receipt))
	assert_eq(_economy.publications, 0)


func _write_document(document: Dictionary, suffix: String = "") -> void:
	var file: FileAccess = FileAccess.open(PATH + suffix, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", true, true))
	file.close()


func _reopen_with_owners(document: Dictionary) -> void:
	_clean()
	_write_document(document)
	_save = _service(_storage)
	_progress.save = _save
	_economy.save = _save
	_progress.configure(_save, null)
	_economy.configure(_save, null, null)
	assert_eq(_save.configure_atomic(_progress, _economy), OK)
	assert_eq(_save.load(), OK)


func test_revision_and_lineage_overflow_leave_memory_and_files_unchanged() -> void:
	# The frozen reader numeric ceiling is MAX_SAFE_COUNT - 1 in this pinned engine.
	# Reject any increment failing full schema validation before touching storage.
	var baseline: Dictionary = SaveSchema.canonical(_storage.read_document())
	baseline.meta.atomic.revision = ProgressSnapshot.MAX_SAFE_COUNT - 1
	_reopen_with_owners(baseline)
	var prepared: Dictionary = _prepare()
	assert_eq(_commit(prepared).error, ERR_INVALID_DATA)
	assert_eq(_save.abort_transaction(prepared.transaction), OK)
	assert_eq(_save.set_setting(&"haptics_enabled", false), ERR_INVALID_DATA)
	assert_eq(_save.debug_reset(), ERR_INVALID_DATA)
	assert_eq(_save.committed_view().revision, ProgressSnapshot.MAX_SAFE_COUNT - 1)
	assert_eq(
		_storage.read_document().meta.atomic.revision, float(ProgressSnapshot.MAX_SAFE_COUNT - 1)
	)
	baseline.meta.atomic.revision = 0
	baseline.meta.atomic.lineage = ProgressSnapshot.MAX_SAFE_COUNT - 1
	_reopen_with_owners(baseline)
	assert_eq(_save.debug_reset(), ERR_INVALID_DATA)
	assert_eq(_save.get_section(&"meta").atomic.lineage, ProgressSnapshot.MAX_SAFE_COUNT - 1)
	assert_eq(_save.get_section(&"economy").coins, 0)


func test_v3_collision_atomic_apis_unavailable_with_preserved_p1_writes() -> void:
	var legacy: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/save/v3.json")
	)
	legacy.meta.atomic = "legacy-extension"
	_reopen_with_owners(legacy)
	assert_eq(_save.migration_state(), "needs_migration")
	assert_eq(_save.committed_view().error, ERR_UNAVAILABLE)
	assert_eq(_save.begin_transaction({}).error, ERR_UNAVAILABLE)
	assert_eq(
		_save.recover_transaction("campaign_complete:pl:1", "a".repeat(64)).error, ERR_UNAVAILABLE
	)
	assert_eq(_save.set_setting(&"haptics_enabled", false), OK)
	assert_eq(_save.debug_reset(), OK)
	assert_eq(_save.get_section(&"meta").atomic, "legacy-extension")
	assert_eq(_storage.read_document().schema_version, 3.0)


func test_invalid_owner_payload_is_rejected_without_runtime_error_or_io() -> void:
	var prepared: Dictionary = _prepare()
	for section: Dictionary in [{}, {"by_lang": []}, {"by_lang": {"pl": []}}]:
		_progress.payload_override = {
			"section": section, "delta": prepared.request.delta, "notifications": []
		}
		assert_eq(_commit(prepared).error, ERR_INVALID_DATA)
	assert_eq(_save.get_section(&"economy").coins, 0)
	assert_eq(_storage.read_document().economy.coins, 0.0)


func test_retry_from_backup_does_not_rotate_corrupt_primary_over_valid_backup() -> void:
	var prepared: Dictionary = _prepare()
	var baseline: Dictionary = _storage.read_document()
	_storage.stop_at = &"temp_flushed"
	assert_eq(_commit(prepared).state, "pending")
	_write_document(baseline, ".bak")
	_write_document({}, "")
	_write_document({}, ".tmp")
	assert_eq(_recover(prepared).state, "pending")
	_storage.stop_at = &""
	assert_eq(_commit(prepared).error, OK)
	assert_eq_deep(_storage.read_document(".bak"), baseline)
	assert_eq(_save.get_section(&"economy").coins, 1)


func test_replacement_with_v3_collision_retains_original_and_p1_compatibility() -> void:
	var prepared: Dictionary = _prepare()
	_storage.stop_at = &"temp_flushed"
	assert_eq(_commit(prepared).state, "pending")
	var legacy: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/save/v3.json")
	)
	legacy.meta.atomic = "foreign-legacy"
	_write_document(legacy)
	assert_eq(_recover(prepared).error, ERR_BUSY)
	assert_eq(_save.migration_state(), "needs_migration")
	assert_eq(_save.get_section(&"meta").atomic, "foreign-legacy")
	assert_false(_save.validates_transaction(prepared.transaction))
	assert_eq_deep(_storage.read_document(), legacy)


func test_receipt_forgery_and_second_lease_from_another_save_are_rejected() -> void:
	var prepared: Dictionary = _prepare()
	var foreign: SAVE_SCRIPT = _service(SaveStorage.new(PATH))
	assert_eq(foreign.load(), OK)
	assert_false(foreign.validates_transaction(prepared.transaction))
	var receipt: Dictionary = _commit(prepared).receipt
	assert_false(foreign.validates_receipt(receipt))
	var fake: Dictionary = receipt.duplicate(true)
	fake.economy_snapshot.coins = 999
	assert_false(_save.validates_receipt(fake))
	assert_true(_save.validates_receipt(receipt))


func test_strict_request_hash_rejects_float_bool_object_and_full_request_changes() -> void:
	var request: Dictionary = _request()
	for value: Variant in [1.0, true, -1, 9007199254740992, RefCounted.new()]:
		var changed: Dictionary = request.duplicate(true)
		changed.context.slot = value
		assert_false(AtomicRequest.valid(changed))
	for key: String in ["board_hash", "manifest_hash", "level_id"]:
		var changed: Dictionary = request.duplicate(true)
		changed.context[key] = "c".repeat(64) if key != "level_id" else "other-level"
		assert_ne(AtomicRequest.hash_value(changed), AtomicRequest.hash_value(request))
	var changed: Dictionary = request.duplicate(true)
	changed.delta.stars = 2
	assert_ne(AtomicRequest.hash_value(changed), AtomicRequest.hash_value(request))
	changed = request.duplicate(true)
	changed.progress_candidate.stars = 2
	assert_ne(AtomicRequest.hash_value(changed), AtomicRequest.hash_value(request))
	changed = request.duplicate(true)
	changed.delta.stars = -9223372036854775808
	assert_false(AtomicRequest.valid(changed))


func test_abort_and_destroyed_screen_do_not_control_durable_outcome() -> void:
	var prepared: Dictionary = _prepare()
	_progress.unbind_board()
	assert_true(_save.validates_transaction(prepared.transaction))
	_storage.stop_at = &"temp_flushed"
	assert_eq(_commit(prepared).state, "pending")
	assert_eq(_save.abort_transaction(prepared.transaction), ERR_BUSY)
	assert_eq(_save.debug_reset(), ERR_BUSY)
	_storage.stop_at = &""
	assert_eq(_commit(prepared).error, OK)
	assert_eq(_save.get_section(&"economy").coins, 1)


func test_storage_callbacks_cannot_resolve_or_abort_an_in_progress_write() -> void:
	var prepared: Dictionary = _prepare()
	var before: Dictionary = _save.committed_view()
	_storage.callback = func(_step: StringName) -> void:
		assert_eq(_recover(prepared).error, ERR_BUSY)
		assert_eq(_commit(prepared).error, ERR_BUSY)
		assert_eq(_save.abort_transaction(prepared.transaction), ERR_BUSY)
		assert_eq_deep(_save.committed_view(), before)
		_assert_writers_busy()
	assert_eq(_commit(prepared).error, OK)
	assert_eq(_save.get_section(&"economy").coins, 1)
	assert_eq(_economy.publications, 1)


func test_recovery_of_matching_old_proof_publishes_newer_current_document() -> void:
	var prepared: Dictionary = _prepare()
	_storage.stop_at = &"temp_flushed"
	assert_eq(_commit(prepared).state, "pending")
	var later: Dictionary = _storage.read_document(".tmp")
	later.meta.atomic.revision += 1
	later.economy.coins = 9
	later.progress.by_lang.pl.current_slot = 3
	later.progress.by_lang.pl.highest_completed_slot = 2
	_write_document(later)
	var result: Dictionary = _recover(prepared)
	assert_eq(result.state, "replayed")
	assert_eq(result.receipt.economy_snapshot.coins, 1.0)
	assert_eq(result.view.sections.economy.coins, 9)
	assert_eq(result.view.sections.progress.by_lang.pl.current_slot, 3)
	assert_eq(_save.get_section(&"economy").coins, 9)
	assert_eq(_save.committed_view().revision, int(later.meta.atomic.revision))


func test_invalid_wallet_or_notifications_never_reach_storage() -> void:
	var prepared: Dictionary = _prepare()
	var valid: Dictionary = _economy.prepared_payload(prepared.economy, prepared.transaction)
	for invalid: Variant in [-1, 0.5, 9007199254740992]:
		_economy.payload_override = valid.duplicate(true)
		_economy.payload_override.section.coins = invalid
		assert_eq(_commit(prepared).error, ERR_INVALID_DATA)
	_economy.payload_override = valid.duplicate(true)
	_economy.payload_override.notifications = ["not-an-owner-notification"]
	assert_eq(_commit(prepared).error, ERR_INVALID_DATA)
	assert_eq(_storage.read_document().economy.coins, 0.0)
	assert_eq(_save.get_section(&"meta").atomic.processed, {})


func test_historical_replacement_migration_collision_has_priority_over_new_temp() -> void:
	var prepared: Dictionary = _prepare()
	_storage.stop_at = &"temp_flushed"
	assert_eq(_commit(prepared).state, "pending")
	var legacy: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/save/v1.json")
	)
	legacy.meta.atomic = "foreign-v1"
	_write_document(legacy)
	assert_eq(_recover(prepared).error, ERR_BUSY)
	assert_eq(_save.migration_state(), "needs_migration")
	assert_eq(_save.get_section(&"meta").atomic, "foreign-v1")
	assert_eq(_save.get_section(&"economy").coins, 0)
	assert_eq(_economy.publications, 0)
	assert_eq_deep(_storage.read_document(), legacy)
