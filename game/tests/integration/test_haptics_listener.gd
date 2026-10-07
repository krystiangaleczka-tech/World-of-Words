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


func _listener(events: EVENTS_SCRIPT, save: SAVE_SCRIPT, fake: HapticsFake) -> HapticsListener:
	var listener: HapticsListener = HapticsListener.new()
	listener.configure(events, save, fake)
	add_child_autofree(listener)
	return listener


func test_events_preference_and_disconnect() -> void:
	var events: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	add_child_autofree(events)
	var fake: HapticsFake = HapticsFake.new()
	var save: SAVE_SCRIPT = _save()
	var listener: HapticsListener = _listener(events, save, fake)
	events.tile_touched.emit(4)
	events.word_found.emit("KOT")
	events.bonus_found.emit("KOLOR")
	events.already_found.emit("KOT")
	events.invalid_word.emit("XYZ")
	events.level_completed.emit(1)
	events.hint_used.emit()
	assert_eq(
		fake.calls.entries.map(func(entry: Dictionary) -> String: return entry["arguments"][0]),
		["tick", "success", "success", "soft", "error", "success", "soft"]
	)
	assert_eq(save.set_setting(&"haptics_enabled", false), OK)
	events.tile_touched.emit(5)
	events.invalid_word.emit("ABC")
	assert_eq(fake.calls.entries.size(), 7)
	assert_eq(save.set_setting(&"haptics_enabled", true), OK)
	events.tile_touched.emit(6)
	assert_eq(fake.calls.entries.size(), 8)
	listener.free()
	events.tile_touched.emit(7)
	assert_eq(fake.calls.entries.size(), 8)


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
