extends SceneTree
## Headless MainLoop adapter for the EditorScript generator.

const GENERATOR: GDScript = preload("res://ui/theme/generate_theme.gd")


func _initialize() -> void:
	var result: Error = GENERATOR.generate()
	if result != OK:
		printerr("Theme generation failed: %s" % error_string(result))
		quit(1)
		return
	print("Theme generation: six Ceramic themes and CSS mirror written")
	quit(0)
