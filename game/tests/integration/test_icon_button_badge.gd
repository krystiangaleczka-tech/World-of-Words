extends GutTest

const GLYPH: Texture2D = preload("res://assets/icons/shuffle.svg")
const HC: Theme = preload("res://ui/theme/generated/theme_hc_130.tres")
var _locale: String
var _pseudo: bool
var _reduced: bool


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	_reduced = Tokens.reduced_motion
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	Tokens.reduced_motion = true


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	Tokens.reduced_motion = _reduced


func _icon() -> IconButton:
	var button: IconButton = load("res://ui/components/IconButton.tscn").instantiate()
	assert_eq(button.configure_icon(GLYPH, "level.hud.shuffle"), OK)
	add_child_autofree(button)
	return button


func _badge(value: String, variant: StringName) -> Badge:
	var badge: Badge = load("res://ui/components/Badge.tscn").instantiate()
	assert_eq(badge.configure(value, variant), OK)
	add_child_autofree(badge)
	return badge


func test_atomic_required_label_and_safe_direct_configuration() -> void:
	var button: IconButton = _icon()
	assert_eq(button.text, "")
	assert_eq(button.accessibility_name, "Tasuj")
	assert_eq(button.tooltip_text, "Tasuj")
	for key: String in ["", "  "]:
		assert_eq(button.configure_icon(GLYPH, key, &"S"), ERR_INVALID_PARAMETER)
	assert_eq(button.configure_icon(null, "level.hud.hint"), ERR_INVALID_PARAMETER)
	assert_eq(button.configure_icon(GLYPH, "level.hud.hint", &"XL"), ERR_INVALID_PARAMETER)
	assert_same(button.icon, GLYPH)
	assert_eq(button.icon_size, &"M")
	assert_eq(button.a11y_label_key, "level.hud.shuffle")
	button.a11y_label_key = ""
	assert_eq(button.a11y_label_key, "level.hud.shuffle")
	for key: String in ["", "  "]:
		var unsafe: IconButton = IconButton.new()
		unsafe.a11y_label_key = key
		unsafe.text_key = "level.hud.shuffle"
		unsafe.icon = GLYPH
		add_child_autofree(unsafe)
		assert_null(unsafe.icon)
		assert_eq(unsafe.text, "Tasuj")
		assert_eq(unsafe.accessibility_name, "Tasuj")
	var pending: IconButton = IconButton.new()
	pending.text_key = "level.hud.shuffle"
	pending.icon = GLYPH
	pending.loading = true
	add_child_autofree(pending)
	assert_eq(pending.text, "Tasuj")
	pending.loading = false
	assert_null(pending.icon, "ending pre-ready work cannot restore an unlabelled glyph")
	assert_eq(pending.text, "Tasuj")
	assert_eq(pending.accessibility_name, "Tasuj")


func test_sizes_live_theme_locale_pseudo_and_reentry() -> void:
	var previous_pl: Translation = TranslationServer.get_translation_object("pl")
	var previous_en: Translation = TranslationServer.get_translation_object("en")
	var button: IconButton = _icon()
	for preset: StringName in [&"S", &"M"]:
		assert_eq(button.configure_icon(GLYPH, "level.hud.shuffle", preset), OK)
		assert_gte(button.custom_minimum_size.x, float(Tokens.Touch.MIN_TARGET))
		assert_gte(button.custom_minimum_size.y, float(Tokens.Touch.MIN_TARGET))
		assert_eq(
			button.get_theme_constant("icon_max_width"),
			Tokens.Space.L if preset == &"S" else Tokens.Space.XL
		)
		assert_eq(button.icon_alignment, HORIZONTAL_ALIGNMENT_CENTER)
		var style: StyleBox = button.get_theme_stylebox("normal")
		assert_eq(style.content_margin_top, float(Tokens.Space.S))
		assert_eq(style.content_margin_bottom, style.content_margin_top)
		assert_false((button.get_node("Sublabel") as Label).visible)
	button.theme = HC
	await get_tree().process_frame
	assert_eq(
		(button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Tokens.PaletteHC.SURFACE
	)
	assert_eq(button.get_theme_color("icon_normal_color"), Tokens.PaletteHC.PRIMARY)
	assert_eq(button.get_theme_color("icon_pressed_color"), Tokens.PaletteHC.ON_PRIMARY)
	assert_eq(button.get_theme_color("icon_disabled_color"), Tokens.PaletteHC.TEXT_MUTED)
	assert_eq(
		(button.get_theme_stylebox("focus") as StyleBoxFlat).border_color, Tokens.PaletteHC.PRIMARY
	)
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq(button.accessibility_name, "Shuffle")
	TranslationServer.pseudolocalization_enabled = true
	button.a11y_label_key = "level.hud.shuffle"
	assert_eq(button.accessibility_name, button.tr(button.a11y_label_key))
	assert_eq(button.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED)
	remove_child(button)
	assert_same(TranslationServer.get_translation_object("pl"), previous_pl)
	assert_same(TranslationServer.get_translation_object("en"), previous_en)
	add_child(button)
	assert_eq(button.accessibility_name, button.tr(button.a11y_label_key))


func test_native_activation_disabled_and_reduced_highlight() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(600, 600)
	add_child_autofree(viewport)
	var button: IconButton = _icon()
	button.reparent(viewport)
	button.position = Vector2(40, 40)
	await get_tree().process_frame
	watch_signals(button)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.position + button.size / 2
		event.pressed = pressed
		viewport.push_input(event)
	assert_signal_emit_count(button, "pressed", 1)
	button.grab_focus()
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = pressed
		viewport.push_input(event)
	assert_signal_emit_count(button, "pressed", 2)
	button.disabled = true
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = pressed
		button.grab_focus()
		viewport.push_input(event)
	assert_signal_emit_count(button, "pressed", 2)
	button.disabled = false
	button.highlighted = true
	assert_eq(button.scale, Vector2.ONE)
	assert_gt((button.get_theme_stylebox("normal") as StyleBoxFlat).border_width_left, 0)


func test_badge_count_lock_new_atomicity_and_passive_geometry() -> void:
	var count: Badge = _badge("0", &"info")
	var caption: Label = count.find_child("Caption", true, false) as Label
	assert_eq(caption.text, "0")
	count.text = "99999"
	assert_eq(caption.text, "99999")
	assert_gt(caption.custom_minimum_size.x, 100.0)
	assert_eq(count.accessibility_name, "99999")
	assert_eq(count.configure("changed", &"urgent"), ERR_INVALID_PARAMETER)
	count.kind = &"urgent"
	assert_eq(count.kind, &"info")
	assert_eq(count.text, "99999")
	assert_eq(count.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(count.focus_mode, Control.FOCUS_NONE)
	var locked: Badge = _badge("3", &"lock")
	var lock_icon: TextureRect = locked.find_child("Lock", true, false) as TextureRect
	assert_true(lock_icon.visible)
	assert_same(lock_icon.texture, Badge.LOCK)
	assert_eq(locked.accessibility_name, "Zablokowane")
	assert_eq(locked.accessibility_description, "3")
	var fresh: Badge = _badge("", &"new")
	assert_eq(fresh.accessibility_name, "NOWE")
	assert_eq((fresh.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, Tokens.Palette.BONUS)
	for node: Control in fresh.find_children("*", "Control", true, false):
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(node.focus_mode, Control.FOCUS_NONE)


func test_badge_theme_wrapping_locale_and_independent_translation_ownership() -> void:
	var first: Badge = _badge("", &"new")
	var second: Badge = _badge("", &"new")
	first.free()
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq(second.accessibility_name, "NEW")
	second.theme = HC
	second.text_key = "gallery.actions.sublabel"
	second.size.x = 220
	for i: int in 6:
		await get_tree().process_frame
	var label: Label = second.find_child("Caption", true, false) as Label
	assert_gt(label.get_line_count(), 1)
	assert_eq(label.get_theme_font_size("font_size"), 42)
	assert_eq(label.get_theme_color("font_color"), Tokens.PaletteHC.ON_PRIMARY)
	TranslationServer.pseudolocalization_enabled = true
	second.text_key = "gallery.actions.sublabel"
	assert_eq(label.text, second.tr(second.text_key))
	assert_eq(second.accessibility_name, label.text)
	assert_eq(label.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED)
	remove_child(second)
	add_child(second)
	assert_eq(label.text, second.tr(second.text_key))
	assert_eq(second.accessibility_name, label.text)
	assert_eq(second.configure("9", &"info"), OK)
	assert_eq(label.text, "9")


func test_gallery_sizes_states_and_badges() -> void:
	var gallery: GalleryShell = load("res://ui/gallery/gallery.tscn").instantiate()
	add_child_autofree(gallery)
	assert_eq(gallery.configure(&"COMPACT", &"PSEUDO", true, 130, true, true, &"Icons"), OK)
	for i: int in 4:
		await get_tree().process_frame
	var screen: ScreenScaffold = gallery.preview_screen()
	assert_eq(screen.find_children("icon_*", "IconButton", true, false).size(), 8)
	assert_eq(screen.find_children("badge_*", "Badge", true, false).size(), 4)
	for button: IconButton in screen.find_children("icon_*", "IconButton", true, false):
		assert_false(button.a11y_label_key.is_empty())
		assert_eq(button.text, "")
		assert_eq(button.accessibility_name, button.tr(button.a11y_label_key))
	gallery.free()
