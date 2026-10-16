extends SceneTree
## Native catalog evidence. Display values are synthetic fixtures, never live offers.


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
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	var viewport: SubViewport = SubViewport.new()
	viewport.size = {
		"COMPACT": Vector2i(1080, 1920),
		"REGULAR": Vector2i(1080, 2340),
		"TABLET": Vector2i(1440, 1920)
	}[layout]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen: ScreenScaffold = ScreenScaffold.new()
	screen.theme = load(
		(
			"res://ui/theme/generated/theme_hc_130.tres"
			if hc
			else "res://ui/theme/generated/theme_default_100.tres"
		)
	)
	viewport.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index: int in range(3):
		var card: Card = Card.new()
		card.title_key = "gallery.content.title"
		card.configure_action(
			&"primary" if index == 0 else &"secondary",
			"gallery.content.action",
			["12,99 zł", "CHF 123.90", ""][index],
			&"ad" if index == 2 else &""
		)
		screen.body.add_child(card)
	for frame: int in range(5):
		await process_frame
	RenderingServer.force_draw(false)
	var filename: String = ProjectSettings.globalize_path(
		(
			"res://../docs/qa/T-0334/card_actions_%s_%s_%s.png"
			% [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100"]
		)
	)
	assert(viewport.get_texture().get_image().save_png(filename) == OK)
	viewport.free()
