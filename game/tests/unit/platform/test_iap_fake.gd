extends GutTest

const COINS: String = "c.coins_s.v1"
const REMOVE: String = "nc.remove_forced_ads.v1"
var store: IapFake
var transactions: Array[StoreTransaction]
var failures: Array[String]
var catalogs: Array[Array]


func before_each() -> void:
	store = IapFake.new()
	transactions = []
	failures = []
	catalogs = []
	store.transaction_updated.connect(func(tx: StoreTransaction) -> void: transactions.append(tx))
	store.purchase_failed.connect(func(reason: String) -> void: failures.append(reason))
	store.products_received.connect(
		func(products: Array[Dictionary]) -> void: catalogs.append(products)
	)
	assert_eq(
		store.set_products(
			[
				{"id": COINS, "restorable": false, "price": {"display": "fixture"}},
				{"id": REMOVE, "restorable": true}
			]
		),
		OK
	)


func test_manual_defaults_keep_legacy_call_log_and_explicit_signals() -> void:
	store.query_products([COINS])
	store.purchase(COINS)
	store.finish(StoreTransaction.new("key", COINS, StoreTransaction.State.PURCHASED))
	store.fetch_unfinished()
	store.restore()
	assert_eq(store.calls.entries.size(), 5)
	assert_eq(store.calls.entries[2]["arguments"][0]["store_key"], "key")
	assert_false(store.settle(store.operation_token()))
	assert_true(transactions.is_empty())
	assert_true(catalogs.is_empty())
	assert_true(failures.is_empty())
	store.transaction_updated.emit(StoreTransaction.new("manual", COINS))
	assert_eq(transactions[0].store_key, "manual")


func test_fixture_validation_and_product_copies_preserve_pending_request() -> void:
	assert_eq(store.set_outcome(&"query_products", &"ready", false), OK)
	store.query_products([COINS, "missing"])
	var token: int = store.operation_token()
	assert_eq(store.set_products([{"id": COINS}]), ERR_INVALID_PARAMETER)
	assert_eq(store.set_products([{"id": " ", "restorable": false}]), ERR_INVALID_PARAMETER)
	assert_eq(
		store.set_products([{"id": COINS, "restorable": false}, {"id": COINS, "restorable": true}]),
		ERR_INVALID_PARAMETER
	)
	assert_eq(store.set_outcome(&"finish", &"ready"), ERR_INVALID_PARAMETER)
	assert_eq(store.set_outcome(&"purchase", &"ready"), ERR_INVALID_PARAMETER)
	assert_true(store.settle(token))
	assert_eq(catalogs[0].size(), 1)
	catalogs[0][0]["price"]["display"] = "mutated"
	store.query_products([COINS])
	assert_true(store.settle(store.operation_token()))
	assert_eq(catalogs[1][0]["price"]["display"], "fixture")
	var fixture: Array[Dictionary] = [{"id": COINS, "restorable": false}]
	assert_eq(store.set_products(fixture), OK)
	fixture[0]["id"] = "mutated"
	assert_eq(store.set_outcome(&"purchase", &"success"), OK)
	store.purchase(COINS)
	assert_eq(transactions[0].product_id, COINS)


func test_purchase_outcomes_and_unique_deterministic_keys() -> void:
	var outcomes: Array[StringName] = [&"success", &"cancel", &"pending", &"deferred", &"failed"]
	var states: Array[int] = [
		StoreTransaction.State.PURCHASED,
		StoreTransaction.State.CANCELLED,
		StoreTransaction.State.PENDING,
		StoreTransaction.State.PENDING,
		StoreTransaction.State.FAILED
	]
	for index: int in outcomes.size():
		assert_eq(store.set_outcome(&"purchase", outcomes[index]), OK)
		store.purchase(COINS)
		assert_eq(transactions[index].state, states[index])
		assert_eq(transactions[index].store_key, "fake_iap_%d" % (index + 1))
	assert_eq(failures, ["failed"])
	store.purchase("")
	store.purchase("unknown")
	assert_eq(transactions.size(), 5)
	assert_eq(failures, ["failed", "unknown_product", "unknown_product"])


func test_duplicate_copies_exact_key_and_finish_is_idempotent() -> void:
	assert_eq(store.set_outcome(&"purchase", &"duplicate"), OK)
	store.purchase(COINS)
	assert_eq(transactions.size(), 2)
	assert_ne(transactions[0], transactions[1])
	assert_eq(transactions[0].store_key, transactions[1].store_key)
	transactions[0].product_id = "wrong"
	store.finish(transactions[0])
	assert_eq(store.set_outcome(&"fetch_unfinished", &"ready"), OK)
	store.fetch_unfinished()
	assert_eq(transactions.size(), 3)
	assert_eq(transactions[2].product_id, COINS)
	store.finish(transactions[1])
	store.finish(transactions[1])
	store.fetch_unfinished()
	assert_eq(transactions.size(), 3)


func test_pending_progression_and_cancellation_never_finish_early() -> void:
	assert_eq(store.set_outcome(&"purchase", &"deferred"), OK)
	store.purchase(COINS)
	var key: String = transactions[0].store_key
	store.finish(StoreTransaction.new(key, COINS, StoreTransaction.State.PURCHASED))
	assert_eq(store.set_outcome(&"fetch_unfinished", &"ready"), OK)
	store.fetch_unfinished()
	assert_eq(transactions[1].state, StoreTransaction.State.PENDING)
	assert_eq(store.set_transaction_state(key, StoreTransaction.State.PURCHASED), OK)
	store.fetch_unfinished()
	assert_eq(transactions[2].store_key, key)
	assert_eq(transactions[2].state, StoreTransaction.State.PURCHASED)
	assert_eq(
		store.set_transaction_state(key, StoreTransaction.State.CANCELLED), ERR_INVALID_PARAMETER
	)
	store.purchase(COINS)
	var cancelled: String = transactions[3].store_key
	assert_eq(store.set_transaction_state(cancelled, StoreTransaction.State.CANCELLED), OK)
	assert_eq(
		store.set_transaction_state("missing", StoreTransaction.State.PURCHASED),
		ERR_INVALID_PARAMETER
	)
	store.finish(transactions[2])
	store.fetch_unfinished()
	assert_eq(transactions.size(), 4)


func test_interrupted_finish_survives_restart_with_same_transaction() -> void:
	assert_eq(store.set_outcome(&"purchase", &"crash_before_finish"), OK)
	store.purchase(COINS)
	var original: StoreTransaction = transactions[0]
	store.finish(original)
	assert_eq(store.set_outcome(&"fetch_unfinished", &"ready", false), OK)
	store.fetch_unfinished()
	var obsolete: int = store.operation_token()
	store.simulate_restart()
	assert_false(store.settle(obsolete))
	store.fetch_unfinished()
	assert_true(store.settle(store.operation_token()))
	assert_eq(transactions[1].store_key, original.store_key)
	store.finish(transactions[1])
	store.fetch_unfinished()
	assert_true(store.settle(store.operation_token()))
	assert_eq(transactions.size(), 2)
	assert_eq(store.calls.entries.size(), 6)


func test_restore_only_owned_restorable_products_after_finish() -> void:
	assert_eq(store.set_outcome(&"purchase", &"success"), OK)
	store.purchase(COINS)
	store.finish(transactions[0])
	store.purchase(REMOVE)
	store.finish(transactions[1])
	assert_eq(store.set_outcome(&"restore", &"ready"), OK)
	store.restore()
	assert_eq(transactions.size(), 3)
	assert_eq(transactions[2].store_key, transactions[1].store_key)
	assert_eq(transactions[2].product_id, REMOVE)
	transactions[2].store_key = "mutated"
	store.restore()
	assert_eq(transactions[3].store_key, transactions[1].store_key)


func test_tokens_commands_control_change_and_reset_cancel_output() -> void:
	assert_eq(store.set_outcome(&"purchase", &"success", false), OK)
	store.purchase(COINS)
	var first: int = store.operation_token()
	store.purchase(REMOVE)
	var second: int = store.operation_token()
	assert_false(store.settle(first))
	assert_true(store.settle(second))
	assert_false(store.settle(second))
	assert_eq(transactions.size(), 1)
	store.purchase(COINS)
	var third: int = store.operation_token()
	assert_eq(store.set_outcome(&"restore", &"ready"), OK)
	assert_false(store.settle(third))
	store.purchase(COINS)
	var fourth: int = store.operation_token()
	store.reset()
	assert_false(store.settle(fourth))
	assert_true(store.calls.entries.is_empty())
	store.purchase(COINS)
	assert_false(store.settle(store.operation_token()))
	assert_eq(transactions.size(), 1)
	assert_eq(store.set_outcome(&"fetch_unfinished", &"ready"), OK)
	store.fetch_unfinished()
	assert_eq(transactions.size(), 1)


func test_synchronous_reentry_stops_duplicate_and_remaining_replay() -> void:
	assert_eq(store.set_outcome(&"purchase", &"duplicate"), OK)
	store.transaction_updated.connect(
		func(_tx: StoreTransaction) -> void: store.simulate_restart(), CONNECT_ONE_SHOT
	)
	store.purchase(COINS)
	assert_eq(transactions.size(), 1)
	assert_eq(store.set_outcome(&"purchase", &"success"), OK)
	store.purchase(REMOVE)
	assert_eq(store.set_outcome(&"fetch_unfinished", &"ready"), OK)
	store.transaction_updated.connect(func(tx: StoreTransaction) -> void: store.finish(tx))
	store.fetch_unfinished()
	assert_eq(transactions.size(), 4, "Finishing a callback does not truncate snapshot replay")
	store.fetch_unfinished()
	assert_eq(transactions.size(), 4)
	store.purchase(COINS)
	store.purchase(REMOVE)
	store.transaction_updated.connect(
		func(_tx: StoreTransaction) -> void: store.reset(), CONNECT_ONE_SHOT
	)
	store.restore()
	assert_eq(transactions.size(), 6, "Manual restore has no controlled output")
	assert_eq(store.set_outcome(&"restore", &"ready"), OK)
	store.restore()
	assert_eq(transactions.size(), 7, "Reentry cancels the rest of a replay batch")


func test_error_controls_emit_no_transactions_or_products() -> void:
	for operation: StringName in [&"query_products", &"purchase", &"fetch_unfinished", &"restore"]:
		assert_eq(store.set_outcome(operation, &"error"), OK)
		match operation:
			&"query_products":
				store.query_products([COINS])
			&"purchase":
				store.purchase(COINS)
			&"fetch_unfinished":
				store.fetch_unfinished()
			&"restore":
				store.restore()
	assert_eq(failures, ["error", "error", "error", "error"])
	assert_true(transactions.is_empty())
	assert_true(catalogs.is_empty())


func test_instances_isolate_controls_ownership_and_restart_sequence() -> void:
	var other: IapFake = IapFake.new()
	assert_eq(store.set_outcome(&"purchase", &"success"), OK)
	store.purchase(COINS)
	other.purchase(COINS)
	assert_false(other.settle(other.operation_token()))
	assert_eq(other.calls.entries.size(), 1)
	store.simulate_restart()
	store.purchase(COINS)
	assert_eq(transactions[0].store_key, "fake_iap_1")
	assert_eq(transactions[1].store_key, "fake_iap_2")
	assert_eq(store.set_outcome(&"fetch_unfinished", &"ready", false), OK)
	store.fetch_unfinished()
	var stale: int = store.operation_token()
	assert_eq(store.set_products([]), OK)
	assert_false(store.settle(stale))
	store.fetch_unfinished()
	assert_true(store.settle(store.operation_token()))
	assert_eq(transactions.size(), 4, "Changing catalog does not erase outstanding purchases")
