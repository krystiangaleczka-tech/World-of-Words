class_name P2Navigation
extends RefCounted
## Nav-owned history, transitions and one passive Home toast. No gameplay owner activation.

var busy: bool = false
var animate: bool = true
var history: Array[Dictionary] = []
var _nav: Node
var _background: Callable
var _tween: Tween
var _messages: Array[Dictionary] = []
var _toast: Toast
var _layer: CanvasLayer


func configure(nav: Node, background: Callable, animated: bool) -> void:
	_nav = nav
	_background = background if background.is_valid() else AppBackground.new().request
	animate = animated


func reset() -> void:
	_park_toast()
	if _tween != null:
		_tween.kill()
		_tween = null
	busy = false
	history.clear()
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_toast = null


func close() -> void:
	reset()
	_messages.clear()
	_nav = null


func route(screen: int, slot: int, remember: bool = true, reveal_latest: bool = false) -> Error:
	if busy:
		return ERR_BUSY
	if not _nav.is_in_group(&"nav_back_owner"):
		return ERR_UNCONFIGURED
	busy = true
	var destination: int = slot
	if screen == _nav.Screen.LEVEL and not _nav.call("_valid_level", slot):
		destination = -1
	if screen == _nav.Screen.POSTCARD:
		var context: Dictionary = _nav.call("_postcard_context", slot)
		if (
			context.is_empty()
			or not _nav.home_unlocked()
			or int(context.progress.current_slot) < int(context.location.first)
		):
			destination = -1
		else:
			destination = int(context.location.first)
	if destination < 0:
		busy = false
		return ERR_INVALID_PARAMETER
	slot = destination
	if _nav.current_screen() == screen and _nav.level_slot() == slot:
		busy = false
		return OK
	var error: Error = _nav.call("_prepare_leave")
	if error != OK:
		busy = false
		return error
	if remember and _nav.current_screen() != 0:
		history.append({"screen": _nav.current_screen(), "slot": _nav.level_slot()})
	_run_route(screen, slot, reveal_latest)
	return OK


func _run_route(screen: int, slot: int, reveal_latest: bool = false) -> void:
	_park_toast()
	var old: Control = _nav.mounted_screen() as Control
	if old != null and animate and not Tokens.reduced_motion:
		old.process_mode = Node.PROCESS_MODE_DISABLED
		_tween = _nav.create_tween().set_trans(Tokens.Ease.IN.x).set_ease(Tokens.Ease.IN.y)
		_tween.tween_property(old, "modulate:a", 0.0, Tokens.dur(Tokens.Motion.FAST))
		await _tween.finished
	_nav.call("_mount_p2", screen, slot, reveal_latest)
	var mounted: Control = _nav.mounted_screen() as Control
	if mounted != null and animate and not Tokens.reduced_motion:
		var mode: Node.ProcessMode = mounted.process_mode
		var rest: Vector2 = mounted.position
		mounted.process_mode = Node.PROCESS_MODE_DISABLED
		mounted.modulate.a = 0
		mounted.position.y += Tokens.Space.L
		_tween = _nav.create_tween().set_parallel(true).set_trans(Tokens.Ease.OUT.x).set_ease(
			Tokens.Ease.OUT.y
		)
		_tween.tween_property(mounted, "modulate:a", 1.0, Tokens.dur(Tokens.Motion.BASE))
		_tween.tween_property(mounted, "position", rest, Tokens.dur(Tokens.Motion.BASE))
		await _tween.finished
		mounted.process_mode = mode
	_tween = null
	busy = false
	_nav.emit_signal("transition_finished")
	_show_next()


# gdlint: disable=max-returns
func back() -> Error:
	if busy:
		return ERR_BUSY
	if not _nav.is_in_group(&"nav_back_owner"):
		return ERR_UNCONFIGURED
	for node: Node in _nav.get_tree().get_nodes_in_group(Sheet.GROUP):
		var sheet: Sheet = node as Sheet
		if sheet != null and sheet.get_viewport() == _nav.get_viewport() and sheet.handle_back():
			return OK
	var screen: int = _nav.current_screen()
	if screen == _nav.Screen.BOOT:
		return ERR_UNCONFIGURED
	if screen == _nav.Screen.LEVEL and _nav.home_unlocked():
		return _nav.go_home()
	if screen in [_nav.Screen.LEVEL, _nav.Screen.HOME]:
		busy = true
		var error: Error = _nav.call("_prepare_leave")
		if error == OK:
			if screen == _nav.Screen.LEVEL and _nav.home_unlocked():
				busy = false
				return _nav.go_home()
			error = _background.call()
		busy = false
		return error
	if history.is_empty():
		return (
			_nav.go_home() if _nav.home_unlocked() else _nav.go_to_level(_nav.call("_resume_slot"))
		)
	var previous: Dictionary = history.pop_back()
	var destination: int = previous.screen
	if screen == _nav.Screen.POSTCARD and destination == _nav.Screen.LEVEL:
		destination = _nav.Screen.HOME
	var error: Error = route(destination, previous.slot, false)
	if error != OK:
		history.append(previous)
	return error


func enqueue(key: String, variant: StringName, first_screen: bool = false) -> Error:
	if key.strip_edges().is_empty() or not Toast.GLYPHS.has(variant):
		return ERR_INVALID_PARAMETER
	var message: Dictionary = {
		"key": key.strip_edges(), "variant": variant, "first_screen": first_screen
	}
	if not _messages.has(message):
		if first_screen:
			_messages.push_front(message)
		else:
			_messages.append(message)
	_show_next()
	return OK


func _show_next() -> void:
	if busy or _messages.is_empty():
		return
	if (
		not is_instance_valid(_nav)
		or not _nav.is_inside_tree()
		or not _nav.is_in_group(&"nav_back_owner")
	):
		return
	if _nav.current_screen() != _nav.Screen.HOME:
		if not _messages.front().first_screen or _nav.current_screen() != _nav.Screen.LEVEL:
			return
	if not is_instance_valid(_toast):
		_layer = CanvasLayer.new()
		_nav.add_child(_layer)
		_toast = Toast.new()
		_layer.add_child(_toast)
		_toast.visibility_changed.connect(_toast_visibility)
	var owner: Control = _nav.mounted_screen() as Control
	var parent: Node = owner if owner != null else _layer
	if _toast.get_parent() != parent:
		_toast.reparent(parent, false)
	if _toast.visible:
		return
	var message: Dictionary = _messages.front()
	if _toast.show_message(message.key, message.variant) == OK:
		_messages.pop_front()


func _toast_visibility() -> void:
	if is_instance_valid(_toast) and not _toast.visible:
		call_deferred("_show_next")


func _park_toast() -> void:
	if not is_instance_valid(_toast):
		return
	_toast.hide_message()
	if is_instance_valid(_layer) and _toast.get_parent() != _layer:
		_toast.reparent(_layer, false)
