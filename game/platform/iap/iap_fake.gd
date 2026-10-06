class_name IapFake
extends IapAdapter
## @api No SDK calls. Operations record calls; outcomes require explicit test delivery.

var calls: FakeCalls = FakeCalls.new()


## @api Record query_products; tests emit inherited signals to deliver success/failure/pending.
func query_products(ids: PackedStringArray) -> void:
	calls.record("query_products", [ids])


## @api Record purchase; tests emit inherited signals to deliver success/failure/pending.
func purchase(id: String) -> void:
	calls.record("purchase", [id])


## @api Record finish; tests emit inherited signals to deliver success/failure/pending.
func finish(transaction: StoreTransaction) -> void:
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


## @api Record fetch_unfinished; tests emit inherited signals to deliver success/failure/pending.
func fetch_unfinished() -> void:
	calls.record("fetch_unfinished", [])


## @api Record restore; tests emit inherited signals to deliver success/failure/pending.
func restore() -> void:
	calls.record("restore", [])
