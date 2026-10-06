class_name AnalyticsAdapter
extends RefCounted
## @api analytics adapter contract; signals report outcomes, never gameplay grants.


## @api log_event: provider operation.
func log_event(_name: String, _params: Dictionary) -> void:
	pass


## @api set_user_property: provider operation.
func set_user_property(_key: String, _value: String) -> void:
	pass
