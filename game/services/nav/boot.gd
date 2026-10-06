extends Node
## Boot scene stub: Nav explicitly initializes services; no loading or navigation yet.


func _ready() -> void:
	Nav.boot(Clock.new())
