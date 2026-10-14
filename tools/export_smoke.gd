extends SceneTree
## Run outside the exported pack; conditions stay active in release runtimes.

var _played: StringName = &""
var _transition_settled: bool = false


func _initialize() -> void:
	_smoke.call_deferred()


func _require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition


func _smoke() -> void:
	var boot: Node = load("res://services/nav/boot.tscn").instantiate()
	var nav: Node = root.get_node("Nav")
	nav.transition_finished.connect(_on_transition_finished)
	root.add_child(boot)
	if not _require(nav.current_screen() == nav.Screen.LEVEL, "Packaged boot must reach Level"):
		return
	await _settle_transition(nav)
	var audio: Node = root.get_node("Audio")
	audio.configure(root.get_node("Save"), _cue)
	if not _require(
		audio.play(&"word_valid") and _played == &"word_valid", "Packaged registry/WAV must load"
	):
		return
	if not await _routes(nav, boot):
		return
	print("OK: packaged boot/audio/navigation; debug_build=", OS.is_debug_build())
	nav.transition_finished.disconnect(_on_transition_finished)
	root.remove_child(boot)
	boot.free()
	await process_frame
	await process_frame
	quit()


func _routes(nav: Node, boot: Node) -> bool:
	if OS.is_debug_build():
		_transition_settled = false
		if not _require(nav.go_debug() == OK, "Debug route must mount"):
			return false
		await _settle_transition(nav)
		var screen: Control = nav.mounted_screen() as Control
		if not _require(
			screen.body.get_node("Title").text == "Narzędzia debugowania", "Debug copy"
		):
			return false
		_transition_settled = false
		if not _require(nav.go_to_level(1) == OK, "Return to packaged Level"):
			return false
		await _settle_transition(nav)
	else:
		if not _require(nav.go_debug() == ERR_UNAVAILABLE, "Release debug route must be disabled"):
			return false
		if not _require(
			not boot.has_node("PerformanceOverlay"), "Release must have no debug overlay"
		):
			return false
	return true


func _on_transition_finished() -> void:
	_transition_settled = true


func _settle_transition(nav: Node) -> void:
	# The signal may already have fired synchronously with reduced motion.
	if not _transition_settled:
		await nav.transition_finished


func _cue(cue: StringName, _gain: float, _pitch: float) -> void:
	_played = cue
