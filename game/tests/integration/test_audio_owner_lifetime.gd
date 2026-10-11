extends GutTest

const AUDIO_SCRIPT: Script = preload("res://services/audio.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")


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


var _played: Array[StringName] = []


func before_each() -> void:
	_played.clear()


func _save() -> SAVE_SCRIPT:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(FixedClock.new())
	save.configure(MemoryStorage.new())
	assert_eq(save.load(), OK)
	return save


func _audio(save: SAVE_SCRIPT, sink: Callable = Callable()) -> AUDIO_SCRIPT:
	var audio: AUDIO_SCRIPT = AUDIO_SCRIPT.new()
	add_child_autofree(audio)
	audio.configure(save, sink)
	assert_eq(audio.load_cues(), OK)
	return audio


func _record(cue: StringName, _gain: float, _pitch: float) -> void:
	_played.append(cue)


func test_destroyed_settings_owner_suppresses_new_play_requests() -> void:
	var save: SAVE_SCRIPT = _save()
	var audio: AUDIO_SCRIPT = _audio(save, _record)
	assert_true(audio.play(&"tile_touch"))
	assert_eq(_played.size(), 1)
	save.free()
	assert_false(audio.play(&"word_valid"))
	assert_eq(_played.size(), 1, "destroyed settings owner must not invoke sink")
	audio.free()


func test_replace_destroyed_owner_restores_live_settings_once() -> void:
	var save: SAVE_SCRIPT = _save()
	var audio: AUDIO_SCRIPT = _audio(save, _record)
	save.free()
	var replacement: SAVE_SCRIPT = _save()
	audio.configure(replacement, _record)
	assert_eq(replacement.setting_changed.get_connections().size(), 1)
	assert_true(audio.play(&"word_valid"))
	assert_eq(_played, [&"word_valid"])
	assert_eq(replacement.set_setting(&"sfx_volume", 0.0), OK)
	assert_false(audio.play(&"word_valid"))
	assert_eq(_played.size(), 1)
	audio.configure(replacement, _record)
	assert_eq(replacement.setting_changed.get_connections().size(), 1)
	assert_eq(replacement.set_setting(&"sfx_volume", 1.0), OK)
	assert_true(audio.play(&"word_bonus"))
	assert_eq(_played, [&"word_valid", &"word_bonus"])
	audio.free()
	assert_eq(replacement.setting_changed.get_connections().size(), 0)


func test_null_configuration_after_destroyed_owner_and_bounded_voices() -> void:
	var save: SAVE_SCRIPT = _save()
	var audio: AUDIO_SCRIPT = _audio(save)
	assert_eq(audio.get_child_count(), 8)
	assert_true(audio.play(&"tile_touch"))
	save.free()
	assert_false(audio.play(&"tile_touch"))
	audio.configure(null)
	assert_false(audio.play(&"tile_touch"))
	assert_eq(audio.get_child_count(), 8)
	var replacement: SAVE_SCRIPT = _save()
	audio.configure(replacement)
	for index: int in 24:
		assert_true(audio.play(&"word_valid"))
	assert_eq(audio.get_child_count(), 8)
	replacement.free()
	audio.free()
