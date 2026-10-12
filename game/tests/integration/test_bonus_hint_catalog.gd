extends GutTest

const HC: Theme = preload("res://ui/theme/generated/theme_hc_130.tres")
var _motion: bool
var _locale: String
var _pseudo: bool


func before_each() -> void:
	_motion = Tokens.reduced_motion
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	Tokens.reduced_motion = true
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false


func after_each() -> void:
	Tokens.reduced_motion = _motion
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo


func _viewport() -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1080, 1920)
	add_child_autofree(view)
	return view


func _click(view: SubViewport, point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		view.push_input(event)


func _activate(view: SubViewport, control: Control) -> void:
	if (
		control.focus_mode != Control.FOCUS_NONE
		and not (control is BaseButton and control.disabled)
	):
		control.grab_focus()
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = pressed
		view.push_input(event)


func _step(seconds: float) -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		tween.custom_step(seconds)


func _meter(view: SubViewport, count: int = 0, target: int = 10) -> BonusMeter:
	var meter: BonusMeter = BonusMeter.new()
	meter.configure(count, target)
	meter.size.x = 800
	view.add_child(meter)
	return meter


func _hint(view: SubViewport, kind: StringName = &"hint", count: int = 3) -> HintButton:
	var hint: HintButton = HintButton.new()
	hint.configure(kind, count, 99999)
	hint.size.x = 500
	view.add_child(hint)
	return hint


func test_bonus_exact_integer_config_over_target_and_atomic_invalid() -> void:
	var view: SubViewport = _viewport()
	var meter: BonusMeter = _meter(view, 5)
	assert_eq(meter.count, 5)
	assert_eq(meter.target, 10)
	var progress: CatalogProgressBar = (
		meter.find_children("*", "CatalogProgressBar", true, false)[0] as CatalogProgressBar
	)
	assert_eq(progress.value, 0.5)
	assert_eq(meter.configure(-1, 10), ERR_INVALID_PARAMETER)
	assert_eq(meter.configure(0, 0), ERR_INVALID_PARAMETER)
	assert_eq(meter.set_count(-1), ERR_INVALID_PARAMETER)
	assert_eq(meter.count, 5)
	assert_eq(meter.target, 10)
	assert_eq(meter.configure(9223372036854775806, 9223372036854775807), OK)
	assert_lt(progress.displayed_value, 1.0)
	assert_false((meter.find_child("Complete", true, false) as TextureRect).visible)
	assert_ne(meter.state, &"full")
	assert_eq(meter.configure(9223372036854775807, 9223372036854775806), OK)
	assert_eq(meter.accessibility_description, "9223372036854775807 / 9223372036854775806")
	assert_eq(progress.value, 1.0)
	assert_eq(meter.state, &"full")


func test_bonus_native_partial_full_disabled_and_full_cues() -> void:
	var view: SubViewport = _viewport()
	var meter: BonusMeter = _meter(view, 5)
	await get_tree().process_frame
	watch_signals(meter)
	_click(view, meter.get_global_rect().get_center())
	assert_signal_emit_count(meter, "pressed", 0)
	assert_eq(meter.focus_mode, Control.FOCUS_NONE)
	meter.set_count(10, false)
	await get_tree().process_frame
	_click(view, meter.get_global_rect().get_center())
	assert_signal_emit_count(meter, "open_requested", 1)
	_activate(view, meter)
	assert_signal_emit_count(meter, "open_requested", 2)
	assert_eq(meter.accessibility_name, meter.tr("ui.bonus.open"))
	assert_same(
		(meter.find_children("*", "TextureRect", true, false)[0] as TextureRect).texture,
		BonusMeter.GIFT
	)
	assert_true((meter.find_child("Complete", true, false) as TextureRect).visible)
	meter.disabled = true
	_click(view, meter.get_global_rect().get_center())
	_activate(view, meter)
	assert_signal_emit_count(meter, "open_requested", 2)


func test_partial_bonus_shortcuts_preserve_sibling_and_unconfigured_rejects_count() -> void:
	var view: SubViewport = _viewport()
	var meter: BonusMeter = BonusMeter.new()
	view.add_child(meter)
	assert_eq(meter.set_count(3), ERR_INVALID_PARAMETER)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_K
	key.pressed = true
	var shortcut: Shortcut = Shortcut.new()
	shortcut.events = [key]
	meter.shortcut = shortcut
	var sibling: Button = Button.new()
	sibling.shortcut = shortcut
	sibling.position.y = 1200
	view.add_child(sibling)
	watch_signals(meter)
	watch_signals(sibling)
	view.push_input(key)
	assert_signal_emit_count(meter, "pressed", 0)
	assert_signal_emit_count(sibling, "pressed", 1)
	meter.configure(5, 10)
	view.push_input(key)
	assert_signal_emit_count(sibling, "pressed", 2)


func test_bonus_fill_interruption_already_and_live_reduction() -> void:
	var view: SubViewport = _viewport()
	var meter: BonusMeter = _meter(view)
	Tokens.reduced_motion = false
	meter.set_count(10)
	assert_eq(meter.state, &"filling")
	assert_eq(meter.focus_mode, Control.FOCUS_NONE)
	_step(Tokens.dur(Tokens.Motion.BASE) / 2)
	assert_eq(meter.set_count(-1), ERR_INVALID_PARAMETER)
	assert_eq(meter.state, &"filling")
	meter.set_count(2)
	_step(Tokens.dur(Tokens.Motion.BASE + Tokens.Motion.FAST))
	assert_eq(meter.count, 2)
	assert_ne(meter.state, &"full")
	assert_eq(meter.pulse_already(), OK)
	assert_eq(meter.state, &"already")
	_step(Tokens.dur(Tokens.Motion.FAST) / 2)
	assert_almost_eq(meter.scale.x, Tokens.Action.ALREADY_SCALE, 0.0001)
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_eq(meter.scale, Vector2.ONE)
	assert_eq(meter.state, &"already")
	assert_true((meter.find_children("*", "Badge", true, false)[0] as Badge).visible)
	meter.set_count(10)
	assert_eq(meter.state, &"full")


func test_bonus_fill_completion_pop_endpoint_copy_theme_and_reentry() -> void:
	var view: SubViewport = _viewport()
	var meter: BonusMeter = _meter(view)
	meter.theme = HC
	Tokens.reduced_motion = false
	meter.set_count(10)
	_step(Tokens.dur(Tokens.Motion.BASE + Tokens.Motion.STAGGER))
	assert_eq(meter.state, &"full")
	_step(Tokens.dur(Tokens.Motion.FAST) / 2)
	var gift: TextureRect = meter.find_children("*", "TextureRect", true, false)[0] as TextureRect
	assert_gt(gift.scale.x, 1.0)
	_step(Tokens.dur(Tokens.Motion.FAST))
	assert_eq(gift.scale, Vector2.ONE)
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	assert_eq(meter.accessibility_name, meter.tr("ui.bonus.open"))
	assert_eq(
		(meter.get_theme_stylebox("normal") as StyleBoxFlat).border_color, Tokens.PaletteHC.BONUS
	)
	view.remove_child(meter)
	view.add_child(meter)
	watch_signals(meter)
	_activate(view, meter)
	assert_signal_emit_count(meter, "open_requested", 1)


func test_hint_legacy_unchanged_and_final_config_atomic() -> void:
	var view: SubViewport = _viewport()
	var hint: HintButton = HintButton.new()
	view.add_child(hint)
	assert_false(hint.catalog_mode)
	assert_eq(hint.text, hint.tr("level.hud.hint"))
	assert_eq(hint.configure(&"shuffle", 1, 5), ERR_INVALID_PARAMETER)
	assert_eq(hint.configure(&"hint", -1, 5), ERR_INVALID_PARAMETER)
	assert_false(hint.catalog_mode)
	assert_eq(hint.set_amounts(3, 5), ERR_UNCONFIGURED)
	assert_eq(hint.configure(&"reveal", 3, 5), OK)
	assert_true(hint.catalog_mode)
	assert_eq(hint.kind, &"reveal")
	assert_same(hint.icon, HintButton.GLYPHS[&"reveal"])
	assert_eq(hint.configure(&"hint", 0, -1), ERR_INVALID_PARAMETER)
	assert_eq(hint.kind, &"reveal")
	assert_eq(hint.count, 3)


func test_hint_count_price_native_pointer_keyboard_and_disabled() -> void:
	var view: SubViewport = _viewport()
	var hint: HintButton = _hint(view)
	await get_tree().process_frame
	var badge: Badge = hint.find_children("*", "Badge", true, false)[0] as Badge
	assert_true(badge.visible)
	assert_eq(badge.text, "3")
	watch_signals(hint)
	_click(view, hint.get_global_rect().get_center())
	_activate(view, hint)
	assert_signal_emit_count(hint, "activated", 2)
	assert_signal_emitted_with_parameters(hint, "activated", [&"hint"])
	hint.set_amounts(0, 99999)
	assert_false(badge.visible)
	assert_eq(hint.accessibility_description, "99999")
	assert_eq(hint.price, 99999)
	hint.disabled = true
	_click(view, hint.get_global_rect().get_center())
	_activate(view, hint)
	assert_signal_emit_count(hint, "activated", 2)


func test_hint_loading_reconfigure_restores_current_kind_and_availability() -> void:
	var view: SubViewport = _viewport()
	var hint: HintButton = _hint(view)
	hint.loading = true
	watch_signals(hint)
	assert_eq(hint.configure(&"reveal", 0, 99999), OK)
	assert_true(hint.loading)
	assert_true(hint.disabled)
	assert_ne(hint.icon, HintButton.GLYPHS[&"reveal"])
	hint.disabled = false
	_activate(view, hint)
	assert_true(hint.disabled)
	assert_signal_emit_count(hint, "activated", 0)
	hint.loading = false
	assert_false(hint.disabled)
	assert_same(hint.icon, HintButton.GLYPHS[&"reveal"])
	_activate(view, hint)
	assert_signal_emitted_with_parameters(hint, "activated", [&"reveal"])
	hint.disabled = true
	hint.loading = true
	hint.loading = false
	assert_true(hint.disabled)


func test_hint_count_pop_interruption_reduction_copy_theme_reentry_footer() -> void:
	var view: SubViewport = _viewport()
	var hint: HintButton = _hint(view)
	hint.theme = HC
	Tokens.reduced_motion = false
	hint.set_amounts(5, 9)
	_step(Tokens.dur(Tokens.Motion.FAST) / 2)
	var badge: Badge = hint.find_children("*", "Badge", true, false)[0] as Badge
	assert_gt(badge.scale.x, 1.0)
	assert_eq(hint.set_amounts(-1, 3), ERR_INVALID_PARAMETER)
	assert_eq(hint.count, 5)
	hint.set_amounts(0, 99999)
	assert_eq(badge.scale, Vector2.ONE)
	hint.set_amounts(3, 99999)
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_eq(badge.scale, Vector2.ONE)
	hint.highlighted = true
	assert_eq(hint.scale, Vector2.ONE)
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	assert_eq(hint.accessibility_name, hint.tr("ui.hint.hint"))
	view.remove_child(hint)
	view.add_child(hint)
	watch_signals(hint)
	_activate(view, hint)
	assert_signal_emit_count(hint, "activated", 1)
	assert_gte(hint.size.y, float(Tokens.Touch.MIN_TARGET))
	assert_true(hint.get_global_rect().encloses(badge.get_global_rect()))


func test_powerups_gallery_inventory_and_pseudo_hc_fit() -> void:
	var gallery: GalleryShell = load("res://ui/gallery/gallery.tscn").instantiate()
	add_child_autofree(gallery)
	assert_eq(gallery.configure(&"COMPACT", &"PSEUDO", true, 130, true, true, &"Powerups"), OK)
	for frame: int in 5:
		await get_tree().process_frame
	var screen: ScreenScaffold = gallery.preview_screen()
	assert_eq(screen.find_children("*", "BonusMeter", true, false).size(), 5)
	assert_eq(screen.find_children("*", "HintButton", true, false).size(), 11)
	var scroll: ScrollContainer = (
		screen.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	)
	assert_true(scroll.get_v_scroll_bar().visible)
	for control: Control in screen.find_children("*", "Control", true, false):
		if control is BonusMeter or control is HintButton:
			assert_lte(control.size.x, screen.body.size.x)
	gallery.free()


func test_full_bonus_already_native_press_and_highlight_cancel_competing_motion() -> void:
	var view: SubViewport = _viewport()
	var meter: BonusMeter = _meter(view, 10)
	await get_tree().process_frame
	Tokens.reduced_motion = false
	meter.pulse_already()
	_step(Tokens.dur(Tokens.Motion.FAST) / 2)
	_click(view, meter.get_global_rect().get_center())
	assert_ne(meter.state, &"already")
	_step(Tokens.dur(Tokens.Motion.BASE))
	assert_eq(meter.scale, Vector2.ONE)
	meter.pulse_already()
	meter.highlighted = true
	assert_ne(meter.state, &"already")
	Tokens.reduced_motion = true
	await get_tree().process_frame
	meter.pulse_already()
	assert_eq(meter.state, &"already")
	assert_eq(meter.scale, Vector2.ONE)
	meter.set_count(5, false)
	assert_eq(meter.state, &"highlighted")


func test_already_scale_css_is_unitless() -> void:
	assert_true(CeramicThemeGenerator.css_text().contains("--Action-ALREADY_SCALE: 1.06;"))
