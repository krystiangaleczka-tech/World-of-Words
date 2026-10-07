extends ScreenScaffold
## Provisional catalog gallery: minimum and maximum supported tile counts.


func _ready() -> void:
	super._ready()
	for letters: PackedStringArray in [
		PackedStringArray(["K", "O", "T"]),
		PackedStringArray(["K", "O", "L", "O", "R", "O", "W", "O"])
	]:
		var wheel: LetterWheelView = LetterWheelView.new()
		wheel.custom_minimum_size = Vector2.ONE * Tokens.Layout.WHEEL_MIN
		body.add_child(wheel)
		wheel.set_letters(letters)
