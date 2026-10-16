extends ScreenScaffold

var _bodies: Array[Control] = []
var _trailing: Array[Control] = []


func _ready() -> void:
	super._ready()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", Tokens.Space.M)
	scroll.add_child(column)
	for state: String in ["normal", "pressed", "disabled", "locked", "highlighted"]:
		var card: Card = Card.new()
		card.name = "card_" + state
		card.title_key = "gallery.content.title"
		card.sublabel_key = "gallery.actions." + ("disabled" if state == "locked" else state)
		card.media = preload("res://assets/icons/map-pinned.svg")
		card.action_key = "gallery.content.action"
		if state == "normal":
			card.configure_action(&"primary", "gallery.content.action", "12,99 zł")
		elif state == "pressed":
			card.configure_action(&"secondary", "gallery.content.action", "CHF 123.90")
		elif state in ["disabled", "highlighted"]:
			card.configure_action(&"secondary", "gallery.content.action", "", &"ad")
		card.locked_label_key = "gallery.content.locked"
		card.tappable = state != "normal"
		card.disabled = state == "disabled"
		card.locked = state == "locked"
		card.highlighted = state == "highlighted"
		var label: Label = CatalogSurface.label()
		label.text = tr("gallery.content.subtitle")
		_bodies.append(label)
		card.configure_body(label)
		column.add_child(card)
		if state == "pressed":
			card.toggle_mode = true
			card.set_pressed_no_signal(true)
	for kind: StringName in [&"none", &"chevron", &"value", &"toggle", &"slider"]:
		var row: ListRow = ListRow.new()
		row.name = "row_" + str(kind)
		row.title_key = "gallery.content.title"
		row.subtitle_key = "gallery.content.subtitle"
		row.leading_icon = preload("res://assets/icons/settings.svg")
		row.trailing_value = "99999"
		var control: Control
		if kind == &"toggle":
			var check: CheckButton = CheckButton.new()
			check.custom_minimum_size = Vector2.ONE * Tokens.Touch.MIN_TARGET
			check.accessibility_name = "gallery.content.title"
			control = check
		elif kind == &"slider":
			var slider: HSlider = HSlider.new()
			slider.custom_minimum_size = Vector2(
				Tokens.Touch.MIN_TARGET * 2, Tokens.Touch.MIN_TARGET
			)
			slider.value = 50
			slider.accessibility_name = "gallery.content.title"
			control = slider
		if control != null:
			_trailing.append(control)
		row.configure_trailing(control, kind)
		column.add_child(row)
	for kind: StringName in StatePanel.GLYPHS:
		var panel: StatePanel = StatePanel.new()
		panel.name = "state_" + str(kind)
		panel.configure(
			kind,
			"gallery.content." + str(kind),
			"gallery.content.subtitle",
			"gallery.content.action" if kind != &"empty" else ""
		)
		column.add_child(panel)


func _exit_tree() -> void:
	for control: Control in _bodies + _trailing:
		if is_instance_valid(control):
			control.queue_free()
