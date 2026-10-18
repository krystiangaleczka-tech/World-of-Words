class_name IapFlow
extends Node
## Explicit receipt processing. Provider adapters own verification and restore filtering.

signal state_changed(product_id: String, state: StringName, error: Error)
signal telemetry(name: StringName, params: Dictionary)
signal changed
signal restore_changed

const ECONOMY: Script = preload("res://services/economy.gd")
const SAVE: Script = preload("res://services/save.gd")
const PRODUCTS: PackedStringArray = ["nc.remove_forced_ads.v1", "c.coins_s.v1"]
var failure_revision: int = 0
var _economy: ECONOMY
var _save: SAVE
var _adapter: IapAdapter
var _catalog_timer: Timer
var _catalog: Dictionary = {}
var _catalog_state: StringName = &"unavailable"
var _querying: bool = false
var _timer: Timer
var _queue: Array[StoreTransaction] = []
var _keys: Dictionary[String, bool] = {}
var _pending_keys: Dictionary[String, String] = {}
var _unknown_products: Dictionary[String, bool] = {}
var _draining: bool = false
var _dispatching: bool = false
var _notifying: bool = false
var _active: String = ""
var _state: StringName = &"idle"
var _last_product: String = ""
var _last_error: Error = OK
var _restore_timer: Timer
var _restore_state: StringName = &"idle"
var _restore_count: int = -1
var _restore_error: Error = OK
var _restore_revision: int = 0
var _restore_observing: bool = false
var _restore_terminal: bool = false
var _restore_keys: Array[String] = []


func configure(save: SAVE, economy: ECONOMY, adapter: IapAdapter) -> void:
	_save = save
	_economy = economy
	_adapter = adapter
	_catalog_timer = Timer.new()
	_catalog_timer.one_shot = true
	_catalog_timer.ignore_time_scale = true
	_catalog_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_catalog_timer.wait_time = AdPresentation.OPERATION_TIMEOUT_SECONDS
	add_child(_catalog_timer)
	_catalog_timer.timeout.connect(_catalog_timeout)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.ignore_time_scale = true
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.wait_time = AdPresentation.OPERATION_TIMEOUT_SECONDS
	add_child(_timer)
	_timer.timeout.connect(expire)
	_adapter.products_received.connect(_on_products)
	_adapter.transaction_updated.connect(_on_transaction)
	_adapter.purchase_failed.connect(_on_failure)
	_adapter.restore_completed.connect(_on_restore_completed)
	_adapter.restore_failed.connect(_on_restore_failed)
	_restore_timer = Timer.new()
	_restore_timer.one_shot = true
	_restore_timer.ignore_time_scale = true
	_restore_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_restore_timer.wait_time = AdPresentation.OPERATION_TIMEOUT_SECONDS
	add_child(_restore_timer)
	_restore_timer.timeout.connect(expire_restore)


func busy() -> bool:
	return (
		_querying
		or _notifying
		or _draining
		or _dispatching
		or not _active.is_empty()
		or not _queue.is_empty()
		or not _pending_keys.is_empty()
		or not _unknown_products.is_empty()
	)


func presenting() -> bool:
	return _draining or _dispatching or not _active.is_empty()


func catalog_snapshot() -> Dictionary:
	return {"state": _catalog_state, "products": _catalog.duplicate(true)}


func product_state(product: String) -> StringName:
	if _unknown_products.has(product):
		return &"unknown"
	if product in _pending_keys.values():
		return &"pending"
	return _state if _last_product == product else &"idle"


func query_products() -> Error:
	if not _owners_ready():
		return ERR_UNCONFIGURED
	if _notifying or _querying or presenting() or not _queue.is_empty():
		return ERR_BUSY
	_querying = true
	_catalog = {}
	_catalog_state = &"loading"
	_catalog_timer.start()
	_dispatching = true
	changed.emit()
	_adapter.query_products(PRODUCTS)
	_dispatching = false
	changed.emit()
	return OK


func _on_products(products: Array[Dictionary]) -> void:
	if not _querying:
		return
	var candidate: Dictionary = {}
	var seen: Dictionary = {}
	var valid: bool = _owners_ready()
	for product: Dictionary in products:
		var id: Variant = product.get("id")
		var price: Variant = product.get("price")
		if not id is String or id not in PRODUCTS:
			continue
		if seen.has(id):
			valid = false
		seen[id] = true
		if price is String and not price.strip_edges().is_empty():
			candidate[id] = {"price": price}
	_querying = false
	_catalog_timer.stop()
	_catalog = candidate if valid else {}
	_catalog_state = &"ready" if valid else &"unavailable"
	changed.emit()


func _catalog_timeout() -> void:
	if not _querying:
		return
	_querying = false
	_catalog_timer.stop()
	_catalog = {}
	_catalog_state = &"unavailable"
	changed.emit()


func state() -> StringName:
	return _state


func purchase(product: String) -> Error:
	if not _owners_ready():
		return ERR_UNCONFIGURED
	if _notifying or _querying or _economy.atomic_has_pending():
		return ERR_BUSY
	if product not in PRODUCTS:
		return ERR_INVALID_PARAMETER
	if (
		_draining
		or _dispatching
		or not _active.is_empty()
		or not _queue.is_empty()
		or product in _pending_keys.values()
		or _unknown_products.has(product)
	):
		return ERR_BUSY
	_dispatching = true
	_active = product
	_timer.start()
	_notify(product, &"purchasing", OK)
	_adapter.purchase(product)
	_dispatching = false
	changed.emit()
	return OK


func recover(restore: bool = false) -> Error:
	if restore and _restore_observing:
		return ERR_BUSY
	if not _owners_ready():
		return ERR_UNCONFIGURED
	if _notifying or _querying or _draining or _dispatching or not _active.is_empty():
		return ERR_BUSY
	_dispatching = true
	var error: Error = _drain()
	if error != OK:
		_dispatching = false
		changed.emit()
		return error
	if restore:
		_restore_observing = true
		_restore_terminal = false
		_restore_keys.clear()
		_restore_timer.start()
		_set_restore(&"requested", -1, OK)
		if _restore_observing:
			_adapter.restore()
	else:
		_adapter.fetch_unfinished()
	_dispatching = false
	changed.emit()
	return OK


func expire() -> void:
	if _active.is_empty():
		return
	var product: String = _active
	_active = ""
	_unknown_products[product] = true
	_timer.stop()
	_notify(product, &"unknown", ERR_TIMEOUT)


func _owners_ready() -> bool:
	return (
		is_instance_valid(_economy)
		and is_instance_valid(_save)
		and _economy.is_ready()
		and _economy.atomic_save_matches(_save)
	)


func _on_transaction(source: StoreTransaction) -> void:
	if (
		source == null
		or source.store_key.is_empty()
		or source.store_key != source.store_key.strip_edges()
		or source.product_id not in PRODUCTS
		or source.state not in StoreTransaction.State.values()
	):
		_notify("", &"failed", ERR_INVALID_DATA)
		return
	var transaction: StoreTransaction = StoreTransaction.new(
		source.store_key,
		source.product_id,
		source.state,
		source.price_micros,
		source.price_currency,
		source.restored
	)
	var processed: bool = (
		is_instance_valid(_save)
		and (
			transaction.store_key
			in _save.committed_view().sections.monetization.processed_transactions
		)
	)
	if (
		(processed or _keys.has(transaction.store_key))
		and transaction.state != StoreTransaction.State.PURCHASED
	):
		return
	if (
		not processed
		and not _pending_keys.has(transaction.store_key)
		and transaction.product_id == _active
	):
		_active = ""
		_timer.stop()
	if transaction.state == StoreTransaction.State.PENDING:
		_pending_keys[transaction.store_key] = transaction.product_id
		_notify(transaction.product_id, &"pending", OK)
		return
	_pending_keys.erase(transaction.store_key)
	if not processed:
		_unknown_products.erase(transaction.product_id)
	if transaction.state != StoreTransaction.State.PURCHASED:
		_notify(
			transaction.product_id,
			&"cancelled" if transaction.state == StoreTransaction.State.CANCELLED else &"failed",
			OK
		)
		return
	if not _keys.has(transaction.store_key):
		_keys[transaction.store_key] = true
		_queue.append(transaction)
	_drain()


func _drain() -> Error:
	if _draining:
		return ERR_BUSY
	_draining = true
	var error: Error = OK
	while not _queue.is_empty():
		var transaction: StoreTransaction = _queue[0]
		var fresh: bool = false
		if _owners_ready():
			fresh = (
				transaction.store_key
				not in _save.committed_view().sections.monetization.processed_transactions
			)
		error = _settle(transaction)
		if error != OK:
			_notify(transaction.product_id, &"settling", error)
			break
		if fresh and not transaction.restored:
			_purchase_completed(transaction)
		_adapter.finish(
			StoreTransaction.new(transaction.store_key, transaction.product_id, transaction.state)
		)
		_queue.pop_front()
		_keys.erase(transaction.store_key)
		_pending_keys.erase(transaction.store_key)
		if _active != transaction.product_id:
			_notify(transaction.product_id, &"completed", OK)
	_maybe_restore_completed()
	_draining = false
	changed.emit()
	return error


func _settle(transaction: StoreTransaction) -> Error:
	if not _owners_ready():
		return ERR_UNCONFIGURED
	var error: Error = _economy.grant_purchase(transaction.store_key, transaction.product_id)
	if error != OK:
		return error
	if (
		not _owners_ready()
		or (
			transaction.store_key
			not in _save.committed_view().sections.monetization.processed_transactions
		)
	):
		return ERR_BUSY
	return OK


func _on_failure(_reason: String) -> void:
	failure_revision += 1
	if _querying:
		_catalog_timeout()
		return
	var product: String = _active
	if not product.is_empty():
		_active = ""
		_timer.stop()
	_notify(product, &"failed", ERR_UNAVAILABLE)
	changed.emit()


func _notify(product: String, next: StringName, error: Error) -> void:
	if _state == next and _last_product == product and _last_error == error:
		return
	_state = next
	_last_product = product
	_last_error = error
	var was_notifying: bool = _notifying
	_notifying = true
	if product in PRODUCTS:
		if next == &"purchasing":
			telemetry.emit(&"iap_purchase_started", {"product_id": product})
		elif next in [&"cancelled", &"failed", &"unknown"]:
			telemetry.emit(
				&"iap_purchase_failed",
				{
					"product_id": product,
					"error_code": "timeout" if next == &"unknown" else str(next)
				}
			)
	state_changed.emit(product, next, error)
	changed.emit()
	_notifying = was_notifying


func _exit_tree() -> void:
	if _adapter != null:
		_adapter.products_received.disconnect(_on_products)
		_adapter.transaction_updated.disconnect(_on_transaction)
		_adapter.purchase_failed.disconnect(_on_failure)
		_adapter.restore_completed.disconnect(_on_restore_completed)
		_adapter.restore_failed.disconnect(_on_restore_failed)


func _purchase_completed(transaction: StoreTransaction) -> void:
	if (
		transaction.price_micros < 0
		or transaction.price_micros > 9007199254740991
		or transaction.price_currency.length() != 3
	):
		return
	for character: String in transaction.price_currency:
		if character < "A" or character > "Z":
			return
	_observe(
		&"iap_purchase_completed",
		{
			"product_id": transaction.product_id,
			"price_micros": transaction.price_micros,
			"price_currency": transaction.price_currency
		}
	)


func _on_restore_completed(transactions: Array[StoreTransaction]) -> void:
	if not _restore_observing or _restore_terminal:
		return
	for transaction: StoreTransaction in transactions:
		if (
			transaction == null
			or transaction.product_id != PRODUCTS[0]
			or transaction.state != StoreTransaction.State.PURCHASED
			or transaction.store_key.is_empty()
			or transaction.store_key != transaction.store_key.strip_edges()
		):
			_end_restore(&"failed", ERR_INVALID_DATA)
			return
		if transaction.store_key not in _restore_keys:
			_restore_keys.append(transaction.store_key)
	_restore_terminal = true
	_restore_timer.stop()
	_maybe_restore_completed()


func _maybe_restore_completed() -> void:
	if not _restore_observing or not _restore_terminal or not _owners_ready():
		return
	var processed: Array = _save.committed_view().sections.monetization.processed_transactions
	for key: String in _restore_keys:
		if key not in processed:
			_set_restore(&"settling", -1, _restore_error if _restore_state == &"settling" else OK)
			return
	var count: int = _restore_keys.size()
	_restore_observing = false
	_restore_terminal = false
	_restore_keys.clear()
	_restore_timer.stop()
	_set_restore(&"completed", count, OK)
	_observe(&"iap_restore_completed", {"restored_count": count})


func _observe(name: StringName, params: Dictionary) -> void:
	var previous: bool = _notifying
	_notifying = true
	telemetry.emit(name, params.duplicate(true))
	_notifying = previous


## @api Transient authoritative result; no mutable owner data escapes.
func restore_snapshot() -> Dictionary:
	return {
		"state": _restore_state,
		"restored_count": _restore_count,
		"error": _restore_error,
		"revision": _restore_revision
	}


func _set_restore(next: StringName, count: int, error: Error) -> void:
	if _restore_state == next and _restore_count == count and _restore_error == error:
		return
	_restore_state = next
	_restore_count = count
	_restore_error = error
	_restore_revision += 1
	var previous: bool = _notifying
	_notifying = true
	restore_changed.emit()
	_notifying = previous


func _end_restore(next: StringName, error: Error) -> void:
	_restore_observing = false
	_restore_terminal = false
	_restore_keys.clear()
	_restore_timer.stop()
	_set_restore(next, -1, error)


func _on_restore_failed(error: Error) -> void:
	if _restore_observing and not _restore_terminal:
		_end_restore(&"failed", error if error != OK else ERR_UNAVAILABLE)


## @api Provider silence is unknown, never empty success; receipts remain authoritative.
func expire_restore() -> void:
	if _restore_observing and not _restore_terminal:
		_end_restore(&"unknown", ERR_TIMEOUT)


## @api Retry only existing durable work; do not ask the store to restore again.
func retry_restore_settlement() -> Error:
	if _notifying or _draining or _dispatching:
		return ERR_BUSY
	if not _restore_observing or not _restore_terminal:
		return ERR_UNAVAILABLE
	var error: Error = _drain()
	if error != OK:
		_set_restore(&"settling", -1, error)
	return error
