class_name IapAdapter
extends RefCounted
## @api iap adapter contract; signals report outcomes, never gameplay grants.

signal products_received(products: Array[Dictionary])
signal transaction_updated(transaction: StoreTransaction)
signal purchase_failed(reason: String)


## @api query_products: provider operation.
func query_products(_ids: PackedStringArray) -> void:
	pass


## @api purchase: provider operation.
func purchase(_id: String) -> void:
	pass


## @api finish: provider operation.
func finish(_transaction: StoreTransaction) -> void:
	pass


## @api fetch_unfinished: provider operation.
func fetch_unfinished() -> void:
	pass


## @api restore: provider operation.
func restore() -> void:
	pass
