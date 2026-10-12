extends GutTest

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
	Tokens.reduced_motion = false


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	Tokens.reduced_motion = _motion


func _pill() -> CurrencyPill:
	var pill: CurrencyPill = load("res://ui/components/CurrencyPill.tscn").instantiate()
	add_child_autofree(pill)
	return pill


func _bar() -> CatalogProgressBar:
	var bar: CatalogProgressBar = load("res://ui/components/ProgressBar.tscn").instantiate()
	add_child_autofree(bar)
	return bar


func _new_tweens(previous: Array[Tween]) -> Array[Tween]:
	var result: Array[Tween] = []
	for tween: Tween in get_tree().get_processed_tweens():
		if tween not in previous:
			result.append(tween)
	return result


func test_currency_numeric_theme_glyphs_and_native_optional_action() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(800, 800)
	add_child_autofree(viewport)
	var pill: CurrencyPill = _pill()
	pill.reparent(viewport)
	pill.position = Vector2(40, 40)
	pill.value = 99999
	pill.theme = HC
	await get_tree().process_frame
	assert_eq(pill.text, "99999")
	assert_eq(pill.get_theme_font_size("font_size"), 52)
	assert_same(pill.get_theme_font("font"), pill.get_theme_font(&"NUMERIC", &"Type"))
	assert_eq(pill.get_theme_color("icon_normal_color"), Tokens.PaletteHC.COIN)
	assert_same(pill.icon, CurrencyPill.GLYPHS[&"coins"])
	assert_eq(pill.accessibility_name, "Monety")
	assert_gte(pill.custom_minimum_size.y, float(Tokens.Touch.MIN_TARGET))
	assert_true(pill.disabled)
	watch_signals(pill)
	for enabled: bool in [false, true]:
		pill.action_enabled = enabled
		for down: bool in [true, false]:
			var event: InputEventMouseButton = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = pill.position + pill.size / 2
			event.pressed = down
			viewport.push_input(event)
		assert_signal_emit_count(pill, "action_requested", 1 if enabled else 0)
	pill.kind = &"stars"
	assert_same(pill.icon, CurrencyPill.GLYPHS[&"stars"])
	pill.kind = &"invalid"
	assert_eq(pill.kind, &"stars")
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	pill.kind = &"stars"
	assert_eq(pill.accessibility_name, pill.tr(CurrencyPill.LABELS[&"stars"]))


func test_currency_interruption_large_exact_target_and_finite_pop() -> void:
	var pill: CurrencyPill = _pill()
	pill.set_value(-1)
	assert_eq(pill.value, 0)
	var before: Array[Tween] = get_tree().get_processed_tweens()
	pill.set_value(100)
	assert_true(pill.counting)
	var first: Tween = _new_tweens(before)[0]
	first.custom_step(Tokens.dur(Tokens.Motion.COUNT_UP_MAX) / 2)
	assert_gt(pill.displayed_value, 0)
	assert_lt(pill.displayed_value, 100)
	var shown: int = pill.displayed_value
	before = get_tree().get_processed_tweens()
	pill.set_value(9223372036854775807)
	assert_false(first.is_running())
	assert_eq(pill.displayed_value, shown)
	var count: Tween = _new_tweens(before)[0]
	count.custom_step(Tokens.dur(Tokens.Motion.COUNT_UP_MAX))
	count.custom_step(Tokens.dur(Tokens.Motion.FAST))
	assert_eq(pill.displayed_value, 9223372036854775807)
	assert_eq(pill.text, "9223372036854775807")
	assert_false(pill.counting)
	for tween: Tween in get_tree().get_processed_tweens():
		if tween not in before and tween != count:
			tween.custom_step(Tokens.dur(Tokens.Motion.FAST) * 3)
	assert_eq(pill.scale, Vector2.ONE)


func test_currency_live_reduction_exit_and_translation_ownership() -> void:
	var first: CurrencyPill = _pill()
	var second: CurrencyPill = _pill()
	first.free()
	second.set_value(90)
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_eq(second.displayed_value, 90)
	assert_false(second.counting)
	assert_eq(second.scale, Vector2.ONE)
	Tokens.reduced_motion = false
	second.set_value(120)
	remove_child(second)
	assert_eq(second.displayed_value, 120)
	add_child(second)
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_eq(second.accessibility_name, "Coins")
	assert_eq(second.text, "120")


func test_progress_atomic_clamp_tints_completion_and_copy() -> void:
	var bar: CatalogProgressBar = _bar()
	assert_eq(bar.set_value(-5, false), OK)
	assert_eq(bar.value, 0.0)
	assert_eq(bar.set_value(0.5, false), OK)
	assert_eq(bar.set_value(NAN), ERR_INVALID_PARAMETER)
	assert_eq(bar.set_value(INF), ERR_INVALID_PARAMETER)
	assert_eq(bar.value, 0.5)
	bar.tint = &"bonus"
	bar.theme = HC
	await get_tree().process_frame
	var track: ProgressBar = bar.find_child("Track", true, false) as ProgressBar
	assert_eq((track.get_theme_stylebox("fill") as StyleBoxFlat).bg_color, Tokens.PaletteHC.BONUS)
	assert_false((bar.find_child("Complete", true, false) as TextureRect).visible)
	assert_eq(bar.set_value(5, false), OK)
	assert_eq(bar.displayed_value, 1.0)
	assert_true((bar.find_child("Complete", true, false) as TextureRect).visible)
	assert_eq((bar.get_node("Label") as Label).text, "Ukończono")
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	bar.label_key = "gallery.currency.progress"
	assert_eq(bar.accessibility_name, bar.tr(CatalogProgressBar.COMPLETE_KEY))
	assert_eq((bar.get_node("Label") as Label).text, bar.tr(CatalogProgressBar.COMPLETE_KEY))


func test_progress_interrupted_fill_live_reduction_and_reentry() -> void:
	var bar: CatalogProgressBar = _bar()
	var before: Array[Tween] = get_tree().get_processed_tweens()
	bar.set_value(1)
	var first: Tween = _new_tweens(before)[0]
	first.custom_step(Tokens.dur(Tokens.Motion.BASE) / 2)
	assert_gt(bar.displayed_value, 0.0)
	assert_lt(bar.displayed_value, 1.0)
	assert_false((bar.find_child("Complete", true, false) as TextureRect).visible)
	bar.set_value(0.5)
	assert_false(first.is_running())
	Tokens.reduced_motion = true
	await get_tree().process_frame
	assert_eq(bar.displayed_value, 0.5)
	assert_false(bar.filling)
	Tokens.reduced_motion = false
	bar.set_value(1)
	remove_child(bar)
	assert_eq(bar.displayed_value, 1.0)
	add_child(bar)
	assert_true((bar.find_child("Complete", true, false) as TextureRect).visible)


func test_reduced_motion_before_values_has_no_animation() -> void:
	Tokens.reduced_motion = true
	var pill: CurrencyPill = _pill()
	pill.set_value(200)
	assert_eq(pill.displayed_value, 200)
	assert_false(pill.counting)
	var bar: CatalogProgressBar = _bar()
	bar.set_value(1)
	assert_eq(bar.displayed_value, 1.0)
	assert_false(bar.filling)


func test_loading_availability_passive_guard_and_reentry_input() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(800, 800)
	add_child_autofree(viewport)
	var pill: CurrencyPill = _pill()
	pill.reparent(viewport)
	pill.position = Vector2(40, 40)
	pill.action_enabled = true
	pill.loading = true
	pill.action_enabled = false
	pill.loading = false
	assert_true(pill.disabled)
	assert_eq(pill.focus_mode, Control.FOCUS_NONE)
	watch_signals(pill)
	pill.disabled = false
	for down: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = pill.position + pill.size / 2
		viewport.push_input(event)
	assert_signal_emit_count(pill, "pressed", 0)
	assert_signal_emit_count(pill, "action_requested", 0)
	pill.loading = true
	pill.action_enabled = true
	pill.loading = false
	assert_false(pill.disabled)
	assert_eq(pill.focus_mode, Control.FOCUS_ALL)
	viewport.remove_child(pill)
	viewport.add_child(pill)
	pill.grab_focus()
	await get_tree().process_frame
	for down: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = down
		viewport.push_input(event)
	assert_signal_emit_count(pill, "action_requested", 1)


func test_count_cadence_visible_pop_and_highlight_ring() -> void:
	var pill: CurrencyPill = _pill()
	var before: Array[Tween] = get_tree().get_processed_tweens()
	pill.set_value(1)
	var count: Tween = _new_tweens(before)[0]
	count.custom_step(Tokens.dur(Tokens.Motion.SLOW))
	assert_true(pill.counting)
	count.custom_step(Tokens.dur(Tokens.Motion.COUNT_UP_STEP + Tokens.Motion.FAST))
	assert_false(pill.counting)
	var pops: Array[Tween] = _new_tweens(before)
	var pop: Tween
	for tween: Tween in pops:
		if tween != count and tween.is_running():
			pop = tween
	assert_not_null(pop)
	pop.custom_step(Tokens.dur(Tokens.Motion.FAST) / 4)
	assert_gt(pill.scale.x, 1.0)
	pop.custom_step(Tokens.dur(Tokens.Motion.FAST) * 2)
	assert_eq(pill.scale, Vector2.ONE)
	Tokens.reduced_motion = true
	pill.highlighted = true
	assert_gt((pill.get_theme_stylebox("normal") as StyleBoxFlat).border_width_left, 0)
	assert_gt((pill.get_theme_stylebox("disabled") as StyleBoxFlat).border_width_left, 0)


func test_progress_normal_endpoint_optional_wrap_and_owned_copy() -> void:
	var first: CatalogProgressBar = _bar()
	var second: CatalogProgressBar = _bar()
	first.free()
	assert_false((second.get_node("Label") as Label).visible)
	second.label_key = "gallery.currency.progress"
	second.theme = HC
	second.size = Vector2(220, 200)
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	for frame: int in 4:
		await get_tree().process_frame
	var label: Label = second.get_node("Label") as Label
	assert_eq(label.text, second.tr(second.label_key))
	assert_gt(label.get_line_count(), 1)
	var before: Array[Tween] = get_tree().get_processed_tweens()
	second.set_value(1)
	var fill: Tween = _new_tweens(before)[0]
	fill.custom_step(Tokens.dur(Tokens.Motion.BASE + Tokens.Motion.FAST))
	assert_eq(second.displayed_value, 1.0)
	assert_false(second.filling)
	assert_eq(label.text, second.tr(CatalogProgressBar.COMPLETE_KEY))
	assert_true((second.find_child("Complete", true, false) as TextureRect).visible)


func test_currency_is_valid_topbar_slot() -> void:
	var header: TopBar = load("res://ui/components/TopBar.tscn").instantiate()
	var pill: CurrencyPill = CurrencyPill.new()
	assert_eq(header.configure([pill], "", []), OK)
	add_child_autofree(header)
	assert_same(pill.get_parent(), header)


func test_gallery_currency_inventory() -> void:
	var gallery: GalleryShell = load("res://ui/gallery/gallery.tscn").instantiate()
	add_child_autofree(gallery)
	assert_eq(gallery.configure(&"COMPACT", &"PSEUDO", true, 130, true, true, &"Currency"), OK)
	await get_tree().process_frame
	assert_eq(gallery.preview_screen().find_children("*", "CurrencyPill", true, false).size(), 5)
	assert_eq(
		gallery.preview_screen().find_children("*", "CatalogProgressBar", true, false).size(), 6
	)
	gallery.free()
