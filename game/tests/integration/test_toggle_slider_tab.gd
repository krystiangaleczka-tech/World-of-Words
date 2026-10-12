extends GutTest

const ICON: Texture2D = preload("res://assets/icons/map-pinned.svg")
const HC: Theme = preload("res://ui/theme/generated/theme_hc_130.tres")
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


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	Tokens.reduced_motion = _motion


func _viewport() -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1080, 1920)
	add_child_autofree(view)
	return view


func _mouse(view: SubViewport, point: Vector2, down: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = point
	view.push_input(event)


func _click(view: SubViewport, point: Vector2) -> void:
	_mouse(view, point, true)
	_mouse(view, point, false)


func _move(view: SubViewport, point: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	view.push_input(event)


func _key(view: SubViewport, code: Key, down: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = down
	view.push_input(event)


func _slider(view: SubViewport, sound: bool = true) -> CatalogSlider:
	var slider: CatalogSlider = CatalogSlider.new()
	slider.configure(0.5, "gallery.settings.sound", sound)
	slider.size = Vector2(600, Tokens.Touch.MIN_TARGET)
	view.add_child(slider)
	return slider


func _toggle(view: SubViewport) -> Toggle:
	var toggle: Toggle = Toggle.new()
	toggle.configure(false, "gallery.settings.sound")
	view.add_child(toggle)
	return toggle


func _tab(view: SubViewport) -> NavTab:
	var tab: NavTab = NavTab.new()
	tab.configure(ICON, "gallery.settings.tab", "gallery.settings.locked")
	tab.size.x = 700
	view.add_child(tab)
	return tab


func test_toggle_native_pointer_keyboard_and_silent_program_value() -> void:
	var view: SubViewport = _viewport()
	var toggle: Toggle = _toggle(view)
	await get_tree().process_frame
	watch_signals(toggle)
	_click(view, toggle.get_global_rect().get_center())
	assert_true(toggle.value)
	assert_signal_emitted_with_parameters(toggle, "value_changed", [true])
	toggle.grab_focus()
	_key(view, KEY_SPACE, true)
	_key(view, KEY_SPACE, false)
	assert_false(toggle.value)
	assert_signal_emit_count(toggle, "value_changed", 2)
	toggle.value = true
	assert_true(toggle.button_pressed)
	assert_signal_emit_count(toggle, "value_changed", 2)
	toggle.disabled = true
	_click(view, toggle.get_global_rect().get_center())
	_key(view, KEY_SPACE, true)
	_key(view, KEY_SPACE, false)
	assert_signal_emit_count(toggle, "value_changed", 2)
	assert_gte(toggle.size.y, float(Tokens.Touch.MIN_TARGET))
	assert_gte(toggle.size.x, float(Tokens.Touch.MIN_TARGET * 2))


func test_toggle_config_atomic_required_name_and_shortcut() -> void:
	var view: SubViewport = _viewport()
	var toggle: Toggle = Toggle.new()
	view.add_child(toggle)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_K
	key.pressed = true
	var shortcut: Shortcut = Shortcut.new()
	shortcut.events = [key]
	toggle.shortcut = shortcut
	watch_signals(toggle)
	view.push_input(key)
	_click(view, toggle.get_global_rect().get_center())
	assert_signal_emit_count(toggle, "value_changed", 0)
	assert_eq(toggle.configure(true, " "), ERR_INVALID_PARAMETER)
	assert_false(toggle.value)
	assert_eq(toggle.configure(true, "gallery.settings.sound"), OK)
	toggle.a11y_label_key = ""
	assert_eq(toggle.a11y_label_key, "gallery.settings.sound")
	view.push_input(key)
	assert_false(toggle.value)
	assert_signal_emit_count(toggle, "value_changed", 1)


func test_toggle_theme_copy_reentry_and_live_motion_reduction() -> void:
	var view: SubViewport = _viewport()
	var toggle: Toggle = _toggle(view)
	toggle.value = true
	toggle.theme = HC
	assert_eq(
		(toggle.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Tokens.PaletteHC.PRIMARY
	)
	assert_eq(toggle.accessibility_description, toggle.tr("ui.toggle.on"))
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	assert_eq(toggle.accessibility_name, toggle.tr(toggle.a11y_label_key))
	Tokens.reduced_motion = false
	toggle.highlighted = true
	await get_tree().process_frame
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_eq(toggle.scale, Vector2.ONE)
	view.remove_child(toggle)
	view.add_child(toggle)
	watch_signals(toggle)
	_click(view, toggle.get_global_rect().get_center())
	assert_signal_emit_count(toggle, "value_changed", 1)


func test_slider_atomic_finite_clamp_step_required_label_and_thumb() -> void:
	var view: SubViewport = _viewport()
	var slider: CatalogSlider = CatalogSlider.new()
	view.add_child(slider)
	assert_false(slider.editable)
	assert_eq(slider.configure(NAN, "gallery.settings.sound"), ERR_INVALID_PARAMETER)
	assert_eq(slider.configure(INF, "gallery.settings.sound"), ERR_INVALID_PARAMETER)
	assert_eq(slider.configure(0.5, ""), ERR_INVALID_PARAMETER)
	assert_eq(slider.configure(2, "gallery.settings.sound"), OK)
	assert_true(slider.editable)
	assert_eq(slider.value, 1.0)
	slider.configure(-1, "gallery.settings.sound")
	assert_eq(slider.value, 0.0)
	slider.configure(0.54, "gallery.settings.sound")
	assert_almost_eq(slider.value, 0.5, 0.0001)
	assert_almost_eq(slider.step, 0.1, 0.0001)
	assert_eq(slider.accessibility_description, "50%")
	for state: StringName in [&"grabber", &"grabber_highlight", &"grabber_disabled"]:
		assert_gte(slider.get_theme_icon(state).get_width(), Tokens.Touch.MIN_TARGET)
		assert_gte(slider.get_theme_icon(state).get_height(), Tokens.Touch.MIN_TARGET)
	assert_gte(slider.size.y, float(Tokens.Touch.MIN_TARGET))


func test_slider_mouse_sound_preview_only_on_changed_release() -> void:
	var view: SubViewport = _viewport()
	var slider: CatalogSlider = _slider(view)
	await get_tree().process_frame
	watch_signals(slider)
	var start: Vector2 = slider.get_global_rect().get_center()
	_mouse(view, start, true)
	_move(view, start + Vector2(150, 0))
	assert_gt(slider.value, 0.5)
	assert_signal_emit_count(slider, "preview_requested", 0)
	_mouse(view, start + Vector2(150, 0), false)
	assert_signal_emit_count(slider, "preview_requested", 1)
	assert_signal_emitted_with_parameters(slider, "preview_requested", [slider.value])
	var current: Vector2 = Vector2(
		Tokens.Touch.MIN_TARGET / 2.0 + slider.value * (slider.size.x - Tokens.Touch.MIN_TARGET),
		slider.size.y / 2
	)
	_click(view, current)
	assert_signal_emit_count(slider, "preview_requested", 1)
	slider.value = 0.2
	assert_signal_emit_count(slider, "preview_requested", 1)
	slider.configure(0.5, "gallery.settings.music", false)
	_mouse(view, start, true)
	_move(view, start + Vector2(150, 0))
	_mouse(view, start + Vector2(150, 0), false)
	assert_signal_emit_count(slider, "preview_requested", 1)


func test_slider_keyboard_release_preview_and_cancel_disable_focus_loss() -> void:
	var view: SubViewport = _viewport()
	var slider: CatalogSlider = _slider(view)
	slider.grab_focus()
	watch_signals(slider)
	_key(view, KEY_RIGHT, true)
	assert_almost_eq(slider.value, 0.6, 0.0001)
	assert_signal_emit_count(slider, "preview_requested", 0)
	_key(view, KEY_RIGHT, false)
	assert_signal_emit_count(slider, "preview_requested", 1)
	_key(view, KEY_RIGHT, true)
	_key(view, KEY_ESCAPE, true)
	_key(view, KEY_RIGHT, false)
	assert_signal_emit_count(slider, "preview_requested", 1)
	_key(view, KEY_RIGHT, true)
	slider.set_available(false)
	_key(view, KEY_RIGHT, false)
	assert_signal_emit_count(slider, "preview_requested", 1)
	slider.set_available(true)
	_key(view, KEY_RIGHT, true)
	slider.release_focus()
	_key(view, KEY_RIGHT, false)
	assert_signal_emit_count(slider, "preview_requested", 1)


func test_slider_gesture_reconfigure_exit_reentry_copy_theme() -> void:
	var view: SubViewport = _viewport()
	var slider: CatalogSlider = _slider(view)
	await get_tree().process_frame
	watch_signals(slider)
	var start: Vector2 = slider.get_global_rect().get_center()
	_mouse(view, start, true)
	_move(view, start + Vector2(150, 0))
	slider.configure(0.5, "gallery.settings.sound", true)
	_mouse(view, start + Vector2(150, 0), false)
	assert_signal_emit_count(slider, "preview_requested", 0)
	view.remove_child(slider)
	view.add_child(slider)
	slider.theme = HC
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	assert_eq(slider.accessibility_name, slider.tr(slider.a11y_label_key))
	assert_eq(
		(slider.get_theme_stylebox("grabber_area") as StyleBoxFlat).bg_color,
		Tokens.PaletteHC.PRIMARY
	)
	slider.grab_focus()
	_key(view, KEY_RIGHT, true)
	_key(view, KEY_RIGHT, false)
	assert_signal_emit_count(slider, "preview_requested", 1)


func test_tab_native_intent_caller_selection_lock_and_new_cues() -> void:
	var view: SubViewport = _viewport()
	var tab: NavTab = _tab(view)
	await get_tree().process_frame
	watch_signals(tab)
	_click(view, tab.global_position + Vector2(100, 50))
	assert_signal_emit_count(tab, "pressed", 1)
	assert_false(tab.selected)
	tab.selected = true
	assert_true((tab.find_children("*", "TextureRect", true, false)[1] as TextureRect).visible)
	_click(view, tab.global_position + Vector2(100, 50))
	assert_true(tab.selected)
	assert_signal_emit_count(tab, "pressed", 2)
	tab.locked = true
	assert_eq(tab.accessibility_description, tab.tr(tab.locked_label_key))
	assert_same(
		(tab.find_children("*", "TextureRect", true, false)[0] as TextureRect).texture, NavTab.LOCK
	)
	_click(view, tab.global_position + Vector2(100, 50))
	assert_signal_emit_count(tab, "pressed", 2)
	tab.locked = false
	tab.highlighted = true
	assert_true((tab.find_children("*", "Badge", true, false)[0] as Badge).visible)
	tab.implemented = false
	assert_false(tab.visible)


func test_tab_invalid_config_reentry_copy_theme_and_inactive_shortcut_siblings() -> void:
	var view: SubViewport = _viewport()
	var tab: NavTab = _tab(view)
	assert_eq(tab.configure(null, "gallery.settings.sound"), ERR_INVALID_PARAMETER)
	assert_eq(tab.configure(ICON, ""), ERR_INVALID_PARAMETER)
	assert_eq(tab.label_key, "gallery.settings.tab")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_K
	key.pressed = true
	var shortcut: Shortcut = Shortcut.new()
	shortcut.events = [key]
	tab.shortcut = shortcut
	var sibling: Button = Button.new()
	sibling.position.y = 1200
	sibling.shortcut = shortcut
	view.add_child(sibling)
	watch_signals(tab)
	watch_signals(sibling)
	tab.locked = true
	view.push_input(key)
	assert_signal_emit_count(tab, "pressed", 0)
	assert_signal_emit_count(sibling, "pressed", 1)
	tab.locked = false
	tab.implemented = false
	view.push_input(key)
	assert_signal_emit_count(sibling, "pressed", 2)
	tab.implemented = true
	view.remove_child(tab)
	view.add_child(tab)
	tab.theme = HC
	tab.selected = true
	TranslationServer.set_locale("en")
	assert_eq(tab.accessibility_name, tab.tr(tab.label_key))
	assert_eq((tab.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Tokens.PaletteHC.PRIMARY)


func test_gallery_inventory_scroll_and_pseudo_hc_fit() -> void:
	var gallery: GalleryShell = load("res://ui/gallery/gallery.tscn").instantiate()
	add_child_autofree(gallery)
	assert_eq(
		gallery.configure(&"COMPACT", &"PSEUDO", true, 130, true, true, &"SettingsControls"), OK
	)
	for frame: int in 5:
		await get_tree().process_frame
	var screen: ScreenScaffold = gallery.preview_screen()
	assert_eq(screen.find_children("*", "Toggle", true, false).size(), 4)
	assert_eq(screen.find_children("*", "CatalogSlider", true, false).size(), 6)
	assert_eq(screen.find_children("*", "NavTab", true, false).size(), 5)
	var scroll: ScrollContainer = (
		screen.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	)
	assert_true(scroll.get_v_scroll_bar().visible)
	for control: Control in screen.find_children("*", "Control", true, false):
		if control is Toggle or control is CatalogSlider or control is NavTab:
			assert_lte(control.size.x, screen.body.size.x)
	gallery.free()


func test_slider_native_touch_changed_release_and_cancellation() -> void:
	var view: SubViewport = _viewport()
	var slider: CatalogSlider = _slider(view)
	await get_tree().process_frame
	watch_signals(slider)
	var start: Vector2 = slider.get_global_rect().get_center()
	var down: InputEventScreenTouch = InputEventScreenTouch.new()
	down.index = 3
	down.pressed = true
	down.position = start
	view.push_input(down)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 3
	drag.position = start + Vector2(150, 0)
	drag.relative = Vector2(150, 0)
	view.push_input(drag)
	assert_gt(slider.value, 0.5)
	var secondary: InputEventScreenTouch = InputEventScreenTouch.new()
	secondary.index = 4
	secondary.canceled = true
	secondary.position = drag.position
	view.push_input(secondary)
	assert_signal_emit_count(slider, "preview_requested", 0)
	var up: InputEventScreenTouch = InputEventScreenTouch.new()
	up.index = 3
	up.position = drag.position
	view.push_input(up)
	assert_signal_emit_count(slider, "preview_requested", 1)
	slider.configure(0.5, "gallery.settings.sound", true)
	view.push_input(down)
	view.push_input(drag)
	up.canceled = true
	view.push_input(up)
	assert_signal_emit_count(slider, "preview_requested", 1)


func test_slider_program_change_during_key_and_atomic_availability_cancel() -> void:
	var view: SubViewport = _viewport()
	var slider: CatalogSlider = _slider(view)
	slider.configure(1, "gallery.settings.sound", true)
	slider.grab_focus()
	watch_signals(slider)
	_key(view, KEY_RIGHT, true)
	slider.value = 0.5
	_key(view, KEY_RIGHT, false)
	assert_signal_emit_count(slider, "preview_requested", 0)
	_key(view, KEY_RIGHT, true)
	slider.set_available(false)
	slider.set_available(true)
	_key(view, KEY_RIGHT, false)
	assert_signal_emit_count(slider, "preview_requested", 0)


func test_selected_tab_focus_ring_and_lock_theme_transition() -> void:
	var view: SubViewport = _viewport()
	var tab: NavTab = _tab(view)
	tab.selected = true
	assert_false((tab.get_theme_stylebox("focus") as StyleBoxFlat).draw_center)
	assert_eq((tab.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Tokens.Palette.PRIMARY)
	tab.locked = true
	assert_eq((tab.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Tokens.Palette.SURFACE)
	tab.locked = false
	assert_eq((tab.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Tokens.Palette.PRIMARY)


func test_slider_touch_teardown_does_not_consume_later_emulated_sibling_click() -> void:
	var view: SubViewport = _viewport()
	var slider: CatalogSlider = _slider(view)
	var sibling: Button = Button.new()
	sibling.position = Vector2(100, 500)
	sibling.size = Vector2(200, 144)
	view.add_child(sibling)
	var down: InputEventScreenTouch = InputEventScreenTouch.new()
	down.index = 7
	down.pressed = true
	down.position = slider.get_global_rect().get_center()
	view.push_input(down)
	view.remove_child(slider)
	view.add_child(slider)
	watch_signals(sibling)
	for pressed: bool in [true, false]:
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.device = InputEvent.DEVICE_ID_EMULATION
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		mouse.position = sibling.get_global_rect().get_center()
		view.push_input(mouse)
	assert_signal_emit_count(sibling, "pressed", 1)
