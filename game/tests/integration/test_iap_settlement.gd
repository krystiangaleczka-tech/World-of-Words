extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONFIG: Script = preload("res://services/config.gd")
const EVENTS: Script = preload("res://services/events.gd")
const SERVICE: Script = preload("res://services/monetization.gd")
const PATH: String = "user://t0271-iap.json"
const COINS: String = "c.coins_s.v1"
const REMOVE: String = "nc.remove_forced_ads.v1"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1800000000

	func monotonic_msec() -> int:
		return 1000000


class InterruptedStorage:
	extends SaveStorage
	var stop: StringName = &""

	func checkpoint(step: StringName) -> Error:
		return ERR_CANT_CREATE if step == stop else OK


class InspectStore:
	extends IapFake
	var save: Node
	var proofs: Array[bool] = []

	func finish(transaction: StoreTransaction) -> void:
		proofs.append(
			(
				transaction.store_key
				in save.committed_view().sections.monetization.processed_transactions
			)
		)
		super.finish(transaction)


var save: SAVE
var economy: ECONOMY
var config: CONFIG
var events: EVENTS
var service: SERVICE
var store: InspectStore
var storage: InterruptedStorage
var notifications: Array[Dictionary]


func before_each() -> void:
	_clean()
	notifications = []
	store = InspectStore.new()
	assert_eq(
		store.set_products(
			[{"id": COINS, "restorable": false}, {"id": REMOVE, "restorable": true}]
		),
		OK
	)
	store.set_outcome(&"purchase", &"success")
	store.set_outcome(&"fetch_unfinished", &"ready")
	store.set_outcome(&"restore", &"ready")
	_build()


func _build() -> void:
	var clock: FixedClock = FixedClock.new()
	storage = InterruptedStorage.new(PATH)
	save = SAVE.new()
	economy = ECONOMY.new()
	config = CONFIG.new()
	events = EVENTS.new()
	service = SERVICE.new()
	for node: Node in [save, economy, config, events, service]:
		add_child(node)
	save.initialize(clock)
	economy.initialize(clock)
	service.initialize(clock)
	save.configure(storage, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert_eq(save.load(), OK)
	assert_eq(config.load(), OK)
	economy.configure(save, config, events)
	events.economy_changed.connect(
		func(
			_op: StringName, _reason: StringName, amounts: Dictionary, _wallet: Dictionary
		) -> void:
			notifications.append(amounts)
	)
	assert_eq(service.configure(save, config, events, ConsentFake.new(), AdsFake.new(), false), OK)
	store.save = save
	assert_eq(service.configure_iap(economy, store), OK)


func _dispose() -> void:
	for node: Node in [service, economy, save, events, config]:
		if is_instance_valid(node):
			node.free()


func after_each() -> void:
	_dispose()
	_clean()


func _clean() -> void:
	for path: String in [PATH, PATH + ".other"]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


func _count(method: String) -> int:
	var count: int = 0
	for call: Dictionary in store.calls.entries:
		if call.method == method:
			count += 1
	return count


func _processed() -> Array:
	return save.committed_view().sections.monetization.processed_transactions


func test_coin_purchase_flushes_pair_before_finish_and_duplicate_only_finishes() -> void:
	assert_true(store.calls.entries.is_empty(), "Binding performs no startup/provider operations")
	store.set_outcome(&"purchase", &"duplicate")
	assert_eq(service.purchase(COINS), OK)
	var amount: int = config.get_int(&"iap.coins_s.amount")
	assert_eq(economy.snapshot().coins, amount)
	assert_eq(_processed(), ["fake_iap_1"])
	assert_eq(store.proofs, [true, true])
	assert_eq(notifications, [{"coins": amount}])
	assert_eq(economy.journal().size(), 1)
	assert_eq(service.purchase_state(), &"completed")
	assert_eq(save.get_section(&"monetization").last_purchase_slot, 1)
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(_count("finish"), 2)


func test_entitlement_is_permanent_and_restore_never_regrants_consumables() -> void:
	assert_eq(service.purchase(REMOVE), OK)
	assert_true(save.committed_view().sections.monetization.remove_forced_ads)
	assert_eq(service.purchase(COINS), OK)
	var coins: int = economy.snapshot().coins
	assert_eq(service.restore_purchases(), OK)
	assert_eq(economy.snapshot().coins, coins)
	assert_eq(_processed().size(), 2)
	assert_eq(_count("finish"), 3)
	assert_eq(notifications.size(), 1)
	_dispose()
	store.simulate_restart()
	_build()
	assert_eq(service.restore_purchases(), OK)
	assert_true(save.committed_view().sections.monetization.remove_forced_ads)
	assert_eq(economy.snapshot().coins, coins)
	assert_eq(_processed().size(), 2)


func test_pending_deferred_complete_with_same_key_and_cancel_failure_grant_nothing() -> void:
	for outcome: StringName in [&"cancel", &"failed", &"error"]:
		store.set_outcome(&"purchase", outcome)
		assert_eq(service.purchase(COINS), OK)
		assert_eq(economy.snapshot().coins, 0)
	assert_eq(_count("finish"), 0)
	for outcome: StringName in [&"pending", &"deferred"]:
		store.set_outcome(&"purchase", outcome)
		assert_eq(service.purchase(COINS), OK)
		assert_eq(service.purchase_state(), &"pending")
		assert_eq(service.purchase(COINS), ERR_BUSY)
		var key: String = "fake_iap_%d" % (3 if outcome == &"pending" else 4)
		assert_eq(store.set_transaction_state(key, StoreTransaction.State.PURCHASED), OK)
		assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(economy.snapshot().coins, 2 * config.get_int(&"iap.coins_s.amount"))
	assert_eq(_processed().size(), 2)
	assert_eq(_count("finish"), 2)


func test_invalid_updates_and_atomic_stage_rejection_leave_wallet_and_marker_unchanged() -> void:
	assert_eq(service.purchase("unknown"), ERR_INVALID_PARAMETER)
	for transaction: StoreTransaction in [
		null,
		StoreTransaction.new("", COINS, StoreTransaction.State.PURCHASED),
		StoreTransaction.new(" bad ", COINS, StoreTransaction.State.PURCHASED),
		StoreTransaction.new("unknown", "unknown", StoreTransaction.State.PURCHASED)
	]:
		store.transaction_updated.emit(transaction)
	assert_eq(economy.snapshot().coins, 0)
	assert_eq(_count("finish"), 0)
	var wallet: Dictionary = save.get_section(&"economy")
	wallet.coins = 999
	var monetization: Dictionary = save.get_section(&"monetization")
	monetization.processed_transactions = [42]
	assert_eq(save.stage_purchase(wallet, monetization), ERR_INVALID_DATA)
	assert_eq(save.get_section(&"economy").coins, 0)
	assert_true(_processed().is_empty())


func test_failed_flush_hides_wallet_blocks_competing_work_and_retries_once() -> void:
	storage.stop = &"temp_opened"
	assert_eq(service.purchase(COINS), OK)
	assert_eq(service.purchase_state(), &"settling")
	assert_eq(economy.snapshot().coins, 0)
	assert_true(_processed().is_empty())
	assert_eq(_count("finish"), 0)
	assert_true(economy.atomic_has_pending())
	assert_eq(economy.grant(&"other", {"coins": 5}), ERR_BUSY)
	assert_false(economy.spend(&"other", {"coins": 1}))
	assert_eq(service.configure_iap(economy, IapFake.new()), ERR_BUSY)
	storage.stop = &""
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(economy.snapshot().coins, config.get_int(&"iap.coins_s.amount"))
	assert_false(economy.atomic_has_pending())
	assert_eq(notifications.size(), 1)
	assert_eq(_processed(), ["fake_iap_1"])
	assert_eq(_count("purchase"), 1)
	assert_true(store.proofs.all(func(proof: bool) -> bool: return proof))


func test_other_owner_flush_reconciles_pending_purchase_and_notifies_once() -> void:
	storage.stop = &"temp_opened"
	assert_eq(service.purchase(COINS), OK)
	storage.stop = &""
	assert_eq(save.set_setting(&"sfx_volume", 0.25), OK)
	assert_eq(_processed(), ["fake_iap_1"])
	assert_true(economy.atomic_has_pending())
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_false(economy.atomic_has_pending())
	assert_eq(economy.snapshot().coins, config.get_int(&"iap.coins_s.amount"))
	assert_eq(notifications.size(), 1)
	assert_eq(save.get_setting(&"sfx_volume"), 0.25)
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(notifications.size(), 1)


func test_every_storage_checkpoint_restart_recovers_one_wallet_key_pair() -> void:
	for step: StringName in [
		&"temp_opened", &"temp_written", &"temp_flushed", &"backup_rotated", &"primary_promoted"
	]:
		_dispose()
		_clean()
		store.reset()
		store.set_products([{"id": COINS, "restorable": false}])
		store.set_outcome(&"purchase", &"success")
		store.set_outcome(&"fetch_unfinished", &"ready")
		_build()
		storage.stop = step
		assert_eq(service.purchase(COINS), OK)
		assert_eq(_count("finish"), 0, str(step))
		_dispose()
		store.simulate_restart()
		_build()
		var recovered: int = economy.snapshot().coins
		assert_true(recovered in [0, config.get_int(&"iap.coins_s.amount")], str(step))
		assert_eq(_processed().has("fake_iap_1"), recovered > 0, str(step))
		assert_eq(service.process_unfinished_transactions(), OK)
		assert_eq(economy.snapshot().coins, config.get_int(&"iap.coins_s.amount"), str(step))
		assert_eq(_processed(), ["fake_iap_1"], str(step))
		assert_eq(economy.journal().size(), 1, str(step))
		assert_true(store.proofs.all(func(proof: bool) -> bool: return proof))


func test_crash_before_grant_and_after_grant_before_ack_replay_without_duplicate() -> void:
	store.set_outcome(&"purchase", &"success", false)
	assert_eq(service.purchase(COINS), OK)
	var token: int = store.operation_token()
	_dispose()
	assert_true(store.settle(token), "Provider accepted purchase while application was absent")
	store.simulate_restart()
	_build()
	assert_eq(economy.snapshot().coins, 0)
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(economy.snapshot().coins, config.get_int(&"iap.coins_s.amount"))
	store.set_outcome(&"purchase", &"crash_before_finish")
	assert_eq(service.purchase(COINS), OK)
	var expected: int = economy.snapshot().coins
	_dispose()
	store.simulate_restart()
	_build()
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(economy.snapshot().coins, expected)
	assert_eq(_processed().size(), 2)
	assert_eq(economy.journal().size(), 2)


func test_reentrant_notifications_cannot_nest_grant_recovery_or_owner_replacement() -> void:
	var results: Array[int] = []
	events.economy_changed.connect(
		func(
			_op: StringName, _reason: StringName, _amounts: Dictionary, _wallet: Dictionary
		) -> void:
			results.append(service.process_unfinished_transactions())
			results.append(economy.grant(&"nested", {"coins": 1}))
			results.append(service.configure_iap(economy, IapFake.new()))
			store.transaction_updated.emit(
				StoreTransaction.new("fake_iap_1", COINS, StoreTransaction.State.PURCHASED)
			)
	)
	assert_eq(service.purchase(COINS), OK)
	assert_eq(results, [ERR_BUSY, ERR_BUSY, ERR_BUSY])
	assert_eq(economy.snapshot().coins, config.get_int(&"iap.coins_s.amount"))
	assert_eq(_count("finish"), 1)


func test_foreign_owner_during_delivery_defers_and_can_resume_original_profile() -> void:
	var other: SAVE = SAVE.new()
	add_child_autofree(other)
	other.initialize(FixedClock.new())
	other.configure(
		SaveStorage.new(PATH + ".other"),
		func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert_eq(other.load(), OK)
	store.set_outcome(&"purchase", &"success", false)
	assert_eq(service.purchase(COINS), OK)
	economy.configure(other, config, events)
	assert_true(store.settle(store.operation_token()))
	assert_eq(economy.snapshot().coins, 0)
	assert_eq(_count("finish"), 0)
	economy.configure(save, config, events)
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(economy.snapshot().coins, config.get_int(&"iap.coins_s.amount"))


func test_timeout_keeps_product_pending_and_old_adapter_disconnects_after_settlement() -> void:
	store.set_outcome(&"purchase", &"success", false)
	assert_eq(service.purchase(COINS), OK)
	var timer: Timer
	for child: Node in service.get_children():
		if child is IapFlow:
			for candidate: Node in child.get_children():
				if candidate is Timer:
					timer = candidate
	assert_not_null(timer)
	assert_true(timer.one_shot and timer.ignore_time_scale and timer.wait_time > 0)
	timer.timeout.emit()
	assert_eq(service.purchase_state(), &"unknown")
	assert_eq(service.purchase(COINS), ERR_BUSY)
	assert_true(store.settle(store.operation_token()))
	assert_eq(service.purchase_state(), &"completed")
	var replacement: IapFake = IapFake.new()
	assert_eq(service.configure_iap(economy, replacement), OK)
	var coins: int = economy.snapshot().coins
	store.transaction_updated.emit(
		StoreTransaction.new("late", COINS, StoreTransaction.State.PURCHASED)
	)
	assert_eq(economy.snapshot().coins, coins)


func test_conflicting_external_flush_cannot_certify_incomplete_purchase_pair() -> void:
	storage.stop = &"temp_opened"
	assert_eq(service.purchase(COINS), OK)
	var wallet: Dictionary = save.get_section(&"economy")
	wallet.coins = 0
	assert_eq(save.set_section(&"economy", wallet), OK)
	storage.stop = &""
	assert_eq(save.set_setting(&"sfx_volume", 0.25), OK)
	assert_eq(service.process_unfinished_transactions(), ERR_BUSY)
	assert_eq(_count("finish"), 0)
	assert_true(notifications.is_empty())
	assert_true(economy.atomic_has_pending())
	assert_eq(economy.snapshot().coins, 0)


func test_active_purchase_cannot_be_superseded_by_recovery_restore_or_rewarded() -> void:
	store.set_outcome(&"purchase", &"success", false)
	assert_eq(service.purchase(COINS), OK)
	var token: int = store.operation_token()
	assert_eq(service.process_unfinished_transactions(), ERR_BUSY)
	assert_eq(service.restore_purchases(), ERR_BUSY)
	assert_eq(
		service.request_rewarded(&"hint", economy.grant.bind(&"rewarded_hint", {"hint": 1})),
		ERR_BUSY
	)
	assert_eq(store.operation_token(), token)
	assert_true(store.settle(token))
	assert_eq(service.purchase_state(), &"completed")


func test_failed_receipts_queue_and_settle_individually_after_retry() -> void:
	storage.stop = &"temp_opened"
	store.transaction_updated.emit(
		StoreTransaction.new("queue_a", COINS, StoreTransaction.State.PURCHASED)
	)
	store.transaction_updated.emit(
		StoreTransaction.new("queue_b", COINS, StoreTransaction.State.PURCHASED)
	)
	assert_eq(_count("finish"), 0)
	storage.stop = &""
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(economy.snapshot().coins, 2 * config.get_int(&"iap.coins_s.amount"))
	assert_eq(_processed(), ["queue_a", "queue_b"])
	assert_eq(notifications.size(), 2)
	assert_eq(_count("finish"), 2)


func test_late_pending_of_processed_key_cannot_relock_product() -> void:
	assert_eq(service.purchase(COINS), OK)
	store.transaction_updated.emit(
		StoreTransaction.new("fake_iap_1", COINS, StoreTransaction.State.PENDING)
	)
	assert_eq(service.purchase_state(), &"completed")
	assert_eq(service.purchase(COINS), OK)
	assert_eq(economy.snapshot().coins, 2 * config.get_int(&"iap.coins_s.amount"))


func test_cancelling_one_pending_key_does_not_release_another_key_of_same_product() -> void:
	store.transaction_updated.emit(
		StoreTransaction.new("pending_a", COINS, StoreTransaction.State.PENDING)
	)
	store.transaction_updated.emit(
		StoreTransaction.new("pending_b", COINS, StoreTransaction.State.PENDING)
	)
	store.transaction_updated.emit(
		StoreTransaction.new("pending_a", COINS, StoreTransaction.State.CANCELLED)
	)
	assert_eq(service.purchase(COINS), ERR_BUSY)
	store.transaction_updated.emit(
		StoreTransaction.new("pending_b", COINS, StoreTransaction.State.PURCHASED)
	)
	assert_eq(service.purchase(COINS), OK)
	assert_eq(economy.snapshot().coins, 2 * config.get_int(&"iap.coins_s.amount"))


func test_old_purchased_duplicate_does_not_release_new_purchase_command() -> void:
	assert_eq(service.purchase(COINS), OK)
	store.set_outcome(&"purchase", &"success", false)
	assert_eq(service.purchase(COINS), OK)
	var token: int = store.operation_token()
	store.transaction_updated.emit(
		StoreTransaction.new("fake_iap_1", COINS, StoreTransaction.State.PURCHASED)
	)
	assert_eq(service.purchase_state(), &"purchasing")
	assert_eq(service.purchase(COINS), ERR_BUSY)
	assert_eq(service.process_unfinished_transactions(), ERR_BUSY)
	assert_true(store.settle(token))
	assert_eq(service.purchase_state(), &"completed")
	assert_eq(economy.snapshot().coins, 2 * config.get_int(&"iap.coins_s.amount"))


func test_late_pending_cannot_regress_queued_purchase_after_failed_write() -> void:
	storage.stop = &"temp_opened"
	store.transaction_updated.emit(
		StoreTransaction.new("unsolicited", COINS, StoreTransaction.State.PURCHASED)
	)
	store.transaction_updated.emit(
		StoreTransaction.new("unsolicited", COINS, StoreTransaction.State.PENDING)
	)
	assert_eq(service.purchase_state(), &"settling")
	storage.stop = &""
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(service.purchase(COINS), OK)
	assert_eq(economy.snapshot().coins, 2 * config.get_int(&"iap.coins_s.amount"))
