class_name ProgressCommitPort
extends RefCounted
## @api Required coordinator protocol.
## Default cannot certify atomic Save/Economy or legacy adaptation.


func is_available() -> bool:
	return false


## @api Only committed domain views; default performs no reads or I/O.
func read_committed(_language: String, _context: Dictionary) -> Dictionary:
	return _unavailable()


## @api Future backend validates one joint candidate and durable stable operation proof.
func transact(_request: Dictionary) -> Dictionary:
	return _unavailable()


## @api Resolve a prior identity without reapplying grants; no default persistence capability.
func recover(_operation_id: String, _context: Dictionary) -> Dictionary:
	return _unavailable()


func _unavailable() -> Dictionary:
	return {"error": ERR_UNAVAILABLE, "state": "unavailable", "snapshot": {}, "receipt": {}}
