extends GutTest

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _viewport() -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	add_child_autofree(viewport)
	return viewport


func _click(viewport: SubViewport, button: Button) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.position + button.size / 2.0
	event.pressed = true
	viewport.push_input(event)
	event.pressed = false
	viewport.push_input(event)


func _accept(viewport: SubViewport) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	viewport.push_input(event)
	event.pressed = false
	viewport.push_input(event)


func test_translation_minimum_target_and_disabled_press() -> void:
	TranslationServer.set_locale("en")
	var viewport: SubViewport = _viewport()
	var button: IconButton = load("res://ui/components/IconButton.tscn").instantiate() as IconButton
	button.text_key = "level.hud.shuffle"
	button.position = Vector2(40, 40)
	button.size = Vector2(400, 160)
	viewport.add_child(button)
	await get_tree().process_frame
	watch_signals(button)
	assert_eq(button.text, "Shuffle")
	assert_eq(button.accessibility_name, "Shuffle")
	assert_gte(button.custom_minimum_size.x, float(Tokens.Touch.MIN_TARGET))
	assert_gte(button.custom_minimum_size.y, float(Tokens.Touch.MIN_TARGET))
	_click(viewport, button)
	assert_signal_emit_count(button, "pressed", 1)
	button.grab_focus()
	_accept(viewport)
	assert_signal_emit_count(button, "pressed", 2)
	TranslationServer.set_locale("pl")
	await get_tree().process_frame
	assert_eq(button.text, "Tasuj")
	assert_eq(button.accessibility_name, "Tasuj")
	button.disabled = true
	_click(viewport, button)
	button.grab_focus()
	_accept(viewport)
	assert_signal_emit_count(button, "pressed", 2)
	button.text_key = "level.hud.hint"
	assert_eq(button.text, "Podpowiedź")
	assert_eq(button.accessibility_name, "Podpowiedź")
	button.text_key = ""
	assert_eq(button.text, "")
	assert_eq(button.accessibility_name, "")


func test_hint_variant_and_gallery() -> void:
	TranslationServer.set_locale("en")
	var hint: HintButton = load("res://ui/components/HintButton.tscn").instantiate() as HintButton
	add_child_autofree(hint)
	assert_eq(hint.text, "Hint")
	assert_eq(hint.accessibility_name, "Hint")
	var gallery: ScreenScaffold = (
		load("res://ui/gallery/controls.tscn").instantiate() as ScreenScaffold
	)
	add_child_autofree(gallery)
	await get_tree().process_frame
	assert_eq(gallery.body.get_child_count(), 4)
	assert_false((gallery.body.get_child(0) as Button).disabled)
	assert_true((gallery.body.get_child(2) as Button).disabled)
	assert_is(gallery.body.get_child(1), HintButton)
	assert_is(gallery.body.get_child(3), HintButton)
	# Releasing one translation owner leaves the gallery's independent registrations alive.
	hint.free()
	TranslationServer.set_locale("pl")
	await get_tree().process_frame
	for child: Node in gallery.body.get_children():
		var button: IconButton = child as IconButton
		assert_eq(button.text, "Podpowiedź" if button is HintButton else "Tasuj")
		assert_eq(button.accessibility_name, button.text)


func test_translation_ownership_survives_detach_and_reentry() -> void:
	TranslationServer.set_locale("en")
	var previous_pl: Translation = TranslationServer.get_translation_object("pl")
	var previous_en: Translation = TranslationServer.get_translation_object("en")
	var viewport: SubViewport = _viewport()
	var button: IconButton = IconButton.new()
	button.text_key = "level.hud.shuffle"
	viewport.add_child(button)
	assert_eq(button.text, "Shuffle")
	viewport.remove_child(button)
	assert_same(TranslationServer.get_translation_object("pl"), previous_pl)
	assert_same(TranslationServer.get_translation_object("en"), previous_en)
	TranslationServer.set_locale("pl")
	viewport.add_child(button)
	assert_eq(button.text, "Tasuj")
	assert_eq(button.accessibility_name, "Tasuj")
	button.free()
	assert_same(TranslationServer.get_translation_object("pl"), previous_pl)
	assert_same(TranslationServer.get_translation_object("en"), previous_en)


func test_style_states_and_labels_use_tokens() -> void:
	TranslationServer.set_locale("pl")
	var button: HintButton = HintButton.new()
	add_child_autofree(button)
	assert_false(button.clip_text)
	assert_eq(button.get_theme_font_size("font_size"), Tokens.Type.LABEL)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style: StyleBoxFlat = button.get_theme_stylebox(state) as StyleBoxFlat
		assert_not_null(style)
		assert_eq(style.corner_radius_top_left, Tokens.Radius.FULL)
		assert_eq(style.content_margin_left, float(Tokens.Space.M))
		assert_eq(style.content_margin_top, float(Tokens.Space.S))
	var normal: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
	var pressed: StyleBoxFlat = button.get_theme_stylebox("pressed") as StyleBoxFlat
	var disabled_style: StyleBoxFlat = button.get_theme_stylebox("disabled") as StyleBoxFlat
	var focus: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
	assert_eq(normal.bg_color, Tokens.Palette.SURFACE)
	assert_eq(pressed.bg_color, Tokens.Palette.PRIMARY)
	assert_eq(disabled_style.bg_color, Tokens.Palette.SURFACE_ALT)
	assert_false(focus.draw_center)
	assert_eq(focus.border_color, Tokens.Palette.PRIMARY)
	assert_eq(button.get_theme_color("font_pressed_color"), Tokens.Palette.ON_PRIMARY)
	assert_eq(button.get_theme_color("font_disabled_color"), Tokens.Palette.TEXT_MUTED)
