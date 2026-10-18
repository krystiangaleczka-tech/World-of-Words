extends GutTest

const FIXTURE: Script = preload("res://tests/integration/test_iap_settlement.gd")
const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONFIG: Script = preload("res://services/config.gd")
const EVENTS: Script = preload("res://services/events.gd")
const SERVICE: Script = preload("res://services/monetization.gd")
const PATH: String = "user://t0341-restore.json"
const REMOVE: String = "nc.remove_forced_ads.v1"
const COINS: String = "c.coins_s.v1"
var save: SAVE
var economy: ECONOMY
var config: CONFIG
var events: EVENTS
var service: SERVICE
var store: FIXTURE.InspectStore
var storage: FIXTURE.InterruptedStorage


func before_each() -> void:
	_clean()
	var clock: Clock = FIXTURE.FixedClock.new()
	save = SAVE.new()
	economy = ECONOMY.new()
	config = CONFIG.new()
	events = EVENTS.new()
	service = SERVICE.new()
	for node: Node in [save, economy, config, events, service]:
		add_child(node)
	for node: Node in [save, economy, service]:
		node.initialize(clock)
	storage = FIXTURE.InterruptedStorage.new(PATH)
	save.configure(storage)
	assert_eq(save.load(), OK)
	assert_eq(config.load(), OK)
	economy.configure(save, config, events)
	assert_eq(service.configure(save, config, events, ConsentFake.new(), AdsFake.new(), false), OK)
	store = FIXTURE.InspectStore.new()
	store.save = save
	assert_eq(
		store.set_products(
			[{"id": REMOVE, "restorable": true}, {"id": COINS, "restorable": false}]
		),
		OK
	)
	store.set_outcome(&"purchase", &"success")
	store.set_outcome(&"restore", &"ready")
	store.set_outcome(&"fetch_unfinished", &"ready")
	assert_eq(service.configure_iap(economy, store), OK)


func after_each() -> void:
	for node: Node in [service, economy, save, events, config]:
		node.free()
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _count(method: String) -> int:
	var count: int = 0
	for call: Dictionary in store.calls.entries:
		if call.method == method:
			count += 1
	return count


func _receipt(key: String = "restored") -> StoreTransaction:
	return StoreTransaction.new(key, REMOVE, StoreTransaction.State.PURCHASED, -1, "", true)


func _batch(transaction: StoreTransaction) -> Array[StoreTransaction]:
	return [transaction]


func test_initial_unconfigured_and_copied_snapshots() -> void:
	var empty: SERVICE = SERVICE.new()
	assert_eq(empty.restore_snapshot().state, &"unavailable")
	assert_eq(empty.retry_restore_settlement(), ERR_UNAVAILABLE)
	empty.expire_restore()
	empty.free()
	var snapshot: Dictionary = service.restore_snapshot()
	assert_eq(snapshot, {"state": &"idle", "restored_count": -1, "error": OK, "revision": 0})
	snapshot.state = &"completed"
	assert_eq(service.restore_snapshot().state, &"idle")
	assert_eq(service.retry_restore_settlement(), ERR_UNAVAILABLE)


func test_requested_is_not_success_and_duplicate_or_rebind_is_blocked() -> void:
	store.set_outcome(&"restore", &"manual")
	assert_eq(service.restore_purchases(), OK)
	assert_eq(service.restore_snapshot().state, &"requested")
	assert_eq(service.restore_snapshot().restored_count, -1)
	assert_eq(service.restore_purchases(), ERR_BUSY)
	assert_eq(_count("restore"), 1)
	assert_eq(service.configure_iap(economy, IapFake.new()), ERR_BUSY)
	assert_eq(
		service.configure(save, config, events, ConsentFake.new(), AdsFake.new(), false), ERR_BUSY
	)
	assert_eq(service.restore_snapshot().state, &"requested")


func test_empty_verified_terminal_is_completed_zero() -> void:
	watch_signals(service)
	assert_eq(service.restore_purchases(), OK)
	assert_eq(service.restore_snapshot().state, &"completed")
	assert_eq(service.restore_snapshot().restored_count, 0)
	assert_eq(service.restore_snapshot().error, OK)
	assert_eq(service.restore_snapshot().revision, 2)
	assert_signal_emit_count(service, "restore_changed", 2)


func test_owned_restore_counts_only_nonconsumables_and_preserves_wallet() -> void:
	assert_eq(service.purchase(REMOVE), OK)
	assert_eq(service.purchase(COINS), OK)
	var coins: int = economy.snapshot().coins
	assert_eq(service.restore_purchases(), OK)
	assert_eq(service.restore_snapshot().restored_count, 1)
	assert_eq(economy.snapshot().coins, coins)
	assert_true(save.committed_view().sections.monetization.remove_forced_ads)
	for proof: bool in store.proofs:
		assert_true(proof)


func test_terminal_duplicate_keys_count_once_and_ignore_duplicate_outcomes() -> void:
	store.set_outcome(&"restore", &"manual")
	assert_eq(service.restore_purchases(), OK)
	var transaction: StoreTransaction = _receipt()
	store.transaction_updated.emit(transaction)
	var batch: Array[StoreTransaction] = [transaction, transaction]
	store.restore_completed.emit(batch)
	assert_eq(service.restore_snapshot().restored_count, 1)
	var snapshot: Dictionary = service.restore_snapshot()
	store.restore_completed.emit(batch)
	store.restore_failed.emit(ERR_UNAVAILABLE)
	service.expire_restore()
	assert_eq(service.restore_snapshot(), snapshot)


func test_failed_write_retries_without_new_store_command_or_early_finish() -> void:
	store.set_outcome(&"restore", &"manual")
	assert_eq(service.restore_purchases(), OK)
	storage.stop = &"temp_opened"
	var transaction: StoreTransaction = _receipt()
	store.transaction_updated.emit(transaction)
	store.restore_completed.emit(_batch(transaction))
	assert_eq(service.restore_snapshot().state, &"settling")
	assert_eq(service.restore_snapshot().restored_count, -1)
	assert_eq(_count("finish"), 0)
	assert_ne(service.retry_restore_settlement(), OK)
	assert_ne(service.restore_snapshot().error, OK)
	assert_eq(service.restore_purchases(), ERR_BUSY)
	storage.stop = &""
	assert_eq(service.retry_restore_settlement(), OK)
	assert_eq(service.restore_snapshot().state, &"completed")
	assert_eq(service.restore_snapshot().restored_count, 1)
	assert_eq(_count("restore"), 1)
	assert_eq(_count("fetch_unfinished"), 0)
	assert_eq(_count("finish"), 1)
	assert_eq(store.proofs, [true])


func test_terminal_waits_for_receipt_proof_and_cannot_provider_timeout() -> void:
	store.set_outcome(&"restore", &"manual")
	assert_eq(service.restore_purchases(), OK)
	var transaction: StoreTransaction = _receipt()
	store.restore_completed.emit(_batch(transaction))
	assert_eq(service.restore_snapshot().state, &"settling")
	service.expire_restore()
	store.restore_failed.emit(ERR_UNAVAILABLE)
	assert_eq(service.restore_snapshot().state, &"settling")
	store.transaction_updated.emit(transaction)
	assert_eq(service.restore_snapshot().state, &"completed")
	assert_eq(service.restore_snapshot().restored_count, 1)


func test_timeout_ignores_late_terminal_but_keeps_valid_receipt_grant() -> void:
	store.set_outcome(&"restore", &"manual")
	assert_eq(service.restore_purchases(), OK)
	service.expire_restore()
	assert_eq(service.restore_snapshot().state, &"unknown")
	assert_eq(service.restore_snapshot().error, ERR_TIMEOUT)
	var transaction: StoreTransaction = _receipt()
	store.transaction_updated.emit(transaction)
	store.restore_completed.emit(_batch(transaction))
	assert_true(save.committed_view().sections.monetization.remove_forced_ads)
	assert_eq(service.restore_snapshot().state, &"unknown")
	assert_eq(service.restore_snapshot().restored_count, -1)
	store.set_outcome(&"restore", &"ready")
	assert_eq(service.restore_purchases(), OK)
	assert_eq(service.restore_snapshot().state, &"completed")


func test_unrelated_purchase_error_does_not_report_restore_failure() -> void:
	store.set_outcome(&"restore", &"manual")
	assert_eq(service.restore_purchases(), OK)
	store.set_outcome(&"purchase", &"error")
	assert_eq(service.purchase(COINS), OK)
	assert_eq(service.restore_snapshot().state, &"requested")
	store.restore_failed.emit(OK)
	assert_eq(service.restore_snapshot().state, &"failed")
	assert_eq(service.restore_snapshot().error, ERR_UNAVAILABLE)
	var empty: Array[StoreTransaction] = []
	store.restore_completed.emit(empty)
	assert_eq(service.restore_snapshot().state, &"failed")


func test_fake_restore_error_reports_failure_only_for_restore() -> void:
	store.set_outcome(&"restore", &"error")
	assert_eq(service.restore_purchases(), OK)
	assert_eq(service.restore_snapshot().state, &"failed")
	assert_eq(service.restore_snapshot().error, ERR_UNAVAILABLE)
	assert_eq(service.restore_snapshot().restored_count, -1)


func test_invalid_batches_fail_closed_without_partial_count() -> void:
	store.set_outcome(&"restore", &"manual")
	for invalid: StoreTransaction in [
		null,
		StoreTransaction.new("", REMOVE, StoreTransaction.State.PURCHASED),
		StoreTransaction.new(" bad ", REMOVE, StoreTransaction.State.PURCHASED),
		StoreTransaction.new("coins", COINS, StoreTransaction.State.PURCHASED),
		StoreTransaction.new("pending", REMOVE, StoreTransaction.State.PENDING)
	]:
		assert_eq(service.restore_purchases(), OK)
		var batch: Array[StoreTransaction] = [_receipt("valid"), invalid]
		store.restore_completed.emit(batch)
		assert_eq(service.restore_snapshot().state, &"failed")
		assert_eq(service.restore_snapshot().error, ERR_INVALID_DATA)
		assert_eq(service.restore_snapshot().restored_count, -1)
	assert_eq(_count("finish"), 0)
	assert_false(save.committed_view().sections.monetization.remove_forced_ads)


func test_restore_notifications_guard_reentrant_commands() -> void:
	var errors: Array[Error] = []
	service.restore_changed.connect(
		func() -> void:
			errors.append(service.restore_purchases())
			errors.append(service.retry_restore_settlement())
			errors.append(service.configure_iap(economy, store))
	)
	assert_eq(service.restore_purchases(), OK)
	assert_eq(errors, [ERR_BUSY, ERR_BUSY, ERR_BUSY, ERR_BUSY, ERR_BUSY, ERR_BUSY])
	assert_eq(_count("restore"), 1)


func test_fake_superseded_error_does_not_emit_restore_terminal() -> void:
	var fake: IapFake = IapFake.new()
	fake.set_outcome(&"restore", &"error", false)
	watch_signals(fake)
	var supersede: Callable = func(_reason: String) -> void: fake.set_outcome(&"restore", &"ready")
	fake.purchase_failed.connect(supersede)
	fake.restore()
	var token: int = fake.operation_token()
	assert_true(fake.settle(token))
	assert_signal_emit_count(fake, "purchase_failed", 1)
	assert_signal_not_emitted(fake, "restore_failed")
	assert_false(fake.settle(token))
	fake.purchase_failed.disconnect(supersede)


func test_existing_unfinished_recovery_also_completes_durable_result() -> void:
	store.set_outcome(&"restore", &"manual")
	assert_eq(service.restore_purchases(), OK)
	storage.stop = &"temp_opened"
	var transaction: StoreTransaction = _receipt()
	store.transaction_updated.emit(transaction)
	store.restore_completed.emit(_batch(transaction))
	assert_eq(service.restore_snapshot().state, &"settling")
	storage.stop = &""
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(service.restore_snapshot().state, &"completed")
	assert_eq(service.restore_snapshot().restored_count, 1)
	assert_eq(_count("restore"), 1)
	assert_eq(_count("fetch_unfinished"), 1)


func test_real_operation_timer_wiring_expires_without_waiting() -> void:
	store.set_outcome(&"restore", &"manual")
	assert_eq(service.restore_purchases(), OK)
	var candidates: Array[Timer] = []
	for timer: Timer in service.find_children("*", "Timer", true, false):
		if timer.timeout.is_connected(Callable(timer.get_parent(), "expire_restore")):
			candidates.append(timer)
	assert_eq(candidates.size(), 1)
	if candidates.is_empty():
		return
	var timer: Timer = candidates[0]
	assert_eq(timer.wait_time, AdPresentation.OPERATION_TIMEOUT_SECONDS)
	assert_true(timer.one_shot)
	assert_true(timer.ignore_time_scale)
	assert_eq(timer.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_false(timer.is_stopped())
	timer.timeout.emit()
	assert_true(timer.is_stopped())
	assert_eq(service.restore_snapshot().state, &"unknown")


func test_requested_callback_expiry_never_dispatches_stale_restore() -> void:
	service.restore_changed.connect(
		func() -> void:
			if service.restore_snapshot().state == &"requested":
				service.expire_restore()
	)
	assert_eq(service.restore_purchases(), OK)
	assert_eq(service.restore_snapshot().state, &"unknown")
	assert_eq(_count("restore"), 0)
