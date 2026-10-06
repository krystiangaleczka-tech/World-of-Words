class_name CrashFake
extends CrashAdapter
## @api No SDK calls. Operations record calls; outcomes require explicit test delivery.

var calls: FakeCalls = FakeCalls.new()


## @api Record record; tests emit inherited signals to deliver success/failure/pending.
func record(message: String) -> void:
	calls.record("record", [message])


## @api Record set_key; tests emit inherited signals to deliver success/failure/pending.
func set_key(key: String, value: String) -> void:
	calls.record("set_key", [key, value])
