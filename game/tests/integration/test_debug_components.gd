extends GutTest

const SCAFFOLD: PackedScene = preload("res://ui/components/ScreenScaffold.tscn")
const BUTTON: PackedScene = preload("res://ui/components/TextButton.tscn")


func test_scaffold_safe_insets_and_layout_classes() -> void:
	var scaffold: ScreenScaffold = SCAFFOLD.instantiate() as ScreenScaffold
	add_child_autofree(scaffold)
	watch_signals(scaffold)
	scaffold.apply_insets(Rect2(16, 64, 24, 32), Vector2(1080, 1920))
	assert_eq(scaffold.get_node("Safe").get_theme_constant("margin_left"), Tokens.Space.M + 16)
	assert_eq(scaffold.get_node("Safe").get_theme_constant("margin_top"), Tokens.Space.M + 64)
	assert_eq(scaffold.get_node("Safe").get_theme_constant("margin_right"), Tokens.Space.M + 24)
	assert_eq(scaffold.get_node("Safe").get_theme_constant("margin_bottom"), Tokens.Space.M + 32)
	assert_eq(scaffold.layout_class, &"COMPACT")
	scaffold.apply_insets(Rect2(), Vector2(1080, 2400))
	assert_eq(scaffold.layout_class, &"REGULAR")
	scaffold.apply_insets(Rect2(), Vector2(1600, 2000))
	assert_eq(scaffold.layout_class, &"TABLET")
	assert_signal_emitted_with_parameters(scaffold, "layout_class_changed", [&"TABLET"])
	scaffold.apply_insets(Rect2(), Vector2.ZERO)
	assert_eq(scaffold.layout_class, &"TABLET")


func test_button_translation_and_min_target() -> void:
	var translation: Translation = Translation.new()
	translation.locale = TranslationServer.get_locale()
	translation.add_message(&"fixture.button", &"Przycisk ąćęłńóśźż")
	TranslationServer.add_translation(translation)
	var button: TextButton = BUTTON.instantiate() as TextButton
	button.text_key = "fixture.button"
	add_child_autofree(button)
	assert_eq(button.text, "Przycisk ąćęłńóśźż")
	assert_gte(button.custom_minimum_size.y, float(Tokens.Touch.MIN_TARGET))
	for glyph: String in "ąćęłńóśźż ĄĆĘŁŃÓŚŹŻ":
		assert_true(button.get_theme_font("font").has_char(glyph.unicode_at(0)), glyph)
	TranslationServer.remove_translation(translation)


func test_button_busy_preserves_disabled() -> void:
	var button: TextButton = BUTTON.instantiate() as TextButton
	add_child_autofree(button)
	button.set_busy(true)
	button.set_busy(true)
	assert_true(button.disabled)
	button.set_busy(false)
	assert_false(button.disabled)
	button.disabled = true
	button.set_busy(true)
	button.set_busy(false)
	assert_true(button.disabled)


func test_gallery_instantiates() -> void:
	var gallery: ScreenScaffold = (
		(load("res://ui/gallery/debug_components.tscn") as PackedScene).instantiate()
		as ScreenScaffold
	)
	add_child_autofree(gallery)
	assert_eq(gallery.body.get_child_count(), 3)
	assert_false((gallery.body.get_node("normal") as TextButton).disabled)
	assert_true((gallery.body.get_node("disabled") as TextButton).disabled)
	assert_true((gallery.body.get_node("busy") as TextButton).disabled)


func test_pressed_underline_uses_local_coordinates() -> void:
	var button: TextButton = BUTTON.instantiate() as TextButton
	button.text_key = "fixture"
	add_child_autofree(button)
	button.size = Vector2(600, 144)
	button.position = Vector2.ZERO
	var local: PackedVector2Array = button.underline_segment()
	button.position = Vector2(220, 450)
	assert_eq(button.underline_segment(), local, "parent position must not shift draw coordinates")
	for point: Vector2 in local:
		assert_true(Rect2(Vector2.ZERO, button.size).has_point(point), str(point))
