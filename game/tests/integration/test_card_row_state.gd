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


func _body() -> Label:
	var label: Label = CatalogSurface.label()
	label.text = "99999"
	add_child_autofree(label)
	remove_child(label)
	return label


func _card(view: SubViewport) -> Card:
	var card: Card = Card.new()
	card.title_key = "gallery.content.title"
	card.action_key = "gallery.content.action"
	card.size.x = 800
	view.add_child(card)
	return card


func _row(view: SubViewport) -> ListRow:
	var row: ListRow = ListRow.new()
	row.title_key = "gallery.content.title"
	row.subtitle_key = "gallery.content.subtitle"
	row.size.x = 900
	view.add_child(row)
	return row


func test_card_native_passive_tappable_disabled_locked_and_footer() -> void:
	var view: SubViewport = _viewport()
	var card: Card = _card(view)
	await get_tree().process_frame
	watch_signals(card)
	var title: Label = card.find_children("*", "Label", true, false)[0] as Label
	_click(view, card.global_position + Vector2(100, 50))
	assert_signal_emit_count(card, "pressed", 0)
	assert_eq(card.focus_mode, Control.FOCUS_NONE)
	card.tappable = true
	_click(view, card.global_position + Vector2(100, 50))
	assert_signal_emit_count(card, "pressed", 1)
	assert_eq(card.focus_mode, Control.FOCUS_ALL)
	var footer: PrimaryButton = (
		card.find_children("*", "PrimaryButton", true, false)[0] as PrimaryButton
	)
	_click(view, footer.get_global_rect().get_center())
	assert_signal_emit_count(card, "action_requested", 1)
	assert_signal_emit_count(card, "pressed", 1)
	card.disabled = true
	_click(view, footer.get_global_rect().get_center())
	assert_signal_emit_count(card, "action_requested", 1)
	card.disabled = false
	card.locked = true
	await get_tree().process_frame
	_click(view, card.global_position + Vector2(100, 50))
	assert_signal_emit_count(card, "pressed", 1)
	assert_false(footer.visible)
	assert_true((card.find_children("*", "Badge", true, false)[0] as Badge).visible)
	assert_false(title.text.is_empty())


func test_card_body_atomic_ownership_and_reentry() -> void:
	var view: SubViewport = _viewport()
	var card: Card = _card(view)
	var first: Label = _body()
	var second: Label = _body()
	assert_eq(card.configure_body(first), OK)
	var parent: Node = first.get_parent()
	assert_eq(card.configure_body(null), ERR_INVALID_PARAMETER)
	assert_eq(card.configure_body(card), ERR_INVALID_PARAMETER)
	var interactive: Button = Button.new()
	add_child_autofree(interactive)
	remove_child(interactive)
	assert_eq(card.configure_body(interactive), ERR_INVALID_PARAMETER)
	assert_same(first.get_parent(), parent)
	assert_eq(card.configure_body(second), OK)
	assert_null(first.get_parent())
	view.remove_child(card)
	assert_null(second.get_parent())
	view.add_child(card)
	assert_same(second.get_parent(), parent)
	second.free()
	assert_eq(card.configure_body(first), OK)


func test_card_lock_media_highlight_copy_theme_reduced_motion() -> void:
	var view: SubViewport = _viewport()
	var card: Card = _card(view)
	card.theme = HC
	card.media = preload("res://assets/icons/map-pinned.svg")
	card.locked_label_key = "gallery.content.locked"
	card.locked = true
	card.highlighted = true
	card.configure_body(_body())
	await get_tree().process_frame
	var texture: TextureRect = card.find_children("*", "TextureRect", true, false)[0] as TextureRect
	assert_true((texture.material as ShaderMaterial).get_shader_parameter("desaturated"))
	assert_eq(
		(card.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Tokens.PaletteHC.SURFACE
	)
	assert_gt((card.get_theme_stylebox("normal") as StyleBoxFlat).border_width_left, 0)
	assert_eq(card.scale, Vector2.ONE)
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	assert_eq(card.accessibility_name, card.tr(card.title_key))
	card.locked = false
	assert_false((texture.material as ShaderMaterial).get_shader_parameter("desaturated"))


func test_row_native_whole_row_and_child_without_double_intent() -> void:
	var view: SubViewport = _viewport()
	var row: ListRow = _row(view)
	var toggle: CheckButton = CheckButton.new()
	toggle.custom_minimum_size = Vector2.ONE * Tokens.Touch.MIN_TARGET
	add_child_autofree(toggle)
	remove_child(toggle)
	row.configure_trailing(toggle, &"toggle")
	for frame: int in 3:
		await get_tree().process_frame
	watch_signals(row)
	watch_signals(toggle)
	_click(view, row.global_position + Vector2(100, 50))
	assert_signal_emit_count(row, "pressed", 1)
	_click(view, toggle.get_global_rect().get_center())
	assert_true(toggle.button_pressed)
	assert_signal_emit_count(toggle, "pressed", 1)
	assert_signal_emit_count(row, "pressed", 1)
	assert_gte(row.size.y, float(Tokens.Touch.MIN_TARGET))


func test_row_disabled_loading_child_restore_and_detach() -> void:
	var view: SubViewport = _viewport()
	var row: ListRow = _row(view)
	var toggle: CheckButton = CheckButton.new()
	toggle.custom_minimum_size = Vector2.ONE * Tokens.Touch.MIN_TARGET
	add_child_autofree(toggle)
	remove_child(toggle)
	row.configure_trailing(toggle, &"toggle")
	await get_tree().process_frame
	row.disabled = true
	_click(view, toggle.get_global_rect().get_center())
	assert_true(toggle.disabled)
	assert_false(toggle.button_pressed)
	row.disabled = false
	_click(view, toggle.get_global_rect().get_center())
	assert_false(toggle.disabled)
	assert_true(toggle.button_pressed)
	row.loading = true
	assert_true(toggle.disabled)
	row.configure_trailing(null, &"none")
	assert_false(toggle.disabled)
	assert_null(toggle.get_parent())
	row.loading = false
	toggle.disabled = true
	row.configure_trailing(toggle, &"toggle")
	row.loading = true
	row.loading = false
	assert_true(toggle.disabled)


func test_row_variants_atomic_ownership_slider_and_reentry() -> void:
	var view: SubViewport = _viewport()
	var row: ListRow = _row(view)
	var slider: HSlider = HSlider.new()
	add_child_autofree(slider)
	remove_child(slider)
	slider.custom_minimum_size = Vector2(Tokens.Touch.MIN_TARGET * 2, Tokens.Touch.MIN_TARGET)
	assert_eq(row.configure_trailing(slider, &"slider"), OK)
	var parent: Node = slider.get_parent()
	assert_eq(row.configure_trailing(slider, &"toggle"), ERR_INVALID_PARAMETER)
	assert_eq(row.configure_trailing(null, &"invalid"), ERR_INVALID_PARAMETER)
	assert_same(slider.get_parent(), parent)
	row.loading = true
	assert_false(slider.editable)
	row.loading = false
	assert_true(slider.editable)
	view.remove_child(row)
	assert_null(slider.get_parent())
	view.add_child(row)
	assert_same(slider.get_parent(), parent)
	for kind: StringName in [&"none", &"chevron", &"value"]:
		assert_eq(row.configure_trailing(null, kind), OK)
		assert_eq(row.trailing_kind, kind)
	assert_null(slider.get_parent())
	row.trailing_value = "99999"
	await get_tree().process_frame
	var numeric: Label = row.find_children("*", "Label", true, false)[2] as Label
	assert_eq(numeric.get_line_count(), 1)
	row.theme = HC
	TranslationServer.set_locale("en")
	assert_eq(row.accessibility_description, row.tr(row.subtitle_key))
	assert_eq(
		(row.get_theme_stylebox("normal") as StyleBoxFlat).border_color, Tokens.PaletteHC.STROKE
	)


func test_state_panel_kinds_atomic_config_native_optional_action_and_reentry() -> void:
	var view: SubViewport = _viewport()
	var panel: StatePanel = StatePanel.new()
	panel.size.x = 800
	view.add_child(panel)
	watch_signals(panel)
	for kind: StringName in StatePanel.GLYPHS:
		assert_eq(
			panel.configure(
				kind,
				"gallery.content." + str(kind),
				"gallery.content.subtitle",
				"gallery.content.action"
			),
			OK
		)
		var icon: TextureRect = (
			panel.find_children("*", "TextureRect", true, false)[0] as TextureRect
		)
		assert_same(icon.texture, StatePanel.GLYPHS[kind])
	assert_eq(
		panel.configure(&"broken", "gallery.content.title", "gallery.content.subtitle"),
		ERR_INVALID_PARAMETER
	)
	assert_eq(panel.configure(&"empty", "", "gallery.content.subtitle"), ERR_INVALID_PARAMETER)
	assert_eq(panel.kind, &"unavailable")
	for frame: int in 3:
		await get_tree().process_frame
	var action: PrimaryButton = (
		panel.find_children("*", "PrimaryButton", true, false)[0] as PrimaryButton
	)
	_click(view, action.get_global_rect().get_center())
	assert_signal_emit_count(panel, "action_requested", 1)
	assert_eq(panel.find_children("*", "PrimaryButton", true, false).size(), 1)
	panel.configure(&"empty", "gallery.content.empty", "gallery.content.subtitle")
	assert_false(action.visible)
	view.remove_child(panel)
	view.add_child(panel)
	panel.configure(
		&"offline", "gallery.content.offline", "gallery.content.subtitle", "gallery.content.action"
	)
	TranslationServer.set_locale("en")
	assert_eq(panel.accessibility_name, panel.tr(panel.title_key))
	assert_eq(panel.accessibility_description, panel.tr(panel.body_key))


func test_gallery_inventory_scroll_and_pseudo_hc_wrapping() -> void:
	var gallery: GalleryShell = load("res://ui/gallery/gallery.tscn").instantiate()
	add_child_autofree(gallery)
	assert_eq(gallery.configure(&"COMPACT", &"PSEUDO", true, 130, true, true, &"Content"), OK)
	for frame: int in 5:
		await get_tree().process_frame
	var screen: ScreenScaffold = gallery.preview_screen()
	assert_eq(screen.find_children("*", "Card", true, false).size(), 5)
	assert_eq(screen.find_children("*", "ListRow", true, false).size(), 5)
	assert_eq(screen.find_children("*", "StatePanel", true, false).size(), 4)
	var scroll: ScrollContainer = (
		screen.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	)
	assert_true(scroll.get_v_scroll_bar().visible)
	for control: Control in screen.find_children("*", "CatalogAction", true, false):
		assert_lte(control.size.x, screen.body.size.x)
		assert_gte(control.size.y, float(Tokens.Touch.MIN_TARGET))
	gallery.free()


func test_card_shortcut_respects_native_intent_gates() -> void:
	var view: SubViewport = _viewport()
	var card: Card = _card(view)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_K
	key.pressed = true
	var shortcut: Shortcut = Shortcut.new()
	shortcut.events = [key]
	card.shortcut = shortcut
	watch_signals(card)
	view.push_input(key)
	assert_signal_emit_count(card, "pressed", 0)
	card.tappable = true
	view.push_input(key)
	assert_signal_emit_count(card, "pressed", 1)
	card.locked = true
	view.push_input(key)
	assert_signal_emit_count(card, "pressed", 1)
	card.locked = false
	card.disabled = true
	view.push_input(key)
	assert_signal_emit_count(card, "pressed", 1)
	card.disabled = false
	card.loading = true
	view.push_input(key)
	assert_signal_emit_count(card, "pressed", 1)


func test_card_body_rejects_nested_unfocusable_text_input_atomically() -> void:
	var view: SubViewport = _viewport()
	var card: Card = _card(view)
	var first: Label = _body()
	card.configure_body(first)
	var parent: Node = first.get_parent()
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child_autofree(column)
	remove_child(column)
	var edit: TextEdit = TextEdit.new()
	edit.focus_mode = Control.FOCUS_NONE
	edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(edit)
	assert_eq(card.configure_body(column), ERR_INVALID_PARAMETER)
	assert_same(first.get_parent(), parent)
	assert_null(column.get_parent())


func test_inactive_card_does_not_consume_sibling_shortcut() -> void:
	var view: SubViewport = _viewport()
	var card: Card = _card(view)
	var sibling: Button = Button.new()
	sibling.position.y = 1000
	view.add_child(sibling)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_K
	key.pressed = true
	var shortcut: Shortcut = Shortcut.new()
	shortcut.events = [key]
	card.shortcut = shortcut
	sibling.shortcut = shortcut
	watch_signals(card)
	watch_signals(sibling)
	for hidden: bool in [true, false]:
		card.visible = not hidden
		view.push_input(key)
	assert_signal_emit_count(card, "pressed", 0)
	assert_signal_emit_count(sibling, "pressed", 2)
