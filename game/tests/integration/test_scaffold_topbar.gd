extends GutTest

const HC_THEME: Theme = preload("res://ui/theme/generated/theme_hc_130.tres")


func _viewport(dimensions: Vector2i = Vector2i(1600, 2000)) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = dimensions
	add_child_autofree(viewport)
	return viewport


func _screen(viewport: SubViewport) -> ScreenScaffold:
	var screen: ScreenScaffold = ScreenScaffold.new()
	viewport.add_child(screen)
	return screen


func _slot(width: float = 144) -> Control:
	var control: Control = Control.new()
	control.custom_minimum_size = Vector2(width, 64)
	return control


func test_screen_pixel_conversion_and_invalid_windows() -> void:
	var window: Rect2i = Rect2i(100, 200, 540, 960)
	assert_eq(
		ScreenScaffold.screen_insets(Rect2i(110, 220, 520, 920), window, Vector2(1080, 1920)),
		Rect2(20, 40, 20, 40)
	)
	assert_eq(ScreenScaffold.screen_insets(Rect2i(), window, Vector2(1080, 1920)), Rect2())
	assert_eq(ScreenScaffold.screen_insets(window, Rect2i(), Vector2(1080, 1920)), Rect2())
	assert_eq(ScreenScaffold.screen_insets(window, window, Vector2.ZERO), Rect2())


func test_class_boundaries_fractional_margins_and_signal_deduplication() -> void:
	var screen: ScreenScaffold = _screen(_viewport())
	screen.apply_insets(Rect2(), Vector2(1080, 2340))
	watch_signals(screen)
	screen.apply_insets(Rect2(), Vector2(1000, 1649))
	assert_eq(screen.layout_class, &"TABLET")
	screen.apply_insets(Rect2(), Vector2(1000, 1650))
	assert_eq(screen.layout_class, &"COMPACT")
	screen.apply_insets(Rect2(), Vector2(1000, 1950))
	assert_eq(screen.layout_class, &"REGULAR")
	screen.apply_insets(Rect2(), Vector2(1000, 1950))
	assert_signal_emit_count(screen, "layout_class_changed", 3)
	screen.apply_insets(Rect2(9999, 9999, 0, 0), Vector2(1000, 1950))
	assert_eq(screen.layout_class, &"REGULAR")
	screen.apply_insets(Rect2(-2, 0.2, 10.2, 20.7), Vector2(1080, 2340))
	var safe: MarginContainer = screen.get_node("Safe") as MarginContainer
	assert_eq(safe.get_theme_constant("margin_left"), Tokens.Space.M)
	assert_eq(safe.get_theme_constant("margin_top"), Tokens.Space.M + 1)
	assert_eq(safe.get_theme_constant("margin_right"), Tokens.Space.M + 11)
	assert_eq(safe.get_theme_constant("margin_bottom"), Tokens.Space.M + 21)


func test_tablet_cap_asymmetric_safe_centre_and_viewport_resize_reentry() -> void:
	var viewport: SubViewport = _viewport()
	var screen: ScreenScaffold = _screen(viewport)
	screen.debug_insets = Rect2(100, 0, 20, 0)
	await get_tree().process_frame
	assert_eq(screen.body.size.x, float(Tokens.Layout.MAX_CONTENT_WIDTH))
	assert_almost_eq(screen.body.position.x + screen.body.size.x / 2, 840.0, 1.0)
	viewport.size = Vector2i(1080, 2340)
	await get_tree().process_frame
	assert_eq(screen.layout_class, &"REGULAR")
	viewport.remove_child(screen)
	viewport.size = Vector2i(1600, 2000)
	viewport.add_child(screen)
	await get_tree().process_frame
	assert_eq(screen.layout_class, &"TABLET")
	assert_eq(screen.body.size.x, float(Tokens.Layout.MAX_CONTENT_WIDTH))


func test_chrome_order_replacement_ownership_and_art_theme() -> void:
	var screen: ScreenScaffold = _screen(_viewport())
	var header: TopBar = TopBar.new()
	var footer: Control = _slot()
	screen.top_bar = header
	screen.bottom = footer
	var content: Control = _slot()
	screen.body.add_child(content)
	assert_same(screen.body.get_child(0), header)
	assert_same(screen.body.get_child(screen.body.get_child_count() - 1), footer)
	screen.top_bar = null
	assert_null(header.get_parent())
	assert_true(is_instance_valid(header))
	header.free()
	screen.bottom = null
	assert_null(footer.get_parent())
	footer.free()
	var foreign: Control = _slot()
	add_child_autofree(foreign)
	screen.bottom = foreign
	assert_null(screen.bottom)
	var texture: GradientTexture2D = GradientTexture2D.new()
	screen.background = texture
	assert_same((screen.get_child(1) as TextureRect).texture, texture)
	screen.theme = HC_THEME
	await get_tree().process_frame
	assert_eq((screen.get_child(0) as ColorRect).color, Tokens.PaletteHC.BG)
	assert_eq(
		(screen.get_child(1) as TextureRect).stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)


func test_topbar_validation_atomic_slots_and_defensive_properties() -> void:
	var bar: TopBar = TopBar.new()
	add_child_autofree(bar)
	var left: Control = _slot()
	var right: Control = _slot()
	assert_eq(bar.configure([left], "gallery.scaffold.title", [right]), OK)
	assert_eq(bar.configure([left, left], "", []), ERR_INVALID_PARAMETER)
	var extras: Array[Control] = [left, _slot(), _slot(), _slot()]
	assert_eq(bar.configure(extras, "", []), ERR_INVALID_PARAMETER)
	for index: int in range(1, extras.size()):
		extras[index].free()
	var text_button: TextButton = TextButton.new()
	assert_eq(bar.configure([text_button], "", []), ERR_INVALID_PARAMETER)
	text_button.free()
	var foreign: Control = _slot()
	add_child_autofree(foreign)
	assert_eq(bar.configure([foreign], "", []), ERR_ALREADY_IN_USE)
	assert_eq(bar.title_key, "gallery.scaffold.title")
	assert_eq(bar.leading, [left])
	var copy: Array[Control] = bar.leading
	copy.clear()
	assert_eq(bar.leading, [left])
	assert_eq(bar.configure([], "", []), OK)
	assert_null(left.get_parent())
	assert_null(right.get_parent())
	left.free()
	right.free()


func test_topbar_centre_nonoverlap_narrow_flag_locale_and_theme() -> void:
	var previous_locale: String = TranslationServer.get_locale()
	var previous_pseudo: bool = TranslationServer.pseudolocalization_enabled
	TranslationServer.pseudolocalization_enabled = false
	TranslationServer.set_locale("pl")
	var bar: TopBar = TopBar.new()
	bar.size = Vector2(1000, Tokens.Layout.TOP_BAR_H)
	var left: Control = _slot(144)
	var right: Control = _slot(200)
	var other: Control = _slot(144)
	bar.configure([left], "gallery.scaffold.title", [right, other])
	add_child_autofree(bar)
	await get_tree().process_frame
	var title: Label = bar.get_node("Title") as Label
	assert_true(bar.fits)
	assert_almost_eq(title.position.x + title.size.x / 2, 500.0, 1.0)
	assert_false(title.get_rect().intersects(left.get_rect()))
	assert_false(title.get_rect().intersects(right.get_rect()))
	assert_lte(left.position.y + left.size.y, float(Tokens.Layout.TOP_BAR_H))
	assert_eq(title.text, "Świat słów")
	TranslationServer.set_locale("en")
	assert_eq(title.text, "World of Words")
	bar.theme = HC_THEME
	bar.transparent = false
	await get_tree().process_frame
	assert_eq(title.get_theme_font_size("font_size"), roundi(Tokens.Type.SUBTITLE * 1.3))
	assert_eq((bar.get_child(0) as ColorRect).color, Tokens.PaletteHC.SURFACE)
	bar.size.x = 100
	await get_tree().process_frame
	assert_false(bar.fits)
	assert_false(title.visible)
	assert_true(left.visible and right.visible and other.visible)
	assert_false(left.get_rect().intersects(right.get_rect()))
	TranslationServer.set_locale(previous_locale)
	TranslationServer.pseudolocalization_enabled = previous_pseudo


func test_topbar_pseudo_translation_owner_and_detach_reentry() -> void:
	var previous_locale: String = TranslationServer.get_locale()
	var previous_pseudo: bool = TranslationServer.pseudolocalization_enabled
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	var foreign: Translation = Translation.new()
	foreign.locale = "en"
	foreign.add_message("scaffold.test.owner", "External")
	TranslationServer.add_translation(foreign)
	var host: Control = Control.new()
	add_child_autofree(host)
	var bar: TopBar = TopBar.new()
	bar.size = Vector2(1000, Tokens.Layout.TOP_BAR_H)
	bar.title_key = "gallery.scaffold.title"
	host.add_child(bar)
	await get_tree().process_frame
	var label: Label = bar.get_node("Title") as Label
	assert_ne(label.text, "World of Words")
	assert_eq(label.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED)
	assert_eq(label.text, TranslationServer.translate("gallery.scaffold.title"))
	host.remove_child(bar)
	TranslationServer.pseudolocalization_enabled = false
	host.add_child(bar)
	await get_tree().process_frame
	assert_eq(label.text, "World of Words")
	bar.free()
	assert_eq(TranslationServer.translate("scaffold.test.owner"), "External")
	TranslationServer.remove_translation(foreign)
	TranslationServer.set_locale(previous_locale)
	TranslationServer.pseudolocalization_enabled = previous_pseudo


func test_title_recovers_from_narrow_and_initially_unsized_bars() -> void:
	for start_wide: bool in [true, false]:
		var bar: TopBar = TopBar.new()
		bar.theme = HC_THEME
		bar.title_key = "gallery.scaffold.title"
		if start_wide:
			bar.size = Vector2(1000, Tokens.Layout.TOP_BAR_H)
		add_child_autofree(bar)
		await get_tree().process_frame
		bar.size.x = 60
		await get_tree().process_frame
		assert_false(bar.fits)
		bar.size.x = 1000
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(bar.fits)
		var label: Label = bar.get_node("Title") as Label
		assert_true(label.visible)
		assert_lte(label.size.y, float(Tokens.Layout.TOP_BAR_H))


func test_ancestor_and_self_chrome_rejected_without_mutation() -> void:
	var host: Control = Control.new()
	var bar: TopBar = TopBar.new()
	host.add_child(bar)
	bar.title_key = "gallery.scaffold.title"
	assert_eq(bar.configure([host], "bad.key", []), ERR_INVALID_PARAMETER)
	assert_eq(bar.title_key, "gallery.scaffold.title")
	assert_true(bar.leading.is_empty())
	host.free()
	var screen: ScreenScaffold = ScreenScaffold.new()
	screen.bottom = screen
	assert_null(screen.bottom)
	host = Control.new()
	host.add_child(screen)
	screen.bottom = host
	assert_null(screen.bottom)
	host.free()
