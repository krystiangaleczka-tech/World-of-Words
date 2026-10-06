extends Node
## Boot scene: inject one Clock, then run the Nav boot sequence with screens mounted here.

## Content root; tests point it at fixture content until the pipeline ships packs (T-0127).
@export var content_root: String = "res://content"


func _ready() -> void:
	Nav.boot(Clock.new())
	var error: Error = Nav.start(self, content_root)
	if error != OK:
		push_warning("Boot stopped before the first screen: %s" % error_string(error))
