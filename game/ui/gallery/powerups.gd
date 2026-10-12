extends ScreenScaffold

var _filling: BonusMeter
var _already: BonusMeter
var _counted: HintButton


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
	for state: String in ["normal", "filling", "full", "already", "highlighted"]:
		var caption: Label = CatalogSurface.label(&"Caption")
		caption.text = tr("gallery.powerups." + state)
		column.add_child(caption)
		var meter: BonusMeter = BonusMeter.new()
		meter.name = "bonus_" + state
		meter.configure(5 if state != "full" else 10, 10)
		meter.highlighted = state == "highlighted"
		column.add_child(meter)
		if state == "filling":
			_filling = meter
		elif state == "already":
			_already = meter
	for kind: StringName in [&"hint", &"reveal"]:
		for state: String in ["count", "price", "disabled", "loading", "highlighted"]:
			var caption: Label = CatalogSurface.label(&"Caption")
			caption.text = tr("gallery.powerups." + state)
			column.add_child(caption)
			var hint: HintButton = HintButton.new()
			hint.name = "hint_%s_%s" % [kind, state]
			hint.configure(kind, 3 if state == "count" else 0, 99999)
			hint.disabled = state == "disabled"
			hint.loading = state == "loading"
			hint.highlighted = state == "highlighted"
			column.add_child(hint)
			if kind == &"hint" and state == "count":
				_counted = hint
	var legacy: HintButton = HintButton.new()
	legacy.name = "legacy_hint"
	column.add_child(legacy)
	var replay: TextButton = TextButton.new()
	replay.text_key = "gallery.powerups.replay"
	column.add_child(replay)
	replay.pressed.connect(_replay)
	_replay()


func _replay() -> void:
	_filling.set_count(0, false)
	_filling.set_count(10)
	_already.pulse_already()
	_counted.set_amounts(1, 99999, false)
	_counted.set_amounts(3, 99999)
