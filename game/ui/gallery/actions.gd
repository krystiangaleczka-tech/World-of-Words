extends ScreenScaffold
## Final catalog actions. Scroll exposes every labelled state without squeezing targets.


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
	for kind: String in ["primary", "secondary", "text"]:
		for state: String in ["normal", "pressed", "disabled", "loading", "highlighted"]:
			var caption: Label = Label.new()
			caption.text = tr("gallery.actions." + kind) + " · " + tr("gallery.actions." + state)
			caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			caption.theme_type_variation = &"Caption"
			column.add_child(caption)
			var button: ActionButton
			if kind == "primary":
				button = PrimaryButton.new()
				button.text_key = "gallery.actions.play"
				button.icon = preload("res://assets/icons/play.svg")
				button.sublabel_key = "gallery.actions.sublabel"
			elif kind == "secondary":
				button = SecondaryButton.new()
				(button as SecondaryButton).badge = &"ad"
				button.text_key = "gallery.actions.ad"
			else:
				button = TextButton.new()
				button.text_key = "gallery.actions.cancel"
			button.name = kind + "_" + state
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.disabled = state == "disabled"
			button.loading = state == "loading"
			button.highlighted = state == "highlighted"
			column.add_child(button)
			if state == "pressed":
				button.toggle_mode = true
				button.set_pressed_no_signal(true)
