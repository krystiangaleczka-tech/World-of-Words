extends ScreenScaffold


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
	for state: String in ["off", "on", "pressed", "disabled"]:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.Space.M)
		column.add_child(row)
		var toggle: Toggle = Toggle.new()
		toggle.name = "toggle_" + state
		toggle.configure(state != "off", "gallery.settings.sound")
		toggle.disabled = state == "disabled"
		row.add_child(toggle)
		var label: Label = CatalogSurface.label()
		label.text = tr("gallery.settings.sound")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if state == "pressed":
			toggle.button_down.emit()
	for amount: float in [0.0, 0.5, 1.0]:
		for sound: bool in [true, false]:
			var label: Label = CatalogSurface.label()
			label.text = tr("gallery.settings.sound" if sound else "gallery.settings.music")
			column.add_child(label)
			var slider: CatalogSlider = CatalogSlider.new()
			slider.configure(
				amount, "gallery.settings.sound" if sound else "gallery.settings.music", sound
			)
			slider.editable = sound or amount != 0.5
			column.add_child(slider)
	for state: String in ["normal", "selected", "locked", "highlighted", "unbuilt"]:
		var tab: NavTab = NavTab.new()
		tab.name = "tab_" + state
		tab.configure(
			preload("res://assets/icons/map-pinned.svg"),
			"gallery.settings.tab",
			"gallery.settings.locked"
		)
		tab.selected = state == "selected"
		tab.locked = state == "locked"
		tab.highlighted = state == "highlighted"
		tab.implemented = state != "unbuilt"
		column.add_child(tab)
