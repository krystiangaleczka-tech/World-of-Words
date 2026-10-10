extends GutTest

const AUDIO_SCRIPT: Script = preload("res://services/audio.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const PATH: String = "user://t0133-save.json"
const BAD: String = "user://t0133-cues.json"
const CUES: Array[StringName] = [
	&"tile_touch", &"word_valid", &"word_bonus", &"word_already", &"word_invalid", &"level_complete"
]


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1_790_000_000


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
		DirAccess.remove_absolute(PATH + "-other" + suffix)
	DirAccess.remove_absolute(BAD)


func _save(path: String = PATH) -> SAVE_SCRIPT:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(FixedClock.new())
	save.configure(
		SaveStorage.new(path), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert_eq(save.load(), OK)
	return save


func _audio(save: SAVE_SCRIPT, sink: Callable = Callable()) -> AUDIO_SCRIPT:
	var audio: AUDIO_SCRIPT = AUDIO_SCRIPT.new()
	add_child_autofree(audio)
	audio.configure(save, sink)
	assert_eq(audio.load_cues(), OK)
	return audio


func test_imported_cues_gain_pitch_and_live_mute() -> void:
	var save: SAVE_SCRIPT = _save()
	var played: Array[Dictionary] = []
	var audio: AUDIO_SCRIPT = _audio(
		save,
		func(cue: StringName, gain: float, pitch: float) -> void:
			played.append({"cue": cue, "gain": gain, "pitch": pitch})
	)
	assert_eq(save.set_setting(&"sfx_volume", 0.5), OK)
	for cue: StringName in CUES:
		assert_true(audio.play(cue))
	assert_eq(played.size(), CUES.size())
	assert_almost_eq(float(played[0]["gain"]), db_to_linear(-12.0) * 0.5, 0.00001)
	assert_eq(played[0]["pitch"], 1.0)
	assert_eq(played[4]["gain"], db_to_linear(-18.0) * 0.5)
	assert_false(audio.play(&"unknown"))
	assert_eq(save.set_setting(&"sfx_volume", 0.0), OK)
	assert_false(audio.play(&"tile_touch"))
	assert_eq(played.size(), 6)
	assert_eq(save.set_setting(&"sfx_volume", 1.0), OK)
	assert_true(audio.play(&"tile_touch"))


func test_real_voices_are_bounded_and_update_on_setting_changes() -> void:
	var save: SAVE_SCRIPT = _save()
	var audio: AUDIO_SCRIPT = _audio(save)
	for _index: int in 40:
		assert_true(audio.play(&"word_valid"))
	assert_eq(audio.get_child_count(), 8)
	assert_eq(save.set_setting(&"sfx_volume", 0.25), OK)
	for child: Node in audio.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		assert_true(player.stream is AudioStreamWAV)
		assert_almost_eq(player.volume_linear, db_to_linear(-12.0) * 0.25, 0.00001)
	assert_eq(save.set_setting(&"sfx_volume", 0.0), OK)
	for child: Node in audio.get_children():
		assert_false((child as AudioStreamPlayer).playing)
	var replacement: SAVE_SCRIPT = _save(PATH + "-other")
	audio.configure(replacement)
	assert_eq(save.setting_changed.get_connections().size(), 0)
	assert_eq(save.set_setting(&"sfx_volume", 0.5), OK)
	assert_true(audio.play(&"word_valid"))
	assert_eq(replacement.set_setting(&"sfx_volume", 0.0), OK)
	assert_false(audio.play(&"word_valid"))


func test_unready_and_invalid_reload_preserve_existing_cues() -> void:
	var audio: AUDIO_SCRIPT = AUDIO_SCRIPT.new()
	add_child_autofree(audio)
	assert_false(audio.play(&"tile_touch"))
	audio.configure(_save())
	assert_false(audio.play(&"tile_touch"))
	assert_eq(audio.load_cues(), OK)
	assert_eq(audio.load_cues("user://t0133-missing.json"), ERR_FILE_NOT_FOUND)
	for document: Variant in [
		[],
		{"schema_version": true},
		{
			"schema_version": 1,
			"max_voices": 8,
			"cues": {"bad": {"files": ["res://wrong.wav"], "volume_db": -12, "pitch_scale": 1}}
		}
	]:
		var file: FileAccess = FileAccess.open(BAD, FileAccess.WRITE)
		file.store_string(JSON.stringify(document))
		file.close()
		assert_eq(audio.load_cues(BAD), ERR_INVALID_DATA)
		assert_true(audio.play(&"tile_touch"))
	assert_eq(audio.get_child_count(), 8)
	var partial: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(AUDIO_SCRIPT.REGISTRY)
	)
	partial["cues"]["word_invalid"]["files"] = ["res://assets/audio/p1/missing.wav"]
	var file: FileAccess = FileAccess.open(BAD, FileAccess.WRITE)
	file.store_string(JSON.stringify(partial))
	file.close()
	assert_eq(audio.load_cues(BAD), ERR_FILE_NOT_FOUND)
	assert_true(audio.play(&"word_valid"), "failed partial preload retains old cues")
	assert_eq(audio.get_child_count(), 8)
