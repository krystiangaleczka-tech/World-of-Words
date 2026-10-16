extends GutTest

var _locale: String
var _pseudo: bool
var _motion: bool


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	_motion = Tokens.reduced_motion
	Tokens.reduced_motion = true
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	Tokens.reduced_motion = _motion


func _view(size: Vector2i = Vector2i(1080, 1920)) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = size
	add_child_autofree(view)
	return view


func _card(view: SubViewport) -> Card:
	var card: Card = Card.new()
	card.title_key = "gallery.content.title"
	card.action_key = "gallery.content.action"
	view.add_child(card)
	card.size = Vector2(Tokens.Layout.MAX_CONTENT_WIDTH, Tokens.Touch.MIN_TARGET)
	watch_signals(card)
	return card


func _activate(view: SubViewport, action: ActionButton) -> void:
	action.grab_focus()
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = pressed
		view.push_input(event)


func test_legacy_default_variants_and_atomic_invalid_input() -> void:
	var view: SubViewport = _view()
	var card: Card = _card(view)
	assert_is(card.action_button(), PrimaryButton)
	assert_eq(card.action_variant, &"primary")
	assert_eq(card.configure_action(&"secondary", "gallery.content.action", "12,99 zł", &"ad"), OK)
	var action: ActionButton = card.action_button()
	assert_is(action, SecondaryButton)
	assert_eq(action.badge, &"ad")
	assert_eq(action.value_text, "12,99 zł")
	for invalid: Array in [
		[&"other", "key", "", &""],
		[&"primary", "key", "", &"ad"],
		[&"none", "key", "", &""],
		[&"secondary", "", "value", &""],
		[&"secondary", "key", "", &"other"]
	]:
		assert_eq(
			card.configure_action(invalid[0], invalid[1], invalid[2], invalid[3]),
			ERR_INVALID_PARAMETER
		)
		assert_eq(card.action_button(), action)
	assert_eq(card.configure_action(&"primary", "gallery.content.action"), OK)
	assert_is(card.action_button(), PrimaryButton)
	assert_eq(card.action_button().value_text, "")


func test_value_caption_is_opaque_and_accessible_across_locale_changes() -> void:
	var view: SubViewport = _view()
	var card: Card = _card(view)
	card.configure_action(&"primary", "level.hud.hint", "CHF 12.30")
	var action: ActionButton = card.action_button()
	action.sublabel_key = "level.hud.shuffle"
	assert_eq(action.text, "CHF 12.30")
	assert_eq(action.text_key, "level.hud.hint")
	assert_eq(action.accessibility_name, action.tr("level.hud.hint"))
	assert_eq(action.accessibility_description, "CHF 12.30")
	TranslationServer.set_locale("en")
	TranslationServer.pseudolocalization_enabled = true
	await get_tree().process_frame
	assert_eq(action.text, "CHF 12.30")
	action.value_text = ""
	assert_eq(action.text, action.tr("level.hud.hint"))
	assert_eq(action.accessibility_description, action.tr("level.hud.shuffle"))


func test_native_activation_availability_loading_and_reentry() -> void:
	var view: SubViewport = _view()
	var card: Card = _card(view)
	card.configure_action(&"secondary", "gallery.content.action", "12,99 zł")
	await get_tree().process_frame
	_activate(view, card.action_button())
	assert_signal_emit_count(card, "action_requested", 1)
	card.disabled = true
	card.action_button().pressed.emit()
	assert_signal_emit_count(card, "action_requested", 1)
	card.loading = true
	assert_true(card.action_button().loading)
	card.loading = false
	assert_true(card.action_button().disabled)
	card.disabled = false
	card.loading = true
	card.loading = false
	assert_false(card.action_button().disabled)
	card.locked = true
	assert_false(card.action_button().visible)
	card.action_button().pressed.emit()
	assert_signal_emit_count(card, "action_requested", 1)
	card.locked = false
	view.remove_child(card)
	view.add_child(card)
	card.action_button().pressed.emit()
	assert_signal_emit_count(card, "action_requested", 2)


func test_pre_mount_configuration_focus_and_reentrant_replacement() -> void:
	var view: SubViewport = _view()
	var card: Card = Card.new()
	assert_eq(card.configure_action(&"secondary", "gallery.content.action", "value"), OK)
	view.add_child(card)
	card.size = Vector2(Tokens.Layout.MAX_CONTENT_WIDTH, Tokens.Touch.MIN_TARGET)
	watch_signals(card)
	await get_tree().process_frame
	var old: ActionButton = card.action_button()
	old.grab_focus()
	assert_eq(card.configure_action(&"primary", "gallery.content.action"), OK)
	assert_true(card.action_button().has_focus())
	old.pressed.emit()
	assert_signal_emit_count(card, "action_requested", 0)
	card.action_requested.connect(
		func() -> void: card.configure_action(&"none", ""), CONNECT_ONE_SHOT
	)
	card.action_button().pressed.emit()
	assert_signal_emit_count(card, "action_requested", 1)
	assert_false(card.action_button().visible)
	assert_false(card.action_button().has_focus())


func test_native_layout_matrix_keeps_price_and_footers_inside_card() -> void:
	for size: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				TranslationServer.pseudolocalization_enabled = pseudo
				var view: SubViewport = _view(size)
				var column: VBoxContainer = VBoxContainer.new()
				view.add_child(column)
				column.size = Vector2(
					minf(size.x - Tokens.Space.XL * 2, Tokens.Layout.MAX_CONTENT_WIDTH), size.y
				)
				column.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				for variant: StringName in [&"primary", &"secondary"]:
					var card: Card = Card.new()
					card.title_key = "gallery.content.title"
					card.configure_action(
						variant,
						"gallery.content.action",
						"CHF 12345.90",
						&"ad" if variant == &"secondary" else &""
					)
					column.add_child(card)
				await get_tree().process_frame
				await get_tree().process_frame
				for card: Card in column.get_children():
					var rect: Rect2 = card.action_button().get_global_rect()
					assert_true(card.get_global_rect().grow(1).encloses(rect))
					assert_gte(rect.size.y, Tokens.Touch.MIN_TARGET)
					assert_eq(card.action_button().text, "CHF 12345.90")


func test_none_retains_footer_class_and_rejects_hidden_pressed_intent() -> void:
	var card: Card = _card(_view())
	var primary: ActionButton = card.action_button()
	assert_eq(card.configure_action(&"none", ""), OK)
	assert_eq(card.action_button(), primary)
	primary.pressed.emit()
	assert_signal_emit_count(card, "action_requested", 0)
	assert_eq(card.configure_action(&"primary", "gallery.content.action"), OK)
	assert_eq(card.action_button(), primary)
	card.configure_action(&"secondary", "gallery.content.action")
	var secondary: ActionButton = card.action_button()
	card.configure_action(&"none", "")
	assert_eq(card.action_button(), secondary)
	secondary.pressed.emit()
	assert_signal_emit_count(card, "action_requested", 0)
	card.configure_action(&"secondary", "gallery.content.action")
	assert_eq(card.action_button(), secondary)


func test_locale_refresh_cannot_expose_locked_footer() -> void:
	var card: Card = _card(_view())
	card.configure_action(&"secondary", "gallery.content.action", "CHF 12.30", &"ad")
	card.locked = true
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	assert_false(card.action_button().visible)
	assert_true(card.action_button().disabled)
	card.locked = false
	assert_true(card.action_button().visible)
