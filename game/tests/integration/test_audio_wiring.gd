extends GutTest

const AUDIO_SCRIPT: Script = preload("res://services/audio.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const LISTENER: Script = preload("res://services/audio/audio_listener.gd")

var _played: Array[StringName] = []
var _save: SAVE_SCRIPT
var _audio: AUDIO_SCRIPT
var _events: EVENTS_SCRIPT
var _content: CONTENT_SCRIPT
var _storage: MemoryStorage


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)
	var fail: bool = false

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		if fail:
			return ERR_FILE_CANT_WRITE
		document = JSON.parse_string(text)
		return OK


func before_each() -> void:
	_played.clear()
	_storage = MemoryStorage.new()
	_save = SAVE_SCRIPT.new()
	_audio = AUDIO_SCRIPT.new()
	_events = EVENTS_SCRIPT.new()
	_content = CONTENT_SCRIPT.new()
	for service: Node in [_save, _audio, _events, _content]:
		add_child_autofree(service)
	_save.initialize(FixedClock.new())
	_save.configure(_storage)
	assert_eq(_save.load(), OK)
	_audio.configure(_save, _capture)
	assert_eq(_audio.load_cues(), OK)
	assert_eq(_content.load_manifest("pl", "res://tests/fixtures/content"), OK)


func _capture(cue: StringName, _gain: float, _pitch: float) -> void:
	_played.append(cue)


func _listener() -> Node:
	var listener: Node = LISTENER.new()
	listener.configure(_events, _audio)
	add_child_autofree(listener)
	return listener


func _all(events: EVENTS_SCRIPT) -> void:
	events.tile_touched.emit(0)
	events.word_found.emit("DOM")
	events.bonus_found.emit("DAM")
	events.already_found.emit("DOM")
	events.invalid_word.emit("XYZ")
	events.level_completed.emit(2)
	events.hint_used.emit()


func test_mapping_mute_replacement_exit_and_reentry() -> void:
	var listener: Node = _listener()
	listener.configure(_events, _audio)
	_all(_events)
	var expected: Array[StringName] = [
		&"tile_touch",
		&"word_valid",
		&"word_bonus",
		&"word_already",
		&"word_invalid",
		&"level_complete"
	]
	assert_eq(_played, expected, "exactly six registered cues; hint has no cue")
	assert_eq(_save.set_setting(&"sfx_volume", 0.0), OK)
	_all(_events)
	assert_eq(_played, expected)
	assert_eq(_save.set_setting(&"sfx_volume", 1.0), OK)
	var replacement: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	add_child_autofree(replacement)
	listener.configure(replacement, _audio)
	_all(_events)
	assert_eq(_played, expected, "old bus disconnected")
	remove_child(listener)
	_all(replacement)
	assert_eq(_played, expected, "exit disconnects")
	add_child(listener)
	_all(replacement)
	assert_eq(_played.size(), 12, "reentry attaches once")
	for event: String in [
		"tile_touched",
		"word_found",
		"bonus_found",
		"already_found",
		"invalid_word",
		"level_completed"
	]:
		assert_eq(_events.get_signal_connection_list(event).size(), 0)


func _scene(slot: int) -> LevelScreen:
	var progress: Dictionary = _save.get_section(&"progress")
	progress["by_lang"]["pl"]["current_slot"] = slot
	assert_eq(_save.set_section(&"progress", progress), OK)
	assert_eq(_save.flush(), OK)
	var screen: LevelScreen = load("res://features/level/level.tscn").instantiate()
	screen.configure(_save, _content, slot, _events)
	add_child_autofree(screen)
	return screen


func test_real_level_effects_and_short_attempts() -> void:
	_listener()
	var screen: LevelScreen = _scene(2)
	screen.wheel.pointer_begin(0, screen.wheel.tile_position(0))
	screen.wheel.pointer_end(0, true)
	assert_eq(_played, [&"tile_touch"])
	assert_null(screen.controller.submit(PackedInt32Array([0, 1])))
	assert_eq(_played.size(), 1, "short attempt has no result sound")
	assert_not_null(screen.controller.submit(PackedInt32Array([0, 1, 2])))
	assert_not_null(screen.controller.submit(PackedInt32Array([0, 3, 2])))
	assert_not_null(screen.controller.submit(PackedInt32Array([0, 1, 2])))
	assert_not_null(screen.controller.submit(PackedInt32Array([1, 0, 2])))
	assert_not_null(screen.controller.submit(PackedInt32Array([2, 1, 0, 3])))
	assert_eq(
		_played,
		[
			&"tile_touch",
			&"word_valid",
			&"word_bonus",
			&"word_already",
			&"word_invalid",
			&"level_complete",
			&"word_valid"
		]
	)
	assert_true(screen.controller.is_complete())
	assert_null(screen.controller.submit(PackedInt32Array([0, 1, 2])))
	assert_eq(_played.size(), 7, "completed board stays quiet")


func test_failed_durability_is_quiet_and_retry_emits_once() -> void:
	_listener()
	var screen: LevelScreen = _scene(1)
	_storage.fail = true
	assert_null(screen.controller.submit(PackedInt32Array([0, 1, 2])))
	assert_eq(_played.size(), 0, "failed save has no success/completion")
	_storage.fail = false
	assert_not_null(screen.controller.submit(PackedInt32Array([2, 1, 0])))
	assert_eq(_played, [&"level_complete", &"word_valid"])
	assert_null(screen.controller.submit(PackedInt32Array([0, 1, 2])))
	assert_eq(_played.size(), 2)


func test_boot_wires_audio_and_level_copy_is_imported() -> void:
	Nav.configure(Save, Config, Content)
	Nav.configure_screens(Callable())
	var boot: Node = load("res://services/nav/boot.tscn").instantiate()
	boot.content_root = "res://tests/fixtures/content"
	add_child_autofree(boot)
	Audio.configure(Save, _capture)
	var screen: LevelScreen = Nav.mounted_screen() as LevelScreen
	assert_not_null(screen)
	assert_true(boot.has_node("AudioListener"))
	screen.wheel.pointer_begin(0, screen.wheel.tile_position(0))
	assert_eq(_played, [&"tile_touch"], "real boot listener observes real Level input")
	screen.wheel.pointer_end(0, true)
	var copy: LevelCopy = LevelCopy.new()
	copy.register()
	for locale: String in ["pl", "en"]:
		TranslationServer.set_locale(locale)
		var file: FileAccess = FileAccess.open("res://locale/level.csv", FileAccess.READ)
		file.get_csv_line()
		while not file.eof_reached():
			var row: PackedStringArray = file.get_csv_line()
			if row.size() != 3:
				continue
			assert_eq(TranslationServer.translate(row[0]), row[1 if locale == "pl" else 2])
		assert_eq(
			screen.level_label.text,
			TranslationServer.translate("level.hud.level_n") % Nav.level_slot()
		)
	copy.unregister()
	TranslationServer.set_locale("pl")
	Audio.configure(Save)
