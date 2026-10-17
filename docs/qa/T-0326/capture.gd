extends SceneTree
## Actual catalog preview, without Save or gameplay activation.

var count: int = 0


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	for key: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + key, GalleryShell.OPTIONS[key])
	TranslationServer.reload_pseudolocalization()
	for layout: String in ["COMPACT", "REGULAR", "TABLET"]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				await _case(layout, pseudo, hc)
	print("T-0326 native screenshots: ", count)
	quit()


func _case(layout: String, pseudo: bool, hc: bool) -> void:
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = pseudo
	Tokens.reduced_motion = false
	var view: SubViewport = SubViewport.new()
	view.size = {"COMPACT": Vector2i(1080, 1920), "REGULAR": Vector2i(1080, 2340), "TABLET": Vector2i(1440, 1920)}[layout]
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var page: Control = (load("res://ui/gallery/tutorial.tscn") as PackedScene).instantiate()
	page.theme = load("res://ui/theme/generated/theme_hc_130.tres" if hc else "res://ui/theme/generated/theme_default_100.tres")
	view.add_child(page)
	await _settle()
	var hand: TutorialHand = page.get("hand")
	assert(hand.play() == OK)
	var motion: Tween = get_processed_tweens().back()
	motion.pause()
	motion.custom_step(Tokens.dur(Tokens.Motion.SLOW) / 2)
	assert(hand.state == &"playing")
	var prefix: String = "%s_%s_%s" % [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100"]
	await _shot(view, page, prefix, "playing")
	hand.hide_for_touch()
	var fade: Tween = get_processed_tweens().back()
	fade.pause()
	fade.custom_step(Tokens.dur(Tokens.Motion.FAST) * 2)
	assert(hand.state == &"hidden")
	assert(not hand.visible)
	await _shot(view, page, prefix, "hidden")
	Tokens.reduced_motion = true
	assert(hand.play() == OK)
	assert(hand.state == &"static")
	assert(not hand.is_processing())
	await _shot(view, page, prefix, "static")
	view.free()


func _shot(view: SubViewport, page: Control, prefix: String, state: String) -> void:
	await _settle()
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(view.size))
	assert(bounds.encloses((page.get("wheel") as Control).get_global_rect()))
	assert(bounds.encloses((page.get("caption") as Control).get_global_rect()))
	var hand: TutorialHand = page.get("hand")
	assert(hand.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	for point: Vector2 in hand.points:
		assert(bounds.has_point(hand.get_global_transform() * point))
	RenderingServer.force_draw(false)
	assert(view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/qa/T-0326/tutorial_%s_%s.png" % [prefix, state])) == OK)
	count += 1


func _settle() -> void:
	for frame: int in range(4):
		await process_frame
