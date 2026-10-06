class_name AnalyticsFake
extends AnalyticsAdapter
## @api No SDK calls. Operations record calls; outcomes require explicit test delivery.

var calls: FakeCalls = FakeCalls.new()


## @api Record log_event; tests emit inherited signals to deliver success/failure/pending.
func log_event(name: String, params: Dictionary) -> void:
	calls.record("log_event", [name, params])


## @api Record set_user_property; tests emit inherited signals to deliver success/failure/pending.
func set_user_property(key: String, value: String) -> void:
	calls.record("set_user_property", [key, value])
