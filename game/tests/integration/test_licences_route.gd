extends GutTest

const ROUTE: Script = preload("res://features/settings/licences_route.gd")
const SETTINGS: PackedScene = preload("res://features/settings/settings_screen.tscn")
const LICENCES: PackedScene = preload("res://features/settings/licences_screen.tscn")
const SAVE: Script = preload("res://services/save.gd")
const MEMORY: Script = preload("res://tests/integration/test_level_hud.gd")
const CREDITS: Script = preload("res://services/settings_credits.gd")
var save: SAVE
var _views: Array[SubViewport] = []
var _locale: String
var _pseudo: bool
var _motion: bool


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	_motion = Tokens.reduced_motion
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	Tokens.reduced_motion = true
	save = SAVE.new()
	add_child(save)
	save.initialize(Clock.new())
	save.configure(MEMORY.MemoryStorage.new())
	assert_eq(save.load(), OK)


func after_each() -> void:
	for view: SubViewport in _views:
		view.free()
	_views.clear()
	if is_instance_valid(save):
		save.free()
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	Tokens.reduced_motion = _motion


func _stack(size: Vector2i = Vector2i(1080, 1920), theme_value: Theme = null) -> Dictionary:
	var view: SubViewport = SubViewport.new()
	view.size = size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	_views.append(view)
	var settings: SettingsScreen = SETTINGS.instantiate()
	assert_eq(settings.configure(save), OK)
	settings.theme = theme_value
	view.add_child(settings)
	var licences: LicencesScreen = LICENCES.instantiate()
	licences.hide()
	view.add_child(licences)
	var route: ROUTE = ROUTE.new()
	view.add_child(route)
	assert_eq(route.configure(settings, licences), OK)
	return {"view": view, "settings": settings, "licences": licences, "route": route}


func _settle() -> void:
	for frame: int in range(5):
		await get_tree().process_frame


func test_default_invalid_bindings_and_configure_do_not_open_or_replace() -> void:
	var fresh: ROUTE = ROUTE.new()
	add_child(fresh)
	assert_eq(fresh.open(), ERR_UNCONFIGURED)
	assert_false(fresh.handle_back())
	assert_eq(fresh.snapshot().state, &"unavailable")
	fresh.free()
	var stack: Dictionary = _stack()
	assert_eq(stack.route.configure(null, stack.licences), ERR_UNCONFIGURED)
	assert_eq(stack.route.configure(stack.settings, stack.settings), ERR_UNCONFIGURED)
	assert_eq(stack.route.snapshot().state, &"settings")
	assert_true(stack.settings.visible)
	assert_false(stack.licences.visible)


func test_actual_intent_two_stage_back_restores_scroll_focus_and_save() -> void:
	var s: Dictionary = _stack()
	await _settle()
	var before: Dictionary = save.committed_view()
	s.settings.scroll.ensure_control_visible(s.settings.rows[&"licences"])
	await _settle()
	var position: int = s.settings.scroll.scroll_vertical
	s.settings.rows[&"licences"].grab_focus()
	s.settings.rows[&"licences"].pressed.emit()
	assert_eq(s.route.snapshot().state, &"licences")
	assert_false(s.settings.is_visible_in_tree())
	assert_true(s.licences.is_visible_in_tree())
	assert_eq(s.route.open(), ERR_ALREADY_IN_USE)
	assert_eq(s.route.configure(s.settings, s.licences), ERR_BUSY)
	s.licences.rows[&"godot"].pressed.emit()
	assert_eq(s.licences.notice.text, CREDITS.entries()[0].notice)
	assert_true(s.route.handle_back())
	await _settle()
	assert_eq(s.licences.selected_id, &"")
	assert_eq(s.route.snapshot().state, &"licences")
	s.licences.back.pressed.emit()
	await _settle()
	assert_eq(s.route.snapshot().state, &"settings")
	assert_eq(s.settings.scroll.scroll_vertical, position)
	assert_true(s.settings.rows[&"licences"].has_focus())
	assert_false(s.route.handle_back())
	assert_eq(save.committed_view(), before)


func test_sheets_block_open_and_other_intents_are_untouched() -> void:
	var s: Dictionary = _stack()
	watch_signals(s.settings)
	s.settings.rows[&"support"].pressed.emit()
	assert_signal_emitted_with_parameters(s.settings, "action_requested", [&"support"])
	assert_false(s.licences.visible)
	s.settings.text_sheet.open()
	assert_eq(s.route.open(), ERR_BUSY)
	s.settings.text_sheet.close()
	await _settle()
	assert_eq(s.route.open(), OK)


func test_visibility_reentry_and_owner_loss_during_open_do_not_show_orphan() -> void:
	var s: Dictionary = _stack()
	var attempts: Array[Error] = []
	var nested: Callable = func() -> void:
		attempts.append(s.route.open())
		attempts.append(s.route.configure(s.settings, s.licences))
	s.licences.visibility_changed.connect(nested)
	assert_eq(s.route.open(), OK)
	s.licences.visibility_changed.disconnect(nested)
	assert_eq(attempts, [ERR_BUSY, ERR_BUSY])
	assert_true(s.route.handle_back())
	var remove_owner: Callable = func() -> void:
		if not s.settings.visible:
			s.view.remove_child(s.route)
	s.settings.visibility_changed.connect(remove_owner)
	assert_eq(s.route.open(), ERR_UNCONFIGURED)
	s.settings.visibility_changed.disconnect(remove_owner)
	assert_false(s.licences.visible)
	assert_true(s.settings.visible)
	s.route.free()


func test_theme_locale_and_retained_selection_remain_verbatim() -> void:
	var s: Dictionary = _stack()
	var previous: Theme = load("res://ui/theme/generated/theme_default_115.tres")
	s.licences.theme = previous
	assert_eq(s.route.open(), OK)
	assert_eq(s.licences.select_notice(&"godot"), OK)
	var legal: String = s.licences.notice.text
	TranslationServer.set_locale("en")
	s.settings.theme = load("res://ui/theme/generated/theme_hc_130.tres")
	await _settle()
	assert_eq(s.licences.theme, s.settings.theme)
	assert_eq(s.licences.notice.text, legal)
	s.route.handle_back()
	s.route.handle_back()
	await _settle()
	assert_eq(s.licences.theme, previous)


func test_owner_and_router_exit_require_explicit_reconfigure_without_duplicate_listeners() -> void:
	var s: Dictionary = _stack()
	assert_eq(s.route.open(), OK)
	s.view.remove_child(s.licences)
	assert_true(s.settings.visible)
	assert_false(s.licences.visible)
	assert_eq(s.route.snapshot().state, &"unavailable")
	s.view.add_child(s.licences)
	assert_eq(s.route.open(), ERR_UNCONFIGURED)
	assert_eq(s.route.configure(s.settings, s.licences), OK)
	s.view.remove_child(s.route)
	s.view.add_child(s.route)
	assert_eq(s.route.snapshot().state, &"unavailable")
	assert_eq(s.route.configure(s.settings, s.licences), OK)
	assert_eq(s.settings.action_requested.get_connections().size(), 1)
	s.settings.rows[&"licences"].pressed.emit()
	assert_eq(s.route.snapshot().state, &"licences")


func _capture(view: SubViewport, name_value: String) -> void:
	var directory: String = OS.get_environment("WOW_LICENCES_ROUTE_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	assert_false(image.is_empty())
	assert_eq(image.save_png(directory.path_join(name_value + ".png")), OK)


func test_native_twelve_case_actual_licences_route() -> void:
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
				var theme_value: Theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				var s: Dictionary = _stack(sizes[layout], theme_value)
				await _settle()
				var name_value: String = (
					"%s_%s_%s"
					% [layout, "PSEUDO" if pseudo else "PL", "hc130" if hc else "default100"]
				)
				s.settings.scroll.ensure_control_visible(s.settings.rows[&"licences"])
				await _settle()
				s.settings.rows[&"licences"].grab_focus()
				s.settings.rows[&"licences"].pressed.emit()
				await _settle()
				assert_true(s.licences.top_bar.fits)
				await _capture(s.view, name_value + "_index")
				s.licences.rows[&"godot"].pressed.emit()
				await _settle()
				assert_eq(s.licences.notice.text, CREDITS.entries()[0].notice)
				assert_lte(s.licences.notice.size.x, s.licences.scroll.size.x)
				assert_eq(s.licences.scroll.scroll_horizontal, 0)
				await _capture(s.view, name_value + "_detail")
				assert_true(s.route.handle_back())
				assert_true(s.route.handle_back())
				await _settle()
				assert_true(s.settings.rows[&"licences"].has_focus())
				assert_true(s.settings.top_bar.fits)
				await _capture(s.view, name_value + "_returned")
				_views.erase(s.view)
				s.view.free()


func test_lost_profile_topbar_back_invalidates_route_and_restores_settings() -> void:
	var s: Dictionary = _stack()
	assert_eq(s.route.open(), OK)
	save.free()
	s.licences.back.pressed.emit()
	assert_eq(s.route.snapshot().state, &"unavailable")
	assert_true(s.settings.visible)
	assert_false(s.licences.visible)


func test_profile_loss_during_open_visibility_cleans_up_route() -> void:
	var s: Dictionary = _stack()
	var lose: Callable = func() -> void:
		if not s.settings.visible and is_instance_valid(save):
			save.free()
	s.settings.visibility_changed.connect(lose)
	assert_eq(s.route.open(), ERR_UNCONFIGURED)
	s.settings.visibility_changed.disconnect(lose)
	assert_eq(s.route.snapshot().state, &"unavailable")
	assert_true(s.settings.visible)
	assert_false(s.licences.visible)
	assert_eq(s.settings.action_requested.get_connections().size(), 0)


func test_profile_loss_during_return_visibility_restores_settings_and_disconnects() -> void:
	var s: Dictionary = _stack()
	assert_eq(s.route.open(), OK)
	var lose: Callable = func() -> void:
		if not s.licences.visible and is_instance_valid(save):
			save.free()
	s.licences.visibility_changed.connect(lose)
	assert_true(s.route.handle_back())
	s.licences.visibility_changed.disconnect(lose)
	assert_eq(s.route.snapshot().state, &"unavailable")
	assert_true(s.settings.visible)
	assert_false(s.licences.visible)
	assert_eq(s.settings.action_requested.get_connections().size(), 0)


func test_reconfigure_before_deferred_return_cannot_steal_new_binding_focus() -> void:
	var first: Dictionary = _stack()
	var second: Dictionary = _stack()
	await _settle()
	second.route.free()
	first.settings.rows[&"licences"].grab_focus()
	assert_eq(first.route.open(), OK)
	assert_true(first.route.handle_back())
	assert_eq(first.route.configure(second.settings, second.licences), OK)
	second.settings.rows[&"support"].grab_focus()
	await _settle()
	assert_true(second.settings.rows[&"support"].has_focus())
	assert_eq(first.route.snapshot().state, &"settings")
