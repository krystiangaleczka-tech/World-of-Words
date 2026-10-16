extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const CONTENT: Script = preload("res://services/content.gd")
const FIXTURE: Script = preload("res://tests/integration/test_level_hud.gd")
const SCENE: PackedScene = preload("res://features/settings/settings_screen.tscn")
const ROOT: String = "res://tests/fixtures/settings/content"
var save: SAVE
var content: CONTENT
var storage: SaveStorage
var selector: SettingsLanguage
var safe: bool
var apply_error: Error
var calls: Array[StringName]
var _locale: String
var _motion: bool
var _pseudo: bool


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_motion = Tokens.reduced_motion
	_pseudo = TranslationServer.pseudolocalization_enabled
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	Tokens.reduced_motion = true
	safe = true
	apply_error = OK
	calls = []
	storage = FIXTURE.MemoryStorage.new()
	save = SAVE.new()
	add_child_autofree(save)
	save.initialize(Clock.new())
	save.configure(storage)
	assert_eq(save.load(), OK)
	content = CONTENT.new()
	add_child_autofree(content)
	assert_eq(content.load_manifest("pl"), OK)
	selector = SettingsLanguage.new()
	add_child_autofree(selector)
	assert_eq(selector.configure(save, content, _reload), OK)


func after_each() -> void:
	# Dispose preview before restoring the surrounding locale.
	if is_instance_valid(selector) and selector.get_parent() != null:
		selector.get_parent().remove_child(selector)
	TranslationServer.set_locale(_locale)
	Tokens.reduced_motion = _motion
	TranslationServer.pseudolocalization_enabled = _pseudo


func _reload(phase: StringName, target: String) -> Error:
	calls.append(phase)
	if phase == &"prepare":
		return save.flush() if safe else ERR_BUSY
	if apply_error != OK:
		return apply_error
	return content.load_manifest(target, ROOT)


func _alternatives() -> void:
	assert_eq(content.load_manifest("pl", ROOT), OK)
	assert_eq(selector.configure(save, content, _reload, ROOT), OK)


func test_real_manifest_discovery_production_filter_and_copies() -> void:
	assert_eq(selector.choices().map(func(choice: Dictionary) -> String: return choice.id), ["pl"])
	assert_eq(selector.select("preview_en"), ERR_UNAVAILABLE)
	assert_eq(selector.select("en"), ERR_INVALID_PARAMETER)
	_alternatives()
	assert_eq(
		selector.choices().map(func(choice: Dictionary) -> String: return choice.id), ["en", "pl"]
	)
	var copy: Array[Dictionary] = selector.choices()
	copy[0].id = "corrupted"
	assert_eq(selector.choices()[0].id, "en")
	assert_eq(selector.select("de"), ERR_INVALID_PARAMETER)
	var candidate: CONTENT = CONTENT.new()
	assert_eq(candidate.load_manifest("en", ROOT), OK)
	assert_not_null(candidate.level_for_slot(1))
	candidate.free()


func test_debug_preview_is_transient_and_never_changes_save_or_content() -> void:
	assert_eq(selector.configure(save, content, _reload, "res://content", true), OK)
	var before: Dictionary = save.committed_view()
	var hash: String = content.manifest_hash()
	assert_eq(selector.select("preview_en"), OK)
	assert_eq(TranslationServer.get_locale(), "en")
	assert_true(selector.snapshot().preview)
	assert_eq(selector.snapshot().language, "pl")
	assert_eq(selector.snapshot().ui_language, "en")
	assert_eq_deep(save.committed_view(), before)
	assert_eq(content.get_language(), "pl")
	assert_eq(content.manifest_hash(), hash)
	assert_true(calls.is_empty())
	assert_eq(selector.choices().back().id, "restore_preview")
	assert_eq(selector.select("restore_preview"), OK)
	assert_eq(TranslationServer.get_locale(), "pl")
	assert_eq(selector.select("preview_en"), OK)
	remove_child(selector)
	assert_eq(TranslationServer.get_locale(), "pl")
	add_child(selector)
	assert_false(selector.snapshot().preview)
	assert_eq_deep(save.committed_view(), before)


func test_initial_device_locale_is_filtered_before_fresh_defaults_only() -> void:
	assert_eq(SettingsLanguage.initial_language("en-US"), "pl")
	assert_eq(SettingsLanguage.initial_language("pl_PL"), "pl")
	assert_eq(SettingsLanguage.initial_language("en_US", ROOT), "en")
	assert_eq(SettingsLanguage.initial_language("de_DE", ROOT), "pl")
	assert_eq(SettingsLanguage.initial_language("", ROOT), "pl")
	var fresh: SAVE = SAVE.new()
	add_child_autofree(fresh)
	fresh.initialize(Clock.new())
	var empty: SaveStorage = InitialStorage.new()
	fresh.configure(empty, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert_eq(SettingsLanguage.configure_initial_defaults(fresh, true, "en_GB", ROOT), OK)
	assert_eq(fresh.load(), OK)
	assert_eq(fresh.get_setting(&"language"), "en")
	assert_true(fresh.get_setting(&"reduced_motion"))
	assert_eq(
		SettingsLanguage.configure_initial_defaults(save, true, "en_US", ROOT), ERR_ALREADY_IN_USE
	)
	assert_eq(save.get_setting(&"language"), "pl")


class InitialStorage:
	extends "res://tests/integration/test_level_hud.gd".MemoryStorage

	func _init() -> void:
		document = {}

	func has_any_file() -> bool:
		return not document.is_empty()


func test_unsafe_reload_rejects_without_persisting_then_retries_same_target() -> void:
	_alternatives()
	safe = false
	var before: Dictionary = save.committed_view()
	assert_eq(selector.select("en"), ERR_BUSY)
	assert_eq(selector.snapshot().state, &"prepare_failed")
	assert_eq(selector.snapshot().pending, "en")
	assert_eq(selector.snapshot().language, "pl")
	assert_eq_deep(save.committed_view(), before)
	assert_eq(content.get_language(), "pl")
	assert_eq(selector.select("pl"), ERR_BUSY)
	safe = true
	assert_eq(selector.retry(), OK)
	assert_eq(selector.snapshot().state, &"ready")
	assert_eq(content.get_language(), "en")
	assert_eq(TranslationServer.get_locale(), "en")


func test_failed_write_and_other_flush_never_claim_reload_success() -> void:
	_alternatives()
	storage.set("fail", true)
	assert_eq(selector.select("en"), ERR_FILE_CANT_WRITE)
	assert_eq(selector.snapshot().state, &"write_failed")
	assert_eq(save.get_setting(&"language"), "en")
	assert_eq(save.committed_view().sections.settings.language, "pl")
	assert_eq(selector.snapshot().language, "pl")
	assert_eq(content.get_language(), "pl")
	storage.set("fail", false)
	apply_error = ERR_BUSY
	assert_eq(save.flush(), OK)
	for frame: int in range(3):
		await get_tree().process_frame
	assert_eq(save.committed_view().sections.settings.language, "en")
	assert_eq(selector.snapshot().state, &"reload_pending")
	assert_eq(selector.snapshot().language, "pl")
	assert_eq(content.get_language(), "pl")
	assert_eq(TranslationServer.get_locale(), "pl")
	apply_error = OK
	assert_eq(selector.retry(), OK)
	assert_eq(selector.snapshot().language, "en")
	assert_eq(selector.snapshot().pending, "")
	assert_eq(content.get_language(), "en")
	assert_eq(TranslationServer.get_locale(), "en")
	assert_eq(selector.retry(), ERR_DOES_NOT_EXIST)


func test_language_switch_preserves_each_campaign_and_rejects_reentrant_replacement() -> void:
	_alternatives()
	var progress: Dictionary = save.get_section(&"progress")
	progress.by_lang.pl.unlocked = ["hint"]
	progress.by_lang["en"] = progress.by_lang.pl.duplicate(true)
	progress.by_lang.en.unlocked = ["shuffle"]
	assert_eq(save.set_section(&"progress", progress), OK)
	assert_eq(save.flush(), OK)
	var before: Dictionary = save.get_section(&"progress")
	var results: Array[Error] = []
	selector.changed.connect(
		func() -> void:
			results.append(selector.select("pl"))
			results.append(selector.configure(save, content, _reload, ROOT))
	)
	assert_eq(selector.select("en"), OK)
	assert_eq(results, [ERR_BUSY, ERR_BUSY])
	assert_eq_deep(save.get_section(&"progress"), before)
	assert_eq(selector.select("pl"), OK)
	assert_eq_deep(save.get_section(&"progress"), before)
	assert_eq(save.get_setting(&"language"), "pl")


func test_hook_cannot_report_success_without_matching_content() -> void:
	_alternatives()
	assert_eq(
		selector.configure(
			save, content, func(_phase: StringName, _target: String) -> Error: return OK, ROOT
		),
		OK
	)
	assert_eq(selector.select("en"), ERR_INVALID_DATA)
	assert_eq(selector.snapshot().state, &"reload_pending")
	assert_eq(selector.snapshot().language, "pl")
	assert_eq(content.get_language(), "pl")


func test_native_language_sheet_debug_selection_and_reentry() -> void:
	assert_eq(selector.configure(save, content, _reload, "res://content", true), OK)
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1080, 1920)
	add_child_autofree(view)
	var screen: SettingsScreen = SCENE.instantiate()
	assert_eq(screen.configure(save), OK)
	assert_eq(screen.bind_language(selector), OK)
	view.add_child(screen)
	screen.rows[&"language"].pressed.emit()
	assert_eq(screen.language_sheet.state, &"open")
	screen.language_options["preview_en"].pressed.emit()
	assert_true(selector.snapshot().preview)
	assert_eq(screen.rows[&"language"].trailing_value, tr("settings.language.preview_value"))
	assert_eq(save.get_setting(&"language"), "pl")
	view.remove_child(screen)
	view.add_child(screen)
	for frame: int in range(3):
		await get_tree().process_frame
	screen.rows[&"language"].pressed.emit()
	watch_signals(selector)
	screen.language_options["restore_preview"].pressed.emit()
	assert_signal_emit_count(selector, "changed", 1)
	assert_eq(TranslationServer.get_locale(), "pl")


func test_native_language_sheet_twelve_case_matrix() -> void:
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
				assert_eq(screen.bind_language(selector), OK)
				screen.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				view.add_child(screen)
				screen.rows[&"language"].pressed.emit()
				for frame: int in range(4):
					await get_tree().process_frame
				assert_eq(screen.language_options.size(), 1)
				var option: TextButton = screen.language_options["pl"]
				assert_true(option.is_visible_in_tree())
				assert_gte(option.size.y, float(Tokens.Touch.MIN_TARGET))
				assert_lte(option.get_global_rect().end.x, float(dimensions.x))
				screen.back.pressed.emit()
				assert_eq(screen.language_sheet.state, &"closed")
				screen.free()


func test_screen_keeps_previous_language_and_retry_until_reload_succeeds() -> void:
	_alternatives()
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1080, 1920)
	add_child_autofree(view)
	var screen: SettingsScreen = SCENE.instantiate()
	assert_eq(screen.configure(save), OK)
	assert_eq(screen.bind_language(selector), OK)
	view.add_child(screen)
	screen.rows[&"language"].pressed.emit()
	storage.set("fail", true)
	screen.language_options["en"].pressed.emit()
	assert_true(screen.language_retry.visible)
	assert_eq(screen.language_options["pl"].sublabel_key, "settings.language.selected")
	assert_eq(screen.language_options["en"].sublabel_key, "")
	assert_eq(screen.rows[&"language"].trailing_value, tr("settings.language.polish"))
	watch_signals(screen)
	screen.back.pressed.emit()
	assert_eq(screen.language_sheet.state, &"open")
	assert_signal_not_emitted(screen, "back_requested")
	storage.set("fail", false)
	apply_error = ERR_BUSY
	screen.language_retry.pressed.emit()
	assert_eq(selector.snapshot().state, &"reload_pending")
	assert_eq(save.get_setting(&"language"), "en")
	assert_eq(content.get_language(), "pl")
	assert_eq(screen.rows[&"language"].trailing_value, tr("settings.language.polish"))
	apply_error = OK
	screen.language_retry.pressed.emit()
	assert_eq(screen.language_sheet.state, &"closed")
	assert_eq(screen.rows[&"language"].trailing_value, tr("settings.language.english"))
	assert_eq(content.get_language(), "en")


func test_retry_rejects_changed_manifest_identity_without_retargeting() -> void:
	var temporary: String = "user://t0287-content"
	for language: String in ["pl", "en"]:
		assert_eq(DirAccess.make_dir_recursive_absolute(temporary.path_join(language)), OK)
		var output: FileAccess = FileAccess.open(
			temporary.path_join(language).path_join("manifest.json"), FileAccess.WRITE
		)
		output.store_string(
			FileAccess.get_file_as_string(ROOT.path_join(language).path_join("manifest.json"))
		)
		output.close()
	assert_eq(content.load_manifest("pl", temporary), OK)
	assert_eq(selector.configure(save, content, _reload, temporary), OK)
	safe = false
	assert_eq(selector.select("en"), ERR_BUSY)
	var document: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(temporary.path_join("en/manifest.json"))
	)
	document.content_version += 1
	var changed_manifest: FileAccess = FileAccess.open(
		temporary.path_join("en/manifest.json"), FileAccess.WRITE
	)
	changed_manifest.store_string(JSON.stringify(document))
	changed_manifest.close()
	assert_eq(selector.retry(), ERR_INVALID_DATA)
	assert_eq(selector.snapshot().state, &"validation_failed")
	assert_eq(selector.snapshot().pending, "en")
	assert_eq(selector.snapshot().language, "pl")
	assert_eq(save.get_setting(&"language"), "pl")
	for language: String in ["pl", "en"]:
		DirAccess.remove_absolute(temporary.path_join(language).path_join("manifest.json"))
		DirAccess.remove_absolute(temporary.path_join(language))
	DirAccess.remove_absolute(temporary)


func test_debug_english_preview_fits_hc130_in_all_three_layout_classes() -> void:
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			TranslationServer.pseudolocalization_enabled = pseudo
			assert_eq(selector.configure(save, content, _reload, "res://content", true), OK)
			var view: SubViewport = SubViewport.new()
			view.size = dimensions
			add_child_autofree(view)
			var screen: SettingsScreen = SCENE.instantiate()
			assert_eq(screen.configure(save), OK)
			assert_eq(screen.bind_language(selector), OK)
			screen.theme = load("res://ui/theme/generated/theme_hc_130.tres")
			view.add_child(screen)
			screen.rows[&"language"].pressed.emit()
			screen.language_options["preview_en"].pressed.emit()
			for frame: int in range(4):
				await get_tree().process_frame
			for row: ListRow in screen.rows.values():
				assert_lte(row.size.x, screen.scroll.size.x)
			assert_eq(save.get_setting(&"language"), "pl")
			assert_eq(content.get_language(), "pl")
			screen.free()
			assert_eq(selector.select("restore_preview"), OK)
