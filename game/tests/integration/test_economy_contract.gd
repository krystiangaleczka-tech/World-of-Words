extends GutTest

const ECONOMY_SCRIPT: Script = preload("res://services/economy.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")


class SaveSpy:
	extends "res://services/save.gd"
	var calls: int = 0

	func get_section(_section: StringName) -> Dictionary:
		calls += 1
		return {}

	func set_section(_section: StringName, _value: Dictionary) -> Error:
		calls += 1
		return OK

	func flush() -> Error:
		calls += 1
		return OK


func _assert_unavailable(service: ECONOMY_SCRIPT) -> void:
	assert_false(service.is_ready())
	assert_eq_deep(service.snapshot(), {})
	assert_eq(service.journal().size(), 0)
	assert_false(service.can_afford({"coins": 1}))
	assert_eq(service.grant(&"level_complete", {"coins": 25}), ERR_UNCONFIGURED)
	assert_false(service.spend(&"hint", {"coins": 100}))
	assert_eq(service.grant(&"", {}), ERR_UNCONFIGURED)
	assert_false(service.spend(&"", {"coins": -1}))


func test_typed_interface_fails_closed_before_initialization() -> void:
	var service: ECONOMY_SCRIPT = ECONOMY_SCRIPT.new()
	add_child_autofree(service)
	assert_null(service.get_clock())
	_assert_unavailable(service)


func test_configuration_is_inert_and_preserves_injected_clock() -> void:
	var service: ECONOMY_SCRIPT = ECONOMY_SCRIPT.new()
	var save: SaveSpy = SaveSpy.new()
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var bus: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	add_child_autofree(service)
	add_child_autofree(save)
	add_child_autofree(config)
	add_child_autofree(bus)
	watch_signals(bus)
	var clock: Clock = Clock.new()
	service.initialize(clock)
	service.configure(save, config, bus)
	service.configure(save, config, bus)
	_assert_unavailable(service)
	assert_same(service.get_clock(), clock)
	assert_eq(save.calls, 0)
	assert_signal_not_emitted(bus, "economy_changed")


func test_empty_reads_and_request_payloads_are_isolated() -> void:
	var service: ECONOMY_SCRIPT = ECONOMY_SCRIPT.new()
	add_child_autofree(service)
	var value: Dictionary = service.snapshot()
	value["coins"] = 99
	var history: Array[Dictionary] = service.journal()
	history.append({"reason": "example"})
	var request: Dictionary = {"coins": 25}
	service.grant(&"level_complete", request)
	service.spend(&"hint", request)
	assert_eq_deep(request, {"coins": 25})
	request["coins"] = 1
	_assert_unavailable(service)


func test_economy_notification_has_the_typed_contract() -> void:
	var bus: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	add_child_autofree(bus)
	var found: bool = false
	for definition: Dictionary in bus.get_signal_list():
		if definition["name"] != "economy_changed":
			continue
		found = true
		var args: Array = definition["args"]
		assert_eq(args.size(), 4)
		var names: Array[String] = ["operation", "reason", "amounts", "snapshot"]
		var types: Array[int] = [
			TYPE_STRING_NAME, TYPE_STRING_NAME, TYPE_DICTIONARY, TYPE_DICTIONARY
		]
		for index: int in names.size():
			assert_eq(args[index]["name"], names[index])
			assert_eq(args[index]["type"], types[index])
	assert_true(found)
