extends Node
## Boot scene: inject one Clock, then run the Nav boot sequence with screens mounted here.

## Content root; tests point it at fixture content until the pipeline ships packs (T-0127).
@export var content_root: String = "res://content"


func _ready() -> void:
	Nav.boot(Clock.new())
	var error: Error = Nav.start(self, content_root)
	if error != OK:
		push_warning("Boot stopped before the first screen: %s" % error_string(error))


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_F3:
		if Nav.go_debug() == OK:
			get_viewport().set_input_as_handled()
