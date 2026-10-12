extends ScreenScaffold
## Final icon sizes/states and passive Badge catalogue.


func _ready() -> void:
	super._ready()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", Tokens.Space.S)
	scroll.add_child(column)
	for preset: StringName in [&"S", &"M"]:
		for state: String in ["normal", "pressed", "disabled", "highlighted"]:
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", Tokens.Space.S)
			column.add_child(row)
			var button: IconButton = IconButton.new()
			button.name = "icon_%s_%s" % [preset, state]
			button.configure_icon(
				preload("res://assets/icons/shuffle.svg"), "level.hud.shuffle", preset
			)
			button.disabled = state == "disabled"
			button.highlighted = state == "highlighted"
			row.add_child(button)
			if state == "pressed":
				button.toggle_mode = true
				button.set_pressed_no_signal(true)
			var label: Label = Label.new()
			label.text = str(preset) + " · " + tr("gallery.actions." + state)
			label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			label.theme_type_variation = &"Caption"
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
	var caption: Label = Label.new()
	caption.text = tr("gallery.icons.badges")
	caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	caption.theme_type_variation = &"Caption"
	column.add_child(caption)
	for variant: StringName in [&"info", &"lock", &"new"]:
		for count: String in ["0", "99999"] if variant == &"info" else [""]:
			var badge: Badge = Badge.new()
			badge.name = "badge_%s_%s" % [variant, count]
			badge.configure(count, variant)
			badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			column.add_child(badge)
