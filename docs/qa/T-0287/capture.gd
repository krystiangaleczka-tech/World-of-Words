extends SceneTree
## Actual SettingsLanguage production catalog and transient debug preview; no SDKs.

const PATH: String = "user://t0287-native.json"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	Tokens.reduced_motion = true
	for key: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + key, GalleryShell.OPTIONS[key])
	TranslationServer.reload_pseudolocalization()
	for layout: String in ["COMPACT", "REGULAR", "TABLET"]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				await _shot(layout, pseudo, hc)
	quit()


func _shot(layout: String, pseudo: bool, hc: bool) -> void:
	_clean()
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	var view: SubViewport = SubViewport.new()
	view.size = {
		"COMPACT": Vector2i(1080, 1920),
		"REGULAR": Vector2i(1080, 2340),
		"TABLET": Vector2i(1440, 1920)
	}[layout]
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var save: Node = load("res://services/save.gd").new()
	view.add_child(save)
	save.initialize(Clock.new())
	var storage: SaveStorage = SaveStorage.new(PATH)
	save.configure(
		storage, func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert(save.load() == OK)
	var screen: Control = load("res://features/settings/settings_screen.tscn").instantiate()
	assert(screen.configure(save) == OK)
	assert(save.set_setting(&"high_contrast", hc) == OK)
	assert(save.set_setting(&"text_scale", 2 if hc else 0) == OK)
	assert(save.set_setting(&"reduced_motion", true) == OK)
	var runtime: Node = load("res://services/settings_runtime.gd").new()
	view.add_child(runtime)
	assert(runtime.configure(save, screen) == OK)
	assert(screen.bind_runtime(runtime) == OK)
	var content: Node = load("res://services/content.gd").new()
	view.add_child(content)
	assert(content.load_manifest("pl") == OK)
	var language: Node = load("res://services/settings_language.gd").new()
	view.add_child(language)
	assert(language.configure(save, content, func(_phase: StringName, _target: String) -> Error: return ERR_UNAVAILABLE) == OK)
	assert(screen.bind_language(language) == OK)
	view.add_child(screen)
	for position: String in ["top", "bottom", "sheet"]:
		for frame: int in range(6):
			await process_frame
		screen.scroll.scroll_vertical = (
			0 if position == "top" else int(screen.scroll.get_v_scroll_bar().max_value)
		)
		if position == "sheet":
			screen.rows[&"language"].pressed.emit()
		await process_frame
		RenderingServer.force_draw(false)
		var filename: String = ProjectSettings.globalize_path(
			(
				"res://../docs/qa/T-0287/settings_%s_%s_%s_%s.png"
				% [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100", position]
			)
		)
		assert(view.get_texture().get_image().save_png(filename) == OK)
	if not pseudo:
		screen.language_sheet.close()
		assert(language.configure(save, content, func(_phase: StringName, _target: String) -> Error: return ERR_UNAVAILABLE, "res://content", true) == OK)
		screen.rows[&"language"].pressed.emit()
		await _extra_shot(view, "debug_sheet", layout, hc)
		screen.language_options["preview_en"].pressed.emit()
		assert(save.get_setting(&"language") == "pl")
		assert(content.get_language() == "pl")
		assert(TranslationServer.get_locale() == "en")
		screen.scroll.scroll_vertical = 0
		await _extra_shot(view, "debug_en_top", layout, hc)
		screen.scroll.scroll_vertical = int(screen.scroll.get_v_scroll_bar().max_value)
		await _extra_shot(view, "debug_en_bottom", layout, hc)
		assert(language.select("restore_preview") == OK)
		assert(content.load_manifest("pl", "res://tests/fixtures/settings/content") == OK)
		assert(language.configure(save, content, func(_phase: StringName, _target: String) -> Error: return ERR_BUSY, "res://tests/fixtures/settings/content") == OK)
		screen.rows[&"language"].pressed.emit()
		screen.language_options["en"].pressed.emit()
		assert(language.snapshot().state == &"prepare_failed")
		assert(content.get_language() == "pl")
		await _extra_shot(view, "fixture_unsafe_retry", layout, hc)
	view.free()
	_clean()


func _extra_shot(view: SubViewport, name_value: String, layout: String, hc: bool) -> void:
	for frame: int in range(6):
		await process_frame
	RenderingServer.force_draw(false)
	assert(view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/qa/T-0287/language_%s_PL_%s_%s.png" % [layout, "hc130" if hc else "default100", name_value])) == OK)


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
