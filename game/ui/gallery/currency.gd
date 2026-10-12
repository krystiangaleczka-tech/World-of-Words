extends ScreenScaffold

var _coins: CurrencyPill
var _progress: CatalogProgressBar


func _ready() -> void:
	super._ready()
	for kind: StringName in [&"coins", &"stars"]:
		for count: int in [0, 99999]:
			var pill: CurrencyPill = CurrencyPill.new()
			pill.kind = kind
			pill.value = count
			pill.action_enabled = count > 0
			body.add_child(pill)
			if kind == &"coins" and count == 0:
				_coins = pill
	var highlighted: CurrencyPill = CurrencyPill.new()
	highlighted.value = 99999
	highlighted.highlighted = true
	body.add_child(highlighted)
	for tint: StringName in [&"primary", &"bonus"]:
		for amount: float in [0.0, 0.5, 1.0]:
			var progress: CatalogProgressBar = CatalogProgressBar.new()
			progress.tint = tint
			progress.value = amount
			progress.label_key = "gallery.currency.progress"
			body.add_child(progress)
			if tint == &"bonus" and amount == 0:
				_progress = progress
	var replay: TextButton = TextButton.new()
	replay.text_key = "gallery.currency.replay"
	body.add_child(replay)
	replay.pressed.connect(_replay)


func _replay() -> void:
	_coins.set_value(0, false)
	_coins.set_value(99999)
	_progress.set_value(0, false)
	_progress.set_value(1)
