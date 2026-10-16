extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const AUDIO: Script = preload("res://services/audio.gd")
const EVENT_BUS: Script = preload("res://services/events.gd")
const PLATFORM: Script = preload("res://platform/platform.gd")
const FIXTURE: Script = preload("res://tests/integration/test_level_hud.gd")
const ATOMIC: Script = preload("res://tests/integration/test_save_atomic.gd")
const SCENE: PackedScene = preload("res://features/settings/settings_screen.tscn")
var save: SAVE
var storage: SaveStorage
var runtime: SettingsRuntime
var root: Control
var _motion: bool
var _locale: String
var _pseudo: bool


class InitialStorage:
	extends "res://tests/integration/test_level_hud.gd".MemoryStorage

	func has_any_file() -> bool:
		return not document.is_empty()


class RecoveryStorage:
	extends "res://tests/integration/test_level_hud.gd".MemoryStorage

	func read_document(suffix: String = "") -> Dictionary:
		return document.duplicate(true) if suffix == ".bak" else {}


func before_each() -> void:
	_motion = Tokens.reduced_motion
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	storage = FIXTURE.MemoryStorage.new()
	save = SAVE.new()
	add_child_autofree(save)
	save.initialize(Clock.new())
	save.configure(storage)
	assert_eq(save.load(), OK)
	root = Control.new()
	add_child_autofree(root)
	runtime = SettingsRuntime.new()
	add_child_autofree(runtime)
	assert_eq(runtime.configure(save, root), OK)


func after_each() -> void:
	Tokens.reduced_motion = _motion
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo


func test_failed_write_keeps_applied_state_and_exact_retry() -> void:
	storage.set("fail", true)
	watch_signals(runtime)
	assert_eq(runtime.set_value(&"high_contrast", true), ERR_FILE_CANT_WRITE)
	assert_true(save.get_setting(&"high_contrast"))
	assert_false(runtime.snapshot().high_contrast)
	assert_eq(root.theme.resource_path, "res://ui/theme/generated/theme_default_100.tres")
	assert_signal_emit_count(runtime, "write_failed", 1)
	assert_eq(runtime.set_value(&"text_scale", 2), ERR_BUSY)
	assert_eq(runtime.configure(save, root), ERR_BUSY)
	storage.set("fail", false)
	assert_eq(runtime.retry(), OK)
	assert_true(runtime.snapshot().high_contrast)
	assert_eq(runtime.snapshot().text_scale, 0)
	assert_signal_emit_count(runtime, "changed", 1)
	assert_eq(runtime.retry(), ERR_DOES_NOT_EXIST)
	var copy: Dictionary = runtime.snapshot()
	copy.high_contrast = false
	assert_true(runtime.snapshot().high_contrast)


func test_other_flush_resolves_pending_and_external_winner_cannot_be_overwritten() -> void:
	storage.set("fail", true)
	assert_ne(runtime.set_value(&"music_volume", 0.2), OK)
	storage.set("fail", false)
	assert_eq(save.flush(), OK)
	assert_eq(runtime.snapshot().music_volume, 0.2)
	assert_eq(runtime.retry(), ERR_DOES_NOT_EXIST)
	storage.set("fail", true)
	assert_ne(runtime.set_value(&"music_volume", 0.8), OK)
	storage.set("fail", false)
	assert_eq(save.set_setting(&"music_volume", 0.2), OK)
	assert_eq(runtime.retry(), ERR_DOES_NOT_EXIST)
	assert_eq(runtime.snapshot().music_volume, 0.2)


func test_invalid_language_values_and_reentrant_replacement_are_rejected() -> void:
	assert_eq(runtime.set_value(&"language", "en"), ERR_INVALID_PARAMETER)
	assert_eq(runtime.set_value(&"text_scale", 3), ERR_INVALID_DATA)
	assert_eq(runtime.set_value(&"music_volume", NAN), ERR_INVALID_DATA)
	var results: Array[Error] = []
	runtime.changed.connect(
		func() -> void:
			results.append(runtime.set_value(&"sfx_volume", 0.5))
			results.append(runtime.configure(save, root))
			results.append(runtime.retry())
	)
	assert_eq(runtime.set_value(&"reduced_motion", true), OK)
	assert_eq(results, [ERR_BUSY, ERR_BUSY, ERR_BUSY])
	assert_eq(runtime.snapshot().sfx_volume, 1.0)
	assert_true(Tokens.reduced_motion)


func test_all_six_themes_and_lifecycle_apply_only_committed_notifications() -> void:
	for hc: bool in [false, true]:
		assert_eq(runtime.set_value(&"high_contrast", hc), OK)
		for scale: int in range(3):
			assert_eq(runtime.set_value(&"text_scale", scale), OK)
			assert_eq(
				root.theme.resource_path,
				(
					"res://ui/theme/generated/theme_%s_%s.tres"
					% ["hc" if hc else "default", ["100", "115", "130"][scale]]
				)
			)
	remove_child(runtime)
	assert_eq(save.set_setting(&"reduced_motion", true), OK)
	assert_false(Tokens.reduced_motion)
	add_child(runtime)
	assert_true(Tokens.reduced_motion)
	watch_signals(runtime)
	assert_eq(save.set_setting(&"reduced_motion", false), OK)
	assert_signal_emit_count(runtime, "changed", 1)


func test_audio_music_and_haptics_ignore_failed_dirty_values() -> void:
	var audio: AUDIO = AUDIO.new()
	add_child_autofree(audio)
	var heard: Array[float] = []
	audio.configure(
		save, func(_cue: StringName, gain: float, _pitch: float) -> void: heard.append(gain)
	)
	assert_eq(audio.load_cues(), OK)
	var music: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child_autofree(music)
	assert_eq(audio.bind_music(music), OK)
	assert_eq(audio.bind_music(null), ERR_INVALID_PARAMETER)
	assert_false(music.playing)
	var bus: EVENT_BUS = EVENT_BUS.new()
	add_child_autofree(bus)
	var platform: PLATFORM = PLATFORM.new()
	var haptics: HapticsFake = HapticsFake.new()
	platform.haptics = haptics
	add_child_autofree(platform)
	var listener: HapticsListener = HapticsListener.new()
	listener.configure(bus, save, platform)
	add_child_autofree(listener)
	assert_true(audio.play(&"tile_touch"))
	var initial: float = heard.back()
	storage.set("fail", true)
	assert_ne(save.set_setting(&"sfx_volume", 0.0), OK)
	assert_ne(save.set_setting(&"music_volume", 0.0), OK)
	assert_ne(save.set_setting(&"haptics_enabled", false), OK)
	assert_true(audio.play(&"tile_touch"))
	assert_eq(heard.back(), initial)
	assert_almost_eq(music.volume_linear, float(runtime.snapshot().music_volume), 0.0001)
	bus.tile_touched.emit(0)
	assert_eq(haptics.calls.entries.size(), 1)
	storage.set("fail", false)
	assert_eq(save.flush(), OK)
	assert_false(audio.play(&"tile_touch"))
	assert_eq(music.volume_linear, 0.0)
	bus.tile_touched.emit(0)
	assert_eq(haptics.calls.entries.size(), 1)
	music.stream = load("res://assets/audio/p1/tile_touch.wav")
	music.play()
	audio.set_ad_paused(true)
	assert_true(music.stream_paused)
	audio.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	audio.set_ad_paused(false)
	assert_true(music.stream_paused)
	audio.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_false(music.stream_paused)
	assert_true(music.playing)
	music.stop()


func _new_save(
	document: Dictionary, motion: bool, language: String, recovery: bool = false
) -> SAVE:
	var owner: SAVE = SAVE.new()
	add_child_autofree(owner)
	owner.initialize(Clock.new())
	var memory: SaveStorage = RecoveryStorage.new() if recovery else InitialStorage.new()
	memory.set("document", document)
	owner.configure(memory, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert_eq(owner.configure_system_defaults(motion, language), OK)
	assert_eq(owner.load(), OK)
	assert_eq(owner.configure_system_defaults(false), ERR_ALREADY_IN_USE)
	return owner


func test_system_defaults_only_affect_fresh_install_not_loaded_or_migrated() -> void:
	var fresh: SAVE = _new_save({}, true, "en")
	assert_true(fresh.get_setting(&"reduced_motion"))
	assert_eq(fresh.get_setting(&"language"), "en")
	var existing: SAVE = _new_save(storage.get("document"), true, "en")
	assert_false(existing.get_setting(&"reduced_motion"))
	assert_eq(existing.get_setting(&"language"), "pl")
	var legacy: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/save/v3.json")
	)
	var migrated: SAVE = _new_save(legacy, true, "en")
	assert_eq(migrated.get_setting(&"reduced_motion"), legacy.settings.reduced_motion)
	assert_eq(migrated.get_setting(&"language"), legacy.settings.language)
	var recovered: SAVE = _new_save(storage.get("document"), true, "en", true)
	assert_false(recovered.get_setting(&"reduced_motion"))
	assert_eq(recovered.get_setting(&"language"), "pl")
	var unloaded: SAVE = SAVE.new()
	assert_eq(unloaded.configure_system_defaults(false, ""), ERR_INVALID_PARAMETER)
	unloaded.free()


func test_screen_toggle_slider_release_retry_and_text_sheet_reentry() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1080, 1920)
	add_child_autofree(view)
	var screen: SettingsScreen = SCENE.instantiate()
	assert_eq(screen.configure(save), OK)
	assert_eq(screen.bind_runtime(runtime), OK)
	view.add_child(screen)
	assert_eq(runtime.configure(save, screen), OK)
	assert_eq(runtime.set_value(&"reduced_motion", true), OK)
	storage.set("fail", true)
	(screen.controls[&"high_contrast"] as Toggle).value_changed.emit(true)
	assert_false(screen.controls[&"high_contrast"].value)
	assert_true(screen.retry_button.visible)
	storage.set("fail", false)
	screen.retry_button.pressed.emit()
	assert_true(screen.controls[&"high_contrast"].value)
	assert_false(screen.retry_button.visible)
	var slider: CatalogSlider = screen.controls[&"sfx_volume"]
	for frame: int in range(3):
		await get_tree().process_frame
	slider.grab_focus()
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_LEFT
	press.pressed = true
	view.push_input(press)
	assert_eq(runtime.snapshot().sfx_volume, 1.0)
	press = press.duplicate()
	press.pressed = false
	view.push_input(press)
	assert_almost_eq(runtime.snapshot().sfx_volume, 0.9, 0.0001)
	view.remove_child(screen)
	view.add_child(screen)
	for frame: int in range(3):
		await get_tree().process_frame
	watch_signals(runtime)
	screen.rows[&"text_size"].pressed.emit()
	assert_eq(screen.text_options.size(), 3)
	assert_eq(screen.text_sheet.state, &"open")
	screen.text_options[2].pressed.emit()
	assert_eq(runtime.snapshot().text_scale, 2)
	assert_eq(screen.text_sheet.state, &"closed")
	assert_signal_emit_count(runtime, "changed", 1)


func test_native_text_sheet_twelve_case_matrix() -> void:
	for option: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + option, GalleryShell.OPTIONS[option])
	TranslationServer.reload_pseudolocalization()
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				TranslationServer.pseudolocalization_enabled = pseudo
				var view: SubViewport = SubViewport.new()
				view.size = dimensions
				add_child_autofree(view)
				var screen: SettingsScreen = SCENE.instantiate()
				assert_eq(screen.configure(save), OK)
				assert_eq(screen.bind_runtime(runtime), OK)
				view.add_child(screen)
				assert_eq(runtime.configure(save, screen), OK)
				assert_eq(runtime.set_value(&"high_contrast", hc), OK)
				assert_eq(runtime.set_value(&"text_scale", 2 if hc else 0), OK)
				assert_eq(runtime.set_value(&"reduced_motion", true), OK)
				screen.rows[&"text_size"].pressed.emit()
				for frame: int in range(5):
					await get_tree().process_frame
				assert_eq(screen.text_sheet.state, &"open")
				for option: TextButton in screen.text_options:
					assert_true(option.is_visible_in_tree())
					assert_gte(option.size.y, float(Tokens.Touch.MIN_TARGET))
					assert_lte(option.get_global_rect().end.x, float(dimensions.x))
				screen.text_sheet.close()
				screen.scroll.scroll_vertical = int(screen.scroll.get_v_scroll_bar().max_value)
				await get_tree().process_frame
				assert_gt(screen.scroll.scroll_vertical, 0)
				screen.free()


func test_atomic_lease_rejects_write_until_explicit_retry() -> void:
	var owner: SAVE = SAVE.new()
	add_child_autofree(owner)
	owner.initialize(Clock.new())
	owner.configure(FIXTURE.MemoryStorage.new())
	var progress: AtomicSaveOwner = ATOMIC.TestProgress.new()
	var economy: AtomicSaveOwner = ATOMIC.TestEconomy.new()
	add_child_autofree(progress)
	add_child_autofree(economy)
	progress.set("save", owner)
	economy.set("save", owner)
	assert_eq(owner.configure_atomic(progress, economy), OK)
	assert_eq(owner.load(), OK)
	assert_eq(runtime.configure(owner, root), OK)
	var lease: Dictionary = owner.begin_transaction(_request(owner))
	assert_eq(lease.error, OK)
	assert_eq(runtime.set_value(&"high_contrast", true), ERR_BUSY)
	assert_false(runtime.snapshot().high_contrast)
	assert_eq(owner.abort_transaction(lease.transaction), OK)
	assert_eq(runtime.retry(), OK)
	assert_true(runtime.snapshot().high_contrast)


func _request(owner: SAVE) -> Dictionary:
	var state: Dictionary = owner.get_section(&"progress").by_lang.pl
	var domain: Dictionary = {
		"current_slot": state.current_slot,
		"stars": state.stars,
		"location_stars": state.location_stars,
		"location_pieces": state.location_pieces,
		"completed_locations": state.postcards,
		"unlocked": state.unlocked
	}
	var candidate: Dictionary = domain.duplicate(true)
	candidate.current_slot += 1
	candidate.stars += 1
	return {
		"operation_id": "campaign_complete:pl:%d" % state.current_slot,
		"kind": "campaign_complete",
		"language": "pl",
		"context":
		{
			"content_version": 1,
			"manifest_hash": "a".repeat(64),
			"level_id": "pl-test",
			"slot": state.current_slot,
			"expected_current_slot": state.current_slot,
			"expected_highest_completed_slot": state.highest_completed_slot,
			"board_hash": "b".repeat(64),
			"expected_progress_hash": AtomicRequest.hash_value(domain)
		},
		"progress_candidate": candidate,
		"economy_commands":
		[{"operation": "grant", "reason": "level_complete", "amounts": {"coins": 1}}],
		"delta": {"stars": 1}
	}


func test_screen_keeps_retry_after_unrelated_commit_and_resolves_on_owner_flush() -> void:
	var screen: SettingsScreen = SCENE.instantiate()
	assert_eq(screen.configure(save), OK)
	assert_eq(screen.bind_runtime(runtime), OK)
	add_child_autofree(screen)
	storage.set("fail", true)
	(screen.controls[&"high_contrast"] as Toggle).value_changed.emit(true)
	assert_true(screen.retry_button.visible)
	for frame: int in range(3):
		await get_tree().process_frame
	assert_true(screen.scroll.get_global_rect().intersects(screen.retry_button.get_global_rect()))
	assert_true(screen.controls[&"high_contrast"].disabled)
	# Another failed owner intent doesn't replace the runtime candidate.
	assert_ne(save.set_setting(&"music_volume", 0.2), OK)
	storage.set("fail", false)
	assert_eq(save.flush(), OK)
	assert_false(screen.retry_button.visible)
	assert_false(screen.controls[&"high_contrast"].disabled)
	assert_true(screen.controls[&"high_contrast"].value)
	assert_eq(runtime.retry(), ERR_DOES_NOT_EXIST)


func test_detached_runtime_discards_a_committed_external_winner_on_reentry() -> void:
	storage.set("fail", true)
	assert_ne(runtime.set_value(&"music_volume", 0.2), OK)
	remove_child(runtime)
	storage.set("fail", false)
	assert_eq(save.set_setting(&"music_volume", 0.8), OK)
	add_child(runtime)
	assert_eq(runtime.retry(), ERR_DOES_NOT_EXIST)
	assert_eq(runtime.snapshot().music_volume, 0.8)
