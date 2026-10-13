extends GutTest

const ECONOMY_SCRIPT: Script = preload("res://services/economy.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const PATH: String = "user://t0233-economy.json"

var service: ECONOMY_SCRIPT
var save: MemorySave
var config: JournalConfig
var bus: EVENTS_SCRIPT


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790000000


class JournalConfig:
	extends "res://services/config.gd"
	var limit: int = 2

	func has_key(key: StringName) -> bool:
		return key == &"economy.journal.max_entries"

	func get_int(_key: StringName) -> int:
		return limit


class MemorySave:
	extends "res://services/save.gd"
	var section: Dictionary = SaveSchema.TEMPLATE["economy"].duplicate(true)
	var writes: int = 0
	var flushes: int = 0
	var set_error: Error = OK
	var flush_error: Error = OK
	var callback: Callable

	func is_loaded() -> bool:
		return true

	func get_section(_name: StringName) -> Dictionary:
		return section.duplicate(true)

	func set_section(_name: StringName, value: Dictionary) -> Error:
		writes += 1
		if set_error == OK:
			section = value.duplicate(true)
		return set_error

	func flush() -> Error:
		flushes += 1
		if callback.is_valid():
			callback.call()
		return flush_error


class InterruptedStorage:
	extends SaveStorage
	var stop: bool = false

	func checkpoint(step: StringName) -> Error:
		return ERR_BUSY if stop and step == &"temp_flushed" else OK


func before_each() -> void:
	service = ECONOMY_SCRIPT.new()
	save = MemorySave.new()
	config = JournalConfig.new()
	bus = EVENTS_SCRIPT.new()
	for node: Node in [service, save, config, bus]:
		add_child_autofree(node)
	service.initialize(FixedClock.new())
	service.configure(save, config, bus)
	watch_signals(bus)


func after_each() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func test_reasoned_mixed_transactions_bound_timestamp_and_extensions() -> void:
	save.section["extension"] = {"keep": true}
	save.section["bonus_counter"] = 7
	save.section["journal"] = [{"legacy": true}]
	assert_true(service.is_ready())
	assert_eq(service.grant(&"earned", {"coins": 200, "hint": 2}), OK)
	assert_true(service.spend(&"hint", {"coins": 100, "hint": 1}))
	assert_true(service.can_afford({"coins": 100, "hint": 1}))
	assert_eq(
		service.snapshot(), {"coins": 100, "items": {"hint": 1, "reveal": 0}, "bonus_counter": 7}
	)
	assert_eq(save.section["extension"], {"keep": true})
	assert_eq(service.journal().size(), 2)
	assert_eq(
		service.journal()[0],
		{
			"timestamp": 1790000000,
			"operation": "grant",
			"reason": "earned",
			"amounts": {"coins": 200, "hint": 2}
		}
	)
	assert_signal_emit_count(bus, "economy_changed", 2)


func test_invalid_and_insufficient_requests_are_atomic() -> void:
	var before: Dictionary = save.section.duplicate(true)
	for request: Dictionary in [
		{}, {"coins": 0}, {"unknown": 1}, {"coins": -1}, {"hint": true}, {"coins": 1.5}
	]:
		assert_eq(service.grant(&"earned", request), ERR_INVALID_PARAMETER)
		assert_false(service.spend(&"hint", request))
	for reason: StringName in [&"", &" bad", &"bad "]:
		assert_eq(service.grant(reason, {"coins": 1}), ERR_INVALID_PARAMETER)
	assert_false(service.spend(&"hint", {"coins": 1, "hint": 1}))
	assert_eq(save.section, before)
	assert_eq(save.writes, 0)
	save.section["coins"] = WalletSnapshot.MAX_SAFE_COUNT
	assert_eq(service.grant(&"earned", {"coins": 1, "hint": 1}), ERR_INVALID_DATA)
	assert_eq(save.section["items"]["hint"], 0)
	assert_signal_not_emitted(bus, "economy_changed")


func test_unready_dependency_and_invalid_wallet_fail_closed() -> void:
	config.limit = 0
	assert_false(service.is_ready())
	assert_eq(service.grant(&"earned", {"coins": 1}), ERR_UNCONFIGURED)
	config.limit = 2
	save.section["items"]["unknown"] = 1
	assert_false(service.is_ready())
	assert_eq(service.snapshot(), {})
	assert_eq(save.writes, 0)


func test_failed_set_and_flush_retry_exactly_once() -> void:
	save.set_error = ERR_INVALID_DATA
	assert_eq(service.grant(&"earned", {"coins": 25}), ERR_INVALID_DATA)
	assert_eq(save.flushes, 0)
	save.set_error = OK
	save.flush_error = ERR_CANT_CREATE
	assert_eq(service.grant(&"earned", {"coins": 25}), ERR_CANT_CREATE)
	assert_eq(service.snapshot()["coins"], 0)
	assert_eq(service.journal().size(), 0)
	assert_false(service.can_afford({"coins": 1}))
	assert_eq(service.grant(&"other", {"coins": 25}), ERR_BUSY)
	assert_false(service.spend(&"hint", {"coins": 1}))
	service.configure(null, null, null)
	assert_signal_not_emitted(bus, "economy_changed")
	save.flush_error = OK
	assert_eq(save.flush(), OK, "Another Save owner may persist the candidate")
	assert_eq(service.grant(&"earned", {"coins": 25}), OK)
	assert_eq(service.snapshot()["coins"], 25)
	assert_eq(save.writes, 2, "One rejected set and one accepted candidate, no retry write")
	assert_eq(service.journal().size(), 1)
	assert_signal_emit_count(bus, "economy_changed", 1)


func test_pending_spend_retry_and_conflicting_replacement() -> void:
	save.section["coins"] = 100
	save.flush_error = ERR_BUSY
	assert_false(service.spend(&"hint", {"coins": 100}))
	assert_eq(service.snapshot()["coins"], 100)
	save.flush_error = OK
	assert_true(service.spend(&"hint", {"coins": 100}))
	assert_eq(service.snapshot()["coins"], 0)
	save.flush_error = ERR_BUSY
	assert_eq(service.grant(&"earned", {"coins": 25}), ERR_BUSY)
	save.section["coins"] = 7
	save.flush_error = OK
	assert_eq(service.grant(&"earned", {"coins": 25}), ERR_BUSY)
	assert_eq(save.section["coins"], 7)
	assert_eq(service.grant(&"earned", {"coins": 25}), OK)
	assert_eq(service.snapshot()["coins"], 32)


func test_reentrant_write_and_signal_payloads_do_not_mutate_owner() -> void:
	save.callback = func() -> void:
		assert_eq(service.grant(&"nested", {"coins": 10}), ERR_BUSY)
		service.configure(null, null, null)
	bus.economy_changed.connect(
		func(
			_operation: StringName, _reason: StringName, amounts: Dictionary, value: Dictionary
		) -> void:
			assert_false(service.spend(&"nested", {"coins": 1}))
			service.configure(null, null, null)
			amounts["coins"] = 999
			value["items"]["hint"] = 999
	)
	var request: Dictionary = {"coins": 25}
	assert_eq(service.grant(&"earned", request), OK)
	assert_eq(request, {"coins": 25})
	var snapshot: Dictionary = service.snapshot()
	snapshot["items"]["hint"] = 99
	var history: Array[Dictionary] = service.journal()
	history[0]["amounts"]["coins"] = 99
	assert_eq(service.snapshot()["items"]["hint"], 0)
	assert_eq(service.journal()[0]["amounts"]["coins"], 25)
	assert_eq(save.writes, 1)


func test_real_storage_restart_recovers_one_complete_candidate() -> void:
	var storage: InterruptedStorage = InterruptedStorage.new(PATH)
	var real: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(real)
	real.initialize(FixedClock.new())
	real.configure(storage)
	assert_eq(real.load(), OK)
	service.configure(real, config, bus)
	assert_eq(service.grant(&"earned", {"coins": 100, "hint": 2}), OK)
	storage.stop = true
	assert_false(service.spend(&"hint", {"coins": 100, "hint": 1}))
	var restored: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(restored)
	restored.initialize(FixedClock.new())
	restored.configure(SaveStorage.new(PATH))
	assert_eq(restored.load(), OK)
	var state: Dictionary = restored.get_section(&"economy")
	assert_eq(state["coins"], 100)
	assert_eq(state["items"]["hint"], 2)
	assert_eq(state["journal"].size(), 1)
	storage.stop = false
	assert_true(service.spend(&"hint", {"coins": 100, "hint": 1}))
	var loaded: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(loaded)
	loaded.initialize(FixedClock.new())
	loaded.configure(SaveStorage.new(PATH))
	assert_eq(loaded.load(), OK)
	assert_eq(loaded.get_section(&"economy")["coins"], 0)
	assert_eq(loaded.get_section(&"economy")["items"]["hint"], 1)
	assert_eq(loaded.get_section(&"economy")["journal"].size(), 2)
