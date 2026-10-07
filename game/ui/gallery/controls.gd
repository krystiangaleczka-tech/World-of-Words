extends ScreenScaffold
## P1 actions, enabled and disabled. Labels follow the current PL/EN locale.


func _ready() -> void:
	super._ready()
	for is_disabled: bool in [false, true]:
		var shuffle: IconButton = IconButton.new()
		shuffle.text_key = "level.hud.shuffle"
		shuffle.disabled = is_disabled
		body.add_child(shuffle)
		var hint: HintButton = HintButton.new()
		hint.disabled = is_disabled
		body.add_child(hint)
