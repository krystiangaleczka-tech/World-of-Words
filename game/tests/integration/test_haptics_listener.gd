extends GutTest

const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const PLATFORM_SCRIPT: Script = preload("res://platform/platform.gd")
const TEST_PATH: String = "user://t0109-haptics-listener.json"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


func before_each() -> void:
	_clean_files()


func after_each() -> void:
	_clean_files()


func _clean_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)


func _save() -> SAVE_SCRIPT:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(FixedClock.new())
	save.configure(
		SaveStorage.new(TEST_PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert_eq(save.load(), OK)
	return save


func _platform(adapter: HapticsAdapter) -> PLATFORM_SCRIPT:
	var container: PLATFORM_SCRIPT = PLATFORM_SCRIPT.new()
	container.haptics = adapter
	add_child_autofree(container)
	return container


func _listener(
	events: EVENTS_SCRIPT, save: SAVE_SCRIPT, container: PLATFORM_SCRIPT
) -> HapticsListener:
	var listener: HapticsListener = HapticsListener.new()
	listener.configure(events, save, container)
	add_child_autofree(listener)
	return listener


func _emit_effects(events: EVENTS_SCRIPT) -> void:
	events.tile_touched.emit(4)
	events.word_found.emit("KOT")
	events.bonus_found.emit("KOLOR")
	events.already_found.emit("KOT")
	events.invalid_word.emit("XYZ")
	events.level_completed.emit(1)
	events.hint_used.emit()


func test_events_preference_and_disconnect() -> void:
	var events: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	add_child_autofree(events)
	var fake: HapticsFake = HapticsFake.new()
	var save: SAVE_SCRIPT = _save()
	var listener: HapticsListener = _listener(events, save, _platform(fake))
	_emit_effects(events)
	assert_eq(
		fake.calls.entries.map(func(entry: Dictionary) -> String: return entry["arguments"][0]),
		["tick", "success", "success", "soft", "error", "success", "soft"]
	)
	assert_eq(save.set_setting(&"haptics_enabled", false), OK)
	_emit_effects(events)
	assert_eq(fake.calls.entries.size(), 7)
	assert_eq(save.set_setting(&"haptics_enabled", true), OK)
	events.tile_touched.emit(6)
	assert_eq(fake.calls.entries.size(), 8)
	listener.free()
	_emit_effects(events)
	assert_eq(fake.calls.entries.size(), 8)


func test_active_listener_uses_replaced_platform_adapter() -> void:
	var events: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	add_child_autofree(events)
	var native_calls: Array[Vector2] = []
	var native: HapticsAndroid = HapticsAndroid.new(
		func(duration_ms: int, strength: float) -> void:
			native_calls.append(Vector2(duration_ms, strength))
	)
	var container: PLATFORM_SCRIPT = _platform(native)
	_listener(events, _save(), container)
	events.tile_touched.emit(0)
	assert_eq(native_calls.size(), 1)
	assert_true(container.force_fake(&"haptics"))
	var first_fake: HapticsFake = container.haptics as HapticsFake
	events.tile_touched.emit(1)
	assert_eq(native_calls.size(), 1, "forcing Fake must stop calls to the native adapter")
	assert_eq(first_fake.calls.entries.size(), 1)
	container.select_adapters("Android", false, false, [], [])
	var next_fake: HapticsFake = container.haptics as HapticsFake
	assert_not_same(next_fake, first_fake)
	events.word_found.emit("KOT")
	assert_eq(first_fake.calls.entries.size(), 1)
	assert_eq(next_fake.calls.entries, [{"method": "play", "arguments": ["success"]}])
	assert_eq(native_calls.size(), 1)


func test_listener_reconnects_on_tree_reentry_and_reconfiguration() -> void:
	var events: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	var other_events: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	add_child_autofree(events)
	add_child_autofree(other_events)
	var fake: HapticsFake = HapticsFake.new()
	var save: SAVE_SCRIPT = _save()
	var container: PLATFORM_SCRIPT = _platform(fake)
	var listener: HapticsListener = _listener(events, save, container)
	_emit_effects(events)
	assert_eq(fake.calls.entries.size(), 7)
	for entry: int in 2:
		remove_child(listener)
		_emit_effects(events)
		assert_eq(fake.calls.entries.size(), 7 * (entry + 1), "detached listener must be silent")
		add_child(listener)
		_emit_effects(events)
		assert_eq(fake.calls.entries.size(), 7 * (entry + 2), "reentry must connect exactly once")
	listener.configure(other_events, save, container)
	_emit_effects(events)
	assert_eq(fake.calls.entries.size(), 21, "reconfiguration must disconnect the old emitter")
	_emit_effects(other_events)
	assert_eq(fake.calls.entries.size(), 28)
	listener.configure(other_events, save, container)
	_emit_effects(other_events)
	assert_eq(
		fake.calls.entries.size(), 35, "configuring the same services must not duplicate calls"
	)
	listener.free()
	_emit_effects(other_events)
	assert_eq(fake.calls.entries.size(), 35)


func test_adapter_selection_preserves_fakes() -> void:
	var container: PLATFORM_SCRIPT = PLATFORM_SCRIPT.new() as PLATFORM_SCRIPT
	add_child_autofree(container)
	container.select_adapters("Android", false, false, [], [])
	assert_is(container.haptics, HapticsAndroid)
	container.select_adapters("iOS", false, false, [], [])
	assert_is(container.haptics, HapticsFake)
	container.select_adapters("Android", true, false, [], [])
	assert_is(container.haptics, HapticsFake)
	container.select_adapters("Android", false, true, [], [])
	assert_is(container.haptics, HapticsFake)
	container.select_adapters("Android", false, false, ["--fakes"], [])
	assert_is(container.haptics, HapticsFake)
	container.force_fake(&"haptics")
	container.select_adapters("Android", false, false, [], [])
	assert_is(container.haptics, HapticsFake)
