class_name CrashAdapter
extends RefCounted
## @api crash adapter contract; signals report outcomes, never gameplay grants.


## @api record: provider operation.
func record(_message: String) -> void:
	pass


## @api set_key: provider operation.
func set_key(_key: String, _value: String) -> void:
	pass
