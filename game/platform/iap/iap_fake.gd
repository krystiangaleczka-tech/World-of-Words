class_name IapFake
extends IapAdapter
## @api Isolated in-memory provider model. Manual by default; never grants gameplay value.

var calls: FakeCalls = FakeCalls.new()
var _products: Array[Dictionary] = []
var _records: Dictionary[String, StoreTransaction] = {}
var _owned: Dictionary[String, StoreTransaction] = {}
var _interrupted: Dictionary[String, bool] = {}
var _outcomes: Dictionary[StringName, StringName] = {}
var _immediate: Dictionary[StringName, bool] = {}
var _generation: int = 0
var _sequence: int = 0
var _operation: StringName = &""
var _outcome: StringName = &"manual"
var _pending: bool = false
var _arguments: Array = []


func query_products(ids: PackedStringArray) -> void:
	calls.record("query_products", [ids])
	_begin(&"query_products", [ids.duplicate()])


func purchase(id: String) -> void:
	calls.record("purchase", [id])
	_begin(&"purchase", [id])


func finish(transaction: StoreTransaction) -> void:
	if transaction == null:
		return
	calls.record(
		"finish",
		[
			{
				"store_key": transaction.store_key,
				"product_id": transaction.product_id,
				"state": transaction.state
			}
		]
	)
	var stored: StoreTransaction = _records.get(transaction.store_key)
	if (
		stored != null
		and stored.state == StoreTransaction.State.PURCHASED
		and transaction.state == stored.state
		and transaction.product_id == stored.product_id
		and not _interrupted.has(stored.store_key)
	):
		_records.erase(stored.store_key)


func fetch_unfinished() -> void:
	calls.record("fetch_unfinished", [])
	_begin(&"fetch_unfinished", [])


func restore() -> void:
	calls.record("restore", [])
	_begin(&"restore", [])


## @api Fixtures use unique id and restorable bool; localized metadata stays opaque.
func set_products(products: Array[Dictionary]) -> Error:
	var ids: Dictionary[String, bool] = {}
	for product: Dictionary in products:
		if (
			not product.get("id") is String
			or str(product["id"]).is_empty()
			or str(product["id"]) != str(product["id"]).strip_edges()
			or not product.get("restorable") is bool
			or ids.has(product["id"])
		):
			return ERR_INVALID_PARAMETER
		ids[product["id"]] = true
	_cancel()
	_products = products.duplicate(true)
	return OK


## @api Controls affect only this instance; invalid controls preserve pending output.
func set_outcome(operation: StringName, outcome: StringName, immediate: bool = true) -> Error:
	var allowed: Array[StringName] = [&"manual", &"error"]
	if operation == &"purchase":
		allowed.append_array(
			[
				&"success",
				&"cancel",
				&"pending",
				&"deferred",
				&"failed",
				&"crash_before_finish",
				&"duplicate"
			]
		)
	elif operation in [&"query_products", &"fetch_unfinished", &"restore"]:
		allowed.append(&"ready")
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
		var restoring: bool = _operation == &"restore"
		purchase_failed.emit("error")
		if restoring and _generation == token:
			restore_failed.emit(ERR_UNAVAILABLE)
	elif _operation == &"query_products":
		var result: Array[Dictionary] = []
		for product: Dictionary in _products:
			if product["id"] in _arguments[0]:
				result.append(product.duplicate(true))
		products_received.emit(result)
	elif _operation == &"purchase":
		_deliver_purchase(token)
	else:
		var restoring: bool = _operation == &"restore"
		var batch: Array[StoreTransaction] = []
		if restoring:
			for transaction: StoreTransaction in _owned.values():
				var copied: StoreTransaction = _copy(transaction)
				copied.restored = true
				batch.append(copied)
		_replay(token, _owned if restoring else _records, restoring)
		if restoring and _generation == token:
			restore_completed.emit(batch)
	return true


## @api Explicit provider progression; pending/deferred share the frozen PENDING state.
func set_transaction_state(key: String, state: StoreTransaction.State) -> Error:
	var transaction: StoreTransaction = _records.get(key)
	if (
		transaction == null
		or transaction.state != StoreTransaction.State.PENDING
		or state not in [StoreTransaction.State.PURCHASED, StoreTransaction.State.CANCELLED]
	):
		return ERR_INVALID_PARAMETER
	_cancel()
	if state == StoreTransaction.State.CANCELLED:
		_records.erase(key)
	else:
		transaction.state = state
		_remember_owned(transaction)
	return OK


## @api Preserve provider state, fixture controls and log; release interrupted finish.
func simulate_restart() -> void:
	_cancel()
	_interrupted.clear()


## @api Reset all provider state, controls and log; old operation tokens stay invalid.
func reset() -> void:
	_cancel()
	_products.clear()
	_records.clear()
	_owned.clear()
	_interrupted.clear()
	_outcomes.clear()
	_immediate.clear()
	_sequence = 0
	calls.entries.clear()


func _deliver_purchase(token: int) -> void:
	var id: String = _arguments[0]
	if not _known_product(id):
		purchase_failed.emit("unknown_product")
		return
	_sequence += 1
	var state: StoreTransaction.State = StoreTransaction.State.PURCHASED
	if _outcome in [&"pending", &"deferred"]:
		state = StoreTransaction.State.PENDING
	elif _outcome == &"cancel":
		state = StoreTransaction.State.CANCELLED
	elif _outcome == &"failed":
		state = StoreTransaction.State.FAILED
	var transaction: StoreTransaction = StoreTransaction.new("fake_iap_%d" % _sequence, id, state)
	for product: Dictionary in _products:
		if product["id"] == id:
			if product.get("price_micros") is int:
				transaction.price_micros = product["price_micros"]
			if product.get("price_currency") is String:
				transaction.price_currency = product["price_currency"]
	if state in [StoreTransaction.State.PURCHASED, StoreTransaction.State.PENDING]:
		_records[transaction.store_key] = transaction
		_remember_owned(transaction)
	if _outcome == &"crash_before_finish":
		_interrupted[transaction.store_key] = true
	var outcome: StringName = _outcome
	transaction_updated.emit(_copy(transaction))
	if _generation != token:
		return
	if outcome == &"duplicate":
		transaction_updated.emit(_copy(transaction))
	elif outcome == &"failed":
		purchase_failed.emit("failed")


func _known_product(id: String) -> bool:
	for product: Dictionary in _products:
		if product["id"] == id:
			return true
	return false


func _remember_owned(transaction: StoreTransaction) -> void:
	if transaction.state != StoreTransaction.State.PURCHASED:
		return
	for product: Dictionary in _products:
		if product["id"] == transaction.product_id and product["restorable"]:
			_owned[transaction.store_key] = _copy(transaction)


func _replay(
	token: int, records: Dictionary[String, StoreTransaction], restoring: bool = false
) -> void:
	var batch: Array[StoreTransaction] = []
	var keys: Array[String] = records.keys()
	keys.sort()
	for key: String in keys:
		var copied: StoreTransaction = _copy(records[key])
		copied.restored = restoring
		batch.append(copied)
	for transaction: StoreTransaction in batch:
		if _generation != token:
			return
		transaction_updated.emit(transaction)


func _copy(transaction: StoreTransaction) -> StoreTransaction:
	return StoreTransaction.new(
		transaction.store_key,
		transaction.product_id,
		transaction.state,
		transaction.price_micros,
		transaction.price_currency,
		transaction.restored
	)


func _cancel() -> void:
	_generation += 1
	_operation = &""
	_pending = false
	_arguments = []


func _begin(operation: StringName, arguments: Array) -> void:
	_cancel()
	_operation = operation
	_arguments = arguments
	_outcome = _outcomes.get(operation, &"manual")
	_pending = true
	if _immediate.get(operation, false):
		settle(_generation)
