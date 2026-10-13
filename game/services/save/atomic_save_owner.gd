class_name AtomicSaveOwner
extends ServiceStub
## @api Typed owner boundary. Production approval remains unavailable until its own task.


func atomic_available() -> bool:
	return false


func atomic_has_pending() -> bool:
	return false


func validates_prepared(_value: RefCounted, _transaction: SaveTransaction) -> bool:
	return false


func prepared_payload(_value: RefCounted, _transaction: SaveTransaction) -> Dictionary:
	return {}


func atomic_context_valid(_transaction: SaveTransaction) -> bool:
	return false


func approved_progress(_value: EconomyPrepared, _transaction: SaveTransaction) -> ProgressPrepared:
	return null


func accept_commit(_receipt: Dictionary) -> Error:
	return ERR_UNAVAILABLE
