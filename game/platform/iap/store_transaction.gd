class_name StoreTransaction
extends RefCounted
## @api Provider-neutral transaction envelope; no grants or persistence here.
## store_key is Android purchaseToken or iOS Transaction.id, never orderId.

enum State { PURCHASED, PENDING, CANCELLED, FAILED }

var store_key: String
var product_id: String
var state: State
## Optional verified store metadata; absent price is unknown, never zero.
var price_micros: int
var price_currency: String
var restored: bool


func _init(
	key: String = "",
	product: String = "",
	status: State = State.PENDING,
	micros: int = -1,
	currency: String = "",
	from_restore: bool = false
) -> void:
	store_key = key
	product_id = product
	state = status
	price_micros = micros
	price_currency = currency
	restored = from_restore
