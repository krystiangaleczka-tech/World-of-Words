extends GutTest

const PROGRESS: Script = preload("res://services/progress.gd")
const CONFIG: Script = preload("res://services/config.gd")
const EVENTS: Script = preload("res://services/events.gd")


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 0

	func monotonic_msec() -> int:
		return 0

	func monotonic_usec() -> int:
		return 0


class AvailablePort:
	extends ProgressCommitPort
	var calls: int = 0

	func is_available() -> bool:
		calls += 1
		return true

	func read_committed(_language: String, _context: Dictionary) -> Dictionary:
		calls += 1
		return {"error": OK, "state": "committed", "snapshot": {"stars": 7}}

	func transact(_request: Dictionary) -> Dictionary:
		calls += 1
		return {"error": OK}

	func recover(_operation_id: String, _context: Dictionary) -> Dictionary:
		calls += 1
		return {"error": OK}


class ConfigSpy:
	extends "res://services/config.gd"
	var calls: int = 0

	func has_key(_key: StringName) -> bool:
		calls += 1
		return true

	func get_int(_key: StringName) -> int:
		calls += 1
		return 1


class SaveSpy:
	extends "res://services/save.gd"
	var writes: int = 0

	func is_loaded() -> bool:
		return true

	func get_setting(_key: StringName) -> Variant:
		return "pl"

	func get_section(_section: StringName) -> Dictionary:
		return {"by_lang": {"pl": {"current_slot": 5, "highest_completed_slot": 4}}}

	func set_section(_section: StringName, _values: Dictionary) -> Error:
		writes += 1
		return OK

	func flush() -> Error:
		writes += 1
		return OK


class ContentSpy:
	extends "res://services/content.gd"

	func is_loaded() -> bool:
		return true

	func get_language() -> String:
		return "pl"


func _assert_defaults(progress: PROGRESS) -> void:
	assert_false(progress.p2_ready())
	for language: String in ["", "pl", "en", "missing"]:
		assert_eq(progress.stars(language), 0)
		assert_false(progress.is_feature_unlocked(&"daily", language))
		assert_eq_deep(progress.language_progress(language), {})
		assert_eq_deep(progress.location_state(&"location", language), {})
		assert_eq_deep(progress.region_state(&"region", language), {})
	var result: Dictionary = progress.language_progress()
	result["stars"] = 99
	assert_eq_deep(progress.language_progress(), {})
	result = progress.location_state(&"location")
	result["pieces"] = 99
	assert_eq_deep(progress.location_state(&"location"), {})
	result = progress.region_state(&"region")
	result["unlocked"] = true
	assert_eq_deep(progress.region_state(&"region"), {})


func test_unconfigured_queries_are_inert_and_copied() -> void:
	var progress: PROGRESS = PROGRESS.new()
	add_child_autofree(progress)
	_assert_defaults(progress)
	assert_eq(progress.configure_p2(null, null, null), ERR_UNAVAILABLE)
	_assert_defaults(progress)


func test_available_dependency_cannot_activate_or_change_p1() -> void:
	var progress: PROGRESS = PROGRESS.new()
	var save: SaveSpy = SaveSpy.new()
	var content: ContentSpy = ContentSpy.new()
	var config: ConfigSpy = ConfigSpy.new()
	var events: EVENTS = EVENTS.new()
	for node: Node in [progress, save, content, config, events]:
		add_child_autofree(node)
	var clock: Clock = FixedClock.new()
	progress.initialize(clock)
	progress.configure(save, content)
	watch_signals(progress)
	watch_signals(events)
	var port: AvailablePort = AvailablePort.new()
	assert_eq(progress.configure_p2(config, port, events), ERR_UNAVAILABLE)
	_assert_defaults(progress)
	assert_eq(progress.current_slot(), 5)
	assert_eq(progress.highest_completed_slot(), 4)
	assert_same(progress.get_clock(), clock)
	assert_null(progress.restore_level(null))
	assert_eq(progress.save_level(null), ERR_INVALID_PARAMETER)
	progress.bind_board(null)
	progress.unbind_board()
	assert_eq(save.writes, 0)
	assert_eq(config.calls, 0)
	assert_eq(port.calls, 0)
	assert_signal_not_emitted(progress, "completed")
	for entry: Dictionary in events.get_signal_list():
		assert_signal_not_emitted(events, entry["name"])


func test_default_port_is_unavailable_without_mutating_requests() -> void:
	var port: ProgressCommitPort = ProgressCommitPort.new()
	var request: Dictionary = {"candidate": {"stars": 9}}
	var expected: Dictionary = request.duplicate(true)
	assert_false(port.is_available())
	var results: Array[Dictionary] = [
		port.read_committed("pl", request), port.transact(request), port.recover("id", request)
	]
	for result: Dictionary in results:
		assert_eq_deep(
			result,
			{"error": ERR_UNAVAILABLE, "state": "unavailable", "snapshot": {}, "receipt": {}}
		)
	results[0]["snapshot"]["stars"] = 9
	results[0]["receipt"]["id"] = "changed"
	assert_eq_deep(results[1]["snapshot"], {})
	assert_eq_deep(results[2]["receipt"], {})
	assert_eq_deep(port.transact(request)["snapshot"], {})
	assert_eq_deep(request, expected)
