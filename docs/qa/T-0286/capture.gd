extends SceneTree
## Actual committed settings runtime and native catalog text-size Sheet; no SDKs.

const PATH: String = "user://t0286-native.json"


class CaptureStorage:
	extends SaveStorage
	var fail: bool = false

	func commit(text: String, rotate: bool) -> Error:
		return ERR_FILE_CANT_WRITE if fail else super.commit(text, rotate)


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
	var storage: CaptureStorage = CaptureStorage.new(PATH)
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
	view.add_child(screen)
	for position: String in ["top", "bottom", "sheet", "error"]:
		if position == "error":
			screen.text_sheet.close()
			storage.fail = true
			screen.controls[&"high_contrast"].value_changed.emit(not hc)
		for frame: int in range(6):
			await process_frame
		screen.scroll.scroll_vertical = (
			0 if position == "top" else int(screen.scroll.get_v_scroll_bar().max_value)
		)
		if position == "sheet":
			screen.rows[&"text_size"].pressed.emit()
		await process_frame
		RenderingServer.force_draw(false)
		var filename: String = ProjectSettings.globalize_path(
			(
				"res://../docs/qa/T-0286/settings_%s_%s_%s_%s.png"
				% [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100", position]
			)
		)
		assert(view.get_texture().get_image().save_png(filename) == OK)
	view.free()
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
