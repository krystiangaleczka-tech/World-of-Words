extends GutTest

const ICON: Texture2D = preload("res://assets/icons/play.svg")
const HC_THEME: Theme = preload("res://ui/theme/generated/theme_hc_130.tres")

var _locale: String
var _pseudo: bool
var _reduced: bool
var _catalog: LocaleCatalog


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	_reduced = Tokens.reduced_motion
	TranslationServer.pseudolocalization_enabled = false
	TranslationServer.set_locale("pl")
	Tokens.reduced_motion = true
	_catalog = LocaleCatalog.new()
	assert_eq(_catalog.register_all(), OK)


func after_each() -> void:
	_catalog.unregister()
	TranslationServer.pseudolocalization_enabled = _pseudo
	TranslationServer.set_locale(_locale)
	Tokens.reduced_motion = _reduced


func _button(kind: String = "PrimaryButton") -> ActionButton:
	var button: ActionButton = load("res://ui/components/%s.tscn" % kind).instantiate()
	button.text_key = "gallery.actions.play"
	button.size = Vector2(500, Tokens.Touch.MIN_TARGET)
	add_child_autofree(button)
	return button


func _activate(button: ActionButton) -> void:
	button.grab_focus()
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	button.get_viewport().push_input(event)
	event = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = false
	button.get_viewport().push_input(event)


func test_native_activation_loading_idempotence_and_icon_restore() -> void:
	for kind: String in ["PrimaryButton", "SecondaryButton", "TextButton"]:
		var button: ActionButton = _button(kind)
		button.icon = ICON
		watch_signals(button)
		await get_tree().process_frame
		_activate(button)
		assert_signal_emit_count(button, "pressed", 1)
		button.loading = true
		button.loading = true
		assert_true(button.disabled)
		assert_ne(button.icon, ICON)
		button.disabled = false
		_activate(button)
		assert_true(button.disabled, "loading survives caller availability refresh")
		assert_signal_emit_count(button, "pressed", 1)
		assert_eq(button.text, button.tr(button.text_key))
		button.set_busy(false)
		assert_same(button.icon, ICON)
		assert_false(button.disabled)
		button.disabled = true
		button.set_busy(true)
		button.set_busy(false)
		assert_true(button.disabled)


func test_copy_sublabel_locale_and_pseudo_single_translation() -> void:
	var button: ActionButton = _button()
	button.sublabel_key = "gallery.actions.sublabel"
	assert_eq(button.text, "Zagraj w kolejny poziom")
	assert_eq(button.accessibility_name, button.text)
	assert_eq(button.accessibility_description, "Przywróć zakupy i kontynuuj")
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq(button.text, "Play the next level")
	assert_eq((button.get_node("Sublabel") as Label).text, "Restore purchases and continue")
	TranslationServer.pseudolocalization_enabled = true
	button.text_key = "gallery.actions.play"
	assert_eq(button.text, button.tr(button.text_key))
	assert_eq(button.accessibility_name, button.text)
	assert_eq(button.accessibility_description, button.tr(button.sublabel_key))
	assert_eq(button.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED)
	assert_eq(
		(button.get_node("Sublabel") as Label).auto_translate_mode,
		Node.AUTO_TRANSLATE_MODE_DISABLED
	)


func test_live_hc_theme_scaled_font_focus_disabled_and_secondary_outline() -> void:
	for kind: String in ["PrimaryButton", "SecondaryButton", "TextButton"]:
		var button: ActionButton = _button(kind)
		button.theme = HC_THEME
		await get_tree().process_frame
		assert_eq(button.get_theme_font_size("font_size"), 52)
		assert_eq(button.get_theme_color("font_disabled_color"), Tokens.PaletteHC.TEXT_MUTED)
		var style: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
		assert_eq(
			button.get_theme_color("font_color"),
			Tokens.PaletteHC.ON_PRIMARY if kind == "PrimaryButton" else Tokens.PaletteHC.PRIMARY
		)
		assert_eq(button.get_theme_color("icon_normal_color"), button.get_theme_color("font_color"))
		var focus: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
		assert_false(focus.draw_center)
		assert_eq(focus.border_color, Tokens.PaletteHC.TEXT)
		if kind == "SecondaryButton":
			assert_eq(style.border_width_left, Tokens.Action.OUTLINE_WIDTH)
			assert_eq(style.bg_color, Tokens.PaletteHC.SURFACE)
		elif kind == "TextButton":
			assert_false(style.draw_center)


func test_compact_wrapping_sublabel_grows_and_remains_inside() -> void:
	var button: ActionButton = _button()
	button.theme = HC_THEME
	button.text_key = "gallery.actions.ad"
	button.sublabel_key = "gallery.actions.sublabel"
	button.size.x = 300
	for i: int in 6:
		await get_tree().process_frame
		button.size.y = button.get_combined_minimum_size().y
	var label: Label = button.get_node("Sublabel") as Label
	assert_gt(button.size.y, float(Tokens.Touch.MIN_TARGET))
	assert_gt(label.get_line_count(), 1)
	assert_lte(label.position.y + label.size.y, button.size.y)
	assert_eq(button.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
	assert_eq(button.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	button.size.x = 800
	for i: int in 6:
		await get_tree().process_frame
		button.size.y = button.get_combined_minimum_size().y
	assert_eq(label.get_line_count(), 1)


func test_badge_atomic_pre_ready_loading_and_reentry() -> void:
	var button: SecondaryButton = SecondaryButton.new()
	button.badge = &"ad"
	button.loading = true
	button.text_key = "gallery.actions.ad"
	add_child_autofree(button)
	assert_true(button.disabled)
	assert_eq(button.badge, &"ad")
	var margin: float = button.get_theme_stylebox("normal").content_margin_left
	assert_gt(margin, float(Tokens.Space.M))
	assert_eq(button.configure_badge(&"unknown"), ERR_INVALID_PARAMETER)
	assert_eq(button.badge, &"ad")
	assert_eq(button.get_theme_stylebox("normal").content_margin_left, margin)
	assert_true(button.get_theme_stylebox("disabled").content_margin_left >= margin)
	remove_child(button)
	add_child(button)
	assert_true(button.disabled)
	button.loading = false
	assert_false(button.disabled)
	assert_eq(button.configure_badge(&""), OK)
	assert_eq(button.get_theme_stylebox("normal").content_margin_left, float(Tokens.Space.M))


func test_finite_motion_reduced_and_disabled_cleanup() -> void:
	var button: ActionButton = _button()
	button.highlighted = true
	assert_eq(button.scale, Vector2.ONE)
	Tokens.reduced_motion = false
	button.highlighted = false
	var previous: Array[Tween] = get_tree().get_processed_tweens()
	button.highlighted = true
	var owned: Array[Tween] = []
	for tween: Tween in get_tree().get_processed_tweens():
		if tween not in previous:
			owned.append(tween)
	assert_eq(owned.size(), 1)
	var motion: Tween = owned[0]
	motion.custom_step(Tokens.dur(Tokens.Motion.SLOW))
	assert_gt(button.scale.x, 1.0)
	Tokens.reduced_motion = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(motion.is_running())
	assert_eq(button.scale, Vector2.ONE)
	Tokens.reduced_motion = false
	button.highlighted = false
	previous = get_tree().get_processed_tweens()
	button.highlighted = true
	for tween: Tween in get_tree().get_processed_tweens():
		if tween not in previous:
			motion = tween
	for i: int in 6:
		motion.custom_step(Tokens.dur(Tokens.Motion.SLOW))
	assert_false(motion.is_running())
	assert_eq(button.scale, Vector2.ONE)
	button.highlighted = false
	button.highlighted = true
	button.disabled = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(button.scale, Vector2.ONE)
	remove_child(button)
	assert_eq(button.scale, Vector2.ONE)
	add_child(button)


func test_live_reduced_motion_cancels_native_press_tween() -> void:
	var button: ActionButton = _button()
	Tokens.reduced_motion = false
	button.grab_focus()
	await get_tree().process_frame
	var previous: Array[Tween] = get_tree().get_processed_tweens()
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	button.get_viewport().push_input(event)
	var motion: Tween
	for tween: Tween in get_tree().get_processed_tweens():
		if tween not in previous:
			motion = tween
	assert_not_null(motion)
	motion.custom_step(Tokens.dur(Tokens.Motion.FAST) / 2)
	assert_lt(button.scale.x, 1.0)
	Tokens.reduced_motion = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(button.scale, Vector2.ONE)
	assert_false(motion.is_running())
	event = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = false
	button.get_viewport().push_input(event)


func test_mouse_once_text_underline_and_gallery_states() -> void:
	var button: TextButton = _button("TextButton") as TextButton
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(900, 900)
	add_child_autofree(viewport)
	button.reparent(viewport)
	button.position = Vector2(40, 40)
	watch_signals(button)
	await get_tree().process_frame
	for down: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = button.global_position + button.size / 2
		button.get_viewport().push_input(event)
	assert_signal_emit_count(button, "pressed", 1)
	var segment: PackedVector2Array = button.underline_segment()
	button.position += Vector2(100, 100)
	assert_eq(button.underline_segment(), segment)
	var gallery: GalleryShell = load("res://ui/gallery/gallery.tscn").instantiate()
	add_child_autofree(gallery)
	assert_eq(gallery.configure(&"COMPACT", &"PSEUDO", true, 130, true, true, &"Actions"), OK)
	await get_tree().process_frame
	var actions: Array[Node] = gallery.preview_screen().find_children(
		"*", "ActionButton", true, false
	)
	assert_eq(actions.size(), 15)
	for action: ActionButton in actions:
		assert_gte(action.get_combined_minimum_size().y, float(Tokens.Touch.MIN_TARGET))

	gallery.free()
