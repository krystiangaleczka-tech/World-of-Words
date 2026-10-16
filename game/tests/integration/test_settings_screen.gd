extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const SCENE: PackedScene = preload("res://features/settings/settings_screen.tscn")
const FIXTURE: Script = preload("res://tests/integration/test_level_hud.gd")
var save: SAVE
var storage: SaveStorage
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
	add_child_autofree(save)
	save.initialize(Clock.new())
	storage = FIXTURE.MemoryStorage.new()
	save.configure(storage)
	assert_eq(save.load(), OK)


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	Tokens.reduced_motion = _motion


func _view(size: Vector2i = Vector2i(1080, 1920)) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = size
	add_child_autofree(view)
	return view


func _screen(view: SubViewport) -> SettingsScreen:
	var screen: SettingsScreen = SCENE.instantiate()
	assert_eq(screen.configure(save), OK)
	view.add_child(screen)
	return screen


func test_configuration_requires_loaded_owner_and_copies_committed_values() -> void:
	var screen: SettingsScreen = SCENE.instantiate()
	assert_eq(screen.configure(null), ERR_UNCONFIGURED)
	var unloaded: SAVE = SAVE.new()
	assert_eq(screen.configure(unloaded), ERR_UNCONFIGURED)
	unloaded.free()
	screen.free()
	assert_eq(save.set_setting(&"sfx_volume", 0.4), OK)
	screen = _screen(_view())
	assert_eq(screen.configure(save), ERR_BUSY)
	assert_eq((screen.controls[&"sfx_volume"] as CatalogSlider).value, 0.4)
	var copy: Dictionary = screen.snapshot()
	copy.sfx_volume = 0.9
	assert_eq(screen.snapshot().sfx_volume, 0.4)
	storage.set("fail", true)
	assert_ne(save.set_setting(&"sfx_volume", 0.8), OK)
	assert_eq(save.get_setting(&"sfx_volume"), 0.8)
	assert_eq(screen.snapshot().sfx_volume, 0.4)


func test_native_control_intents_do_not_persist_or_claim_uncommitted_settings() -> void:
	var screen: SettingsScreen = _screen(_view())
	var before: Dictionary = save.committed_view()
	watch_signals(screen)
	(screen.controls[&"sfx_volume"] as CatalogSlider).preview_requested.emit(0.2)
	(screen.controls[&"haptics_enabled"] as Toggle).value_changed.emit(false)
	assert_signal_emit_count(screen, "setting_requested", 2)
	assert_eq(screen.controls[&"sfx_volume"].value, before.sections.settings.sfx_volume)
	assert_eq(screen.controls[&"haptics_enabled"].value, before.sections.settings.haptics_enabled)
	assert_eq_deep(save.committed_view(), before)


func test_owned_purchase_and_privacy_availability_are_explicit() -> void:
	var monetization: Dictionary = save.get_section(&"monetization")
	monetization.remove_forced_ads = true
	assert_eq(save.set_section(&"monetization", monetization), OK)
	assert_eq(save.flush(), OK)
	var screen: SettingsScreen = _screen(_view())
	assert_true(screen.rows[&"shop"].disabled)
	assert_eq(screen.rows[&"shop"].trailing_value, tr("settings.purchases.owned"))
	assert_false(screen.rows[&"privacy_options"].visible)
	screen.set_privacy_options_available(true)
	assert_true(screen.rows[&"privacy_options"].visible)
	watch_signals(screen)
	screen.rows[&"shop"].pressed.emit()
	screen.rows[&"restore"].pressed.emit()
	screen.rows[&"privacy_options"].pressed.emit()
	assert_signal_emit_count(screen, "action_requested", 2)
	assert_false(screen.rows[&"restore"].loading)


func test_all_external_actions_and_back_emit_intent_only() -> void:
	var screen: SettingsScreen = _screen(_view())
	watch_signals(screen)
	var before: Dictionary = save.committed_view()
	for key: StringName in [
		&"text_size", &"language", &"shop", &"restore", &"privacy_policy", &"licences", &"support"
	]:
		screen.rows[key].pressed.emit()
	screen.back.pressed.emit()
	assert_signal_emit_count(screen, "action_requested", 7)
	assert_signal_emit_count(screen, "back_requested", 1)
	assert_eq_deep(save.committed_view(), before)
	assert_true(
		screen.information.text.contains(save.committed_view().sections.meta.install_id.left(8))
	)


func test_keyboard_activation_and_reentry_do_not_duplicate_subscriptions() -> void:
	var view: SubViewport = _view()
	var screen: SettingsScreen = _screen(view)
	view.remove_child(screen)
	view.add_child(screen)
	for frame: int in range(3):
		await get_tree().process_frame
	watch_signals(screen)
	var toggle: Toggle = screen.controls[&"haptics_enabled"]
	toggle.grab_focus()
	for down: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = down
		view.push_input(event)
	assert_signal_emit_count(screen, "setting_requested", 1)
	assert_eq(save.set_setting(&"haptics_enabled", false), OK)
	assert_false(toggle.value)
	screen.back.pressed.emit()
	assert_signal_emit_count(screen, "back_requested", 1)


func test_native_layout_matrix_scrolls_to_about_without_horizontal_overflow() -> void:
	for option: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + option, GalleryShell.OPTIONS[option])
	TranslationServer.reload_pseudolocalization()
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				TranslationServer.pseudolocalization_enabled = pseudo
				var view: SubViewport = _view(dimensions)
				var screen: SettingsScreen = SCENE.instantiate()
				assert_eq(screen.configure(save), OK)
				screen.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				view.add_child(screen)
				for frame: int in range(5):
					await get_tree().process_frame
				assert_true(screen.top_bar.fits)
				for row: ListRow in screen.rows.values():
					assert_lte(row.size.x, screen.scroll.size.x)
					if row.visible:
						assert_gte(row.size.y, float(Tokens.Touch.MIN_TARGET))
				screen.scroll.scroll_vertical = int(screen.scroll.get_v_scroll_bar().max_value)
				await get_tree().process_frame
				assert_gt(screen.scroll.scroll_vertical, 0)
				assert_true(
					screen.scroll.get_global_rect().intersects(screen.information.get_global_rect())
				)
				screen.free()


func test_live_theme_change_updates_native_background_without_emitting_intent() -> void:
	var screen: SettingsScreen = _screen(_view())
	watch_signals(screen)
	screen.theme = load("res://ui/theme/generated/theme_hc_130.tres")
	await get_tree().process_frame
	var surfaces: Array[Node] = screen.find_children("*", "ColorRect", true, false)
	assert_gt(surfaces.size(), 0)
	assert_eq((surfaces[0] as ColorRect).color, screen.get_theme_color(&"BG", &"Palette"))
	assert_signal_emit_count(screen, "setting_requested", 0)
