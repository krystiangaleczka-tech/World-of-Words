extends GutTest

const SCENE: PackedScene = preload("res://features/settings/licences_screen.tscn")
const CREDITS: Script = preload("res://services/settings_credits.gd")
const SETTINGS: PackedScene = preload("res://features/settings/settings_screen.tscn")
const SAVE: Script = preload("res://services/save.gd")
const FIXTURE: Script = preload("res://tests/integration/test_level_hud.gd")
var _locale: String
var _pseudo: bool


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo


func _view(dimensions: Vector2i = Vector2i(1080, 1920)) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = dimensions
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(view)
	return view


func _screen(view: SubViewport) -> LicencesScreen:
	var screen: LicencesScreen = SCENE.instantiate()
	view.add_child(screen)
	return screen


func _settle() -> void:
	for frame: int in range(5):
		await get_tree().process_frame


func test_all_seven_legal_notices_are_browseable_verbatim() -> void:
	var screen: LicencesScreen = SCENE.instantiate()
	assert_eq(screen.select_notice(&"godot"), ERR_UNCONFIGURED)
	_view().add_child(screen)
	assert_eq(screen.rows.size(), 7)
	for entry: Dictionary in CREDITS.entries():
		assert_true(screen.rows.has(entry.id))
		assert_eq(screen.select_notice(entry.id), OK)
		assert_eq(screen.selected_id, entry.id)
		assert_eq(screen.notice.text, entry.notice)
		assert_true(screen.notice.visible)
		assert_false(screen.rows[entry.id].is_visible_in_tree())
	assert_eq(screen.select_notice(&"missing"), ERR_INVALID_PARAMETER)
	assert_eq(screen.selected_id, &"pl-sources")
	assert_eq(screen.notice.text, CREDITS.entries().back().notice)


func test_back_from_notice_returns_to_list_then_requests_exit() -> void:
	var screen: LicencesScreen = _screen(_view())
	await _settle()
	watch_signals(screen)
	screen.rows[&"audio"].pressed.emit()
	await _settle()
	screen.back.pressed.emit()
	await _settle()
	assert_eq(screen.selected_id, &"")
	assert_false(screen.notice.is_visible_in_tree())
	assert_true(screen.rows[&"audio"].is_visible_in_tree())
	assert_true(screen.rows[&"audio"].has_focus())
	assert_signal_not_emitted(screen, "back_requested")
	screen.back.pressed.emit()
	assert_signal_emit_count(screen, "back_requested", 1)


func test_settings_intent_routes_to_caller_owned_scene() -> void:
	var save: SAVE = SAVE.new()
	add_child_autofree(save)
	save.initialize(Clock.new())
	save.configure(FIXTURE.MemoryStorage.new())
	assert_eq(save.load(), OK)
	var view: SubViewport = _view()
	var settings: SettingsScreen = SETTINGS.instantiate()
	assert_eq(settings.configure(save), OK)
	view.add_child(settings)
	var licences: LicencesScreen = SCENE.instantiate()
	settings.action_requested.connect(
		func(action: StringName) -> void:
			if action == &"licences":
				settings.hide()
				view.add_child(licences)
	)
	licences.back_requested.connect(
		func() -> void:
			licences.hide()
			settings.show()
	)
	var before: Dictionary = save.committed_view()
	settings.rows[&"licences"].pressed.emit()
	assert_true(licences.is_visible_in_tree())
	assert_false(settings.is_visible_in_tree())
	licences.handle_back()
	assert_true(settings.is_visible_in_tree())
	assert_eq_deep(save.committed_view(), before)


func test_keyboard_activation_and_retained_reentry() -> void:
	var view: SubViewport = _view()
	var screen: LicencesScreen = _screen(view)
	await _settle()
	screen.rows[&"inter"].grab_focus()
	for down: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = down
		view.push_input(event)
	assert_eq(screen.selected_id, &"inter")
	var legal: String = screen.notice.text
	view.remove_child(screen)
	view.add_child(screen)
	await _settle()
	assert_eq(screen.selected_id, &"inter")
	assert_eq(screen.notice.text, legal)
	watch_signals(screen)
	screen.handle_back()
	await _settle()
	screen.handle_back()
	assert_signal_emit_count(screen, "back_requested", 1)


func test_live_translation_preserves_legal_data() -> void:
	var screen: LicencesScreen = _screen(_view())
	assert_eq(screen.select_notice(&"pl-sources"), OK)
	var legal: String = screen.notice.text
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	await _settle()
	assert_eq(screen.notice.text, legal)
	var found_heading: bool = false
	for label: Node in screen.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.text == tr("settings.licences.sources"):
			found_heading = true
	assert_true(found_heading)
	var previous_font_size: int = screen.notice.get_theme_font_size(&"font_size")
	screen.theme = load("res://ui/theme/generated/theme_hc_130.tres")
	await _settle()
	assert_gt(screen.notice.get_theme_font_size(&"font_size"), previous_font_size)
	assert_eq(screen.notice.text, legal)
	assert_eq(screen.notice.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED)
	assert_eq(screen.top_bar.title_key, "settings.about.licences")
	assert_ne(tr("settings.licences.sources"), "settings.licences.sources")


func _capture(view: SubViewport, name_value: String) -> void:
	var directory: String = OS.get_environment("WOW_LICENCES_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	assert_false(image.is_empty())
	assert_eq(image.save_png(directory.path_join(name_value + ".png")), OK)


func test_twelve_case_layout_and_long_notice_scroll() -> void:
	for option: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + option, GalleryShell.OPTIONS[option])
	TranslationServer.reload_pseudolocalization()
	var sizes: Dictionary[String, Vector2i] = {
		"COMPACT": Vector2i(1080, 1920),
		"REGULAR": Vector2i(1080, 2340),
		"TABLET": Vector2i(1440, 1920)
	}
	for layout: String in sizes:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				TranslationServer.pseudolocalization_enabled = pseudo
				var view: SubViewport = _view(sizes[layout])
				var screen: LicencesScreen = SCENE.instantiate()
				screen.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				view.add_child(screen)
				await _settle()
				assert_true(screen.top_bar.fits)
				for row: ListRow in screen.rows.values():
					assert_lte(row.size.x, screen.scroll.size.x)
					assert_gte(row.size.y, float(Tokens.Touch.MIN_TARGET))
				var name_value: String = (
					"%s_%s_%s"
					% [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100"]
				)
				await _capture(view, name_value + "_index")
				var position: int = screen.scroll.scroll_vertical
				assert_eq(screen.select_notice(&"pl-sources"), OK)
				await _settle()
				assert_true(screen.top_bar.fits)
				assert_lte(screen.notice.size.x, screen.scroll.size.x)
				assert_eq(screen.scroll.scroll_horizontal, 0)
				assert_eq(screen.scroll.scroll_vertical, 0)
				await _capture(view, name_value + "_notice_top")
				screen.scroll.scroll_vertical = int(screen.scroll.get_v_scroll_bar().max_value)
				await _settle()
				assert_gt(screen.scroll.scroll_vertical, 0)
				assert_lte(
					screen.notice.get_global_rect().end.y, screen.scroll.get_global_rect().end.y + 1
				)
				await _capture(view, name_value + "_notice_bottom")
				screen.handle_back()
				await _settle()
				assert_eq(screen.scroll.scroll_vertical, position)
				screen.free()
