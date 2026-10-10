extends Node
## Boot scene: inject one Clock, then run the Nav boot sequence with screens mounted here.

## Content root; tests point it at fixture content until the pipeline ships packs (T-0127).
@export var content_root: String = "res://content"
var _locale_catalog: LocaleCatalog = LocaleCatalog.new()
var _haptics_listener: HapticsListener


func _ready() -> void:
	Nav.boot(Clock.new())
	var error: Error = _locale_catalog.register_all()
	if error != OK:
		push_warning("Boot locale registration failed: %s" % error_string(error))
		return
	Audio.configure(Save)
	var audio_error: Error = Audio.load_cues()
	if audio_error != OK:
		push_warning("Sound cues unavailable: %s" % error_string(audio_error))
	error = Nav.start(self, content_root)
	if error != OK:
		push_warning("Boot stopped before the first screen: %s" % error_string(error))
		return
	_haptics_listener = HapticsListener.new()
	_haptics_listener.configure(Events, Save, Platform)
	add_child(_haptics_listener)


func _exit_tree() -> void:
	_locale_catalog.unregister()


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_F3:
		if Nav.go_debug() == OK:
			get_viewport().set_input_as_handled()
