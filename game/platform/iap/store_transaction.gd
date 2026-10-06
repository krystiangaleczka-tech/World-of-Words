class_name StoreTransaction
extends RefCounted
## @api Provider-neutral transaction envelope; no grants or persistence here.
## store_key is Android purchaseToken or iOS Transaction.id, never orderId.

enum State { PURCHASED, PENDING, CANCELLED, FAILED }

var store_key: String
var product_id: String
var state: State


func _init(key: String = "", product: String = "", status: State = State.PENDING) -> void:
	store_key = key
	product_id = product
	state = status
