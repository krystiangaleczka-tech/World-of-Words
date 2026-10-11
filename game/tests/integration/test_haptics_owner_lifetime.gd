extends GutTest

const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const PLATFORM_SCRIPT: Script = preload("res://platform/platform.gd")


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		document = JSON.parse_string(text)
		return OK


func _save() -> SAVE_SCRIPT:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(FixedClock.new())
	save.configure(MemoryStorage.new())
	assert_eq(save.load(), OK)
	return save


func _events() -> EVENTS_SCRIPT:
	var events: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	add_child_autofree(events)
	return events


func _platform(fake: HapticsFake) -> PLATFORM_SCRIPT:
	var platform: PLATFORM_SCRIPT = PLATFORM_SCRIPT.new()
	platform.haptics = fake
	add_child_autofree(platform)
	return platform


func _listener(
	events: EVENTS_SCRIPT, save: SAVE_SCRIPT, platform: PLATFORM_SCRIPT
) -> HapticsListener:
	var listener: HapticsListener = HapticsListener.new()
	listener.configure(events, save, platform)
	add_child_autofree(listener)
	return listener


func test_destroyed_settings_and_platform_are_silent() -> void:
	var events: EVENTS_SCRIPT = _events()
	var fake: HapticsFake = HapticsFake.new()
	var save: SAVE_SCRIPT = _save()
	var platform: PLATFORM_SCRIPT = _platform(fake)
	var listener: HapticsListener = _listener(events, save, platform)
	events.tile_touched.emit(0)
	assert_eq(fake.calls.entries.size(), 1)
	save.free()
	events.tile_touched.emit(1)
	assert_eq(fake.calls.entries.size(), 1)
	var replacement: SAVE_SCRIPT = _save()
	listener.configure(events, replacement, platform)
	events.word_found.emit("KOT")
	assert_eq(fake.calls.entries.size(), 2)
	platform.free()
	events.bonus_found.emit("KUR")
	assert_eq(fake.calls.entries.size(), 2)
	listener.free()
	assert_eq(events.tile_touched.get_connections().size(), 0)


func test_destroyed_emitter_reentry_rebind_and_teardown() -> void:
	var events: EVENTS_SCRIPT = _events()
	var fake: HapticsFake = HapticsFake.new()
	var save: SAVE_SCRIPT = _save()
	var platform: PLATFORM_SCRIPT = _platform(fake)
	var listener: HapticsListener = _listener(events, save, platform)
	events.free()
	remove_child(listener)
	add_child(listener)
	var replacement: EVENTS_SCRIPT = _events()
	listener.configure(replacement, save, platform)
	listener.configure(replacement, save, platform)
	assert_eq(replacement.tile_touched.get_connections().size(), 1)
	replacement.tile_touched.emit(2)
	assert_eq(fake.calls.entries.size(), 1)
	replacement.free()
	listener.free()


func test_reconfiguration_detaches_old_emitter_and_reads_live_preferences() -> void:
	var old_events: EVENTS_SCRIPT = _events()
	var events: EVENTS_SCRIPT = _events()
	var save: SAVE_SCRIPT = _save()
	var fake: HapticsFake = HapticsFake.new()
	var platform: PLATFORM_SCRIPT = _platform(fake)
	var listener: HapticsListener = _listener(old_events, save, platform)
	listener.configure(events, save, platform)
	assert_eq(old_events.tile_touched.get_connections().size(), 0)
	old_events.tile_touched.emit(0)
	assert_eq(fake.calls.entries.size(), 0)
	events.tile_touched.emit(0)
	assert_eq(fake.calls.entries.size(), 1)
	assert_eq(save.set_setting(&"haptics_enabled", false), OK)
	events.word_found.emit("KOT")
	assert_eq(fake.calls.entries.size(), 1)
	assert_eq(save.set_setting(&"haptics_enabled", true), OK)
	var replacement: HapticsFake = HapticsFake.new()
	platform.haptics = replacement
	events.word_found.emit("KOT")
	assert_eq(fake.calls.entries.size(), 1)
	assert_eq(replacement.calls.entries.size(), 1, "reads current adapter after replacement")


func test_null_owners_and_detached_listener_emit_no_effects() -> void:
	var events: EVENTS_SCRIPT = _events()
	var listener: HapticsListener = _listener(events, null, null)
	events.tile_touched.emit(0)
	var fake: HapticsFake = HapticsFake.new()
	var save: SAVE_SCRIPT = _save()
	listener.configure(events, save, _platform(fake))
	remove_child(listener)
	events.word_found.emit("KOT")
	assert_eq(fake.calls.entries.size(), 0)
	add_child(listener)
	events.word_found.emit("KOT")
	assert_eq(fake.calls.entries.size(), 1)
	listener.configure(null, null, null)
	events.word_found.emit("KOT")
	assert_eq(fake.calls.entries.size(), 1)
	listener.free()
