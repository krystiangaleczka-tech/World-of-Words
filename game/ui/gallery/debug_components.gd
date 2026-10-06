extends ScreenScaffold
## Provisional gallery entry; reusable components contain no service calls.

const BUTTON: PackedScene = preload("res://ui/components/TextButton.tscn")


func _ready() -> void:
	super._ready()
	for state: String in ["normal", "disabled", "busy"]:
		var button: TextButton = BUTTON.instantiate() as TextButton
		button.name = state
		button.text_key = "debug.shell.home"
		body.add_child(button)
		button.disabled = state == "disabled"
		button.set_busy(state == "busy")
