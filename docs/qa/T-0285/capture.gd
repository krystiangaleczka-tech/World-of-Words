extends SceneTree
## Actual Settings scene and Save owner; no persistence intent binding or SDKs.

const PATH: String = "user://t0285-native.json"


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
	save.configure(
		SaveStorage.new(PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert(save.load() == OK)
	var screen: Control = load("res://features/settings/settings_screen.tscn").instantiate()
	assert(screen.configure(save) == OK)
	screen.theme = load(
		(
			"res://ui/theme/generated/theme_hc_130.tres"
			if hc
			else "res://ui/theme/generated/theme_default_100.tres"
		)
	)
	view.add_child(screen)
	for position: String in ["top", "bottom"]:
		for frame: int in range(6):
			await process_frame
		screen.scroll.scroll_vertical = (
			0 if position == "top" else int(screen.scroll.get_v_scroll_bar().max_value)
		)
		await process_frame
		RenderingServer.force_draw(false)
		var filename: String = ProjectSettings.globalize_path(
			(
				"res://../docs/qa/T-0285/settings_%s_%s_%s_%s.png"
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
