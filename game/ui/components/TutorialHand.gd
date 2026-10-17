class_name TutorialHand
extends Control
## Passive caller-local path. Gameplay owns first touch/word and durable teaching state.

signal cycle_finished
const GLYPH: Texture2D = preload("res://assets/icons/hand.svg")
const OPACITY: float = 0.85  # DESIGN.md#tutorialhand-addition.
var points: PackedVector2Array:
	get:
		return _points.duplicate()
var state: StringName:
	get:
		return _state
var hand_position: Vector2:
	get:
		return _cursor
var _points: PackedVector2Array = PackedVector2Array()
var _loop: bool = true
var _configured: bool = false
var _dismissed: bool = false
var _state: StringName = &"hidden"
var _motion: Tween
var _cursor: Vector2 = Vector2.ZERO:
	set(value):
		_cursor = value
		queue_redraw()


## @api Invalid paths preserve all presentation/motion. Reconfiguration preserves dismissal.
func configure(path: PackedVector2Array, loop: bool = true) -> Error:
	if path.size() < 2:
		return ERR_INVALID_PARAMETER
	for index: int in path.size():
		if not path[index].is_finite() or (index > 0 and path[index] == path[index - 1]):
			return ERR_INVALID_PARAMETER
	_points = path.duplicate()
	_loop = loop
	_configured = true
	if is_node_ready() and not _dismissed:
		_start()
	return OK


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(false)
	visible = false
	if _configured and not _dismissed:
		_start()


## @api Caller explicitly begins a new demonstration; never driven by input interception.
func play() -> Error:
	if not _configured:
		return ERR_UNCONFIGURED
	_dismissed = false
	if is_node_ready() and is_inside_tree():
		_start()
	return OK


func _start() -> void:
	if not is_inside_tree() or _dismissed:
		return
	_stop_motion()
	visible = true
	modulate.a = 1
	_cursor = _points[0]
	_state = &"static" if Tokens.reduced_motion else &"playing"
	queue_redraw()
	if Tokens.reduced_motion:
		return
	set_process(true)
	_motion = create_tween().set_trans(Tokens.Ease.IN_OUT.x).set_ease(Tokens.Ease.IN_OUT.y)
	if _loop:
		_motion.set_loops()
	for index: int in range(1, _points.size()):
		_motion.tween_property(self, "_cursor", _points[index], Tokens.dur(Tokens.Motion.SLOW))
	_motion.tween_interval(Tokens.dur(Tokens.Motion.BASE))
	_motion.tween_callback(_finish_cycle)


func _finish_cycle() -> void:
	if _loop:
		_cursor = _points[0]
	else:
		_state = &"finished"
		set_process(false)
	cycle_finished.emit()


## @api First wheel touch suppresses autoplay; the caller still receives that same input.
func hide_for_touch() -> void:
	if _dismissed:
		return
	_dismissed = true
	_stop_motion()
	if not is_inside_tree() or Tokens.reduced_motion or not visible:
		cancel()
		return
	_state = &"hiding"
	set_process(true)
	_motion = create_tween().set_trans(Tokens.Ease.IN_OUT.x).set_ease(Tokens.Ease.IN_OUT.y)
	_motion.tween_property(self, "modulate:a", 0.0, Tokens.dur(Tokens.Motion.FAST))
	_motion.tween_callback(cancel)


func cancel() -> void:
	_stop_motion()
	_dismissed = true
	_state = &"hidden"
	visible = false
	modulate.a = 1


func _stop_motion() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	set_process(false)


func _process(_delta: float) -> void:
	if not Tokens.reduced_motion:
		return
	if _state == &"hiding":
		cancel()
	elif _state == &"playing":
		_stop_motion()
		_state = &"static"
		queue_redraw()


func _draw() -> void:
	if _state == &"hidden" or _points.size() < 2:
		return
	var ink: Color = get_theme_color(&"TEXT", &"Palette")
	ink.a *= OPACITY
	var shadow: Color = get_theme_color(&"MID_COLOR", &"Elevation")
	var offset: Vector2 = Vector2(0, Tokens.Elevation.MID_OFFSET_Y)
	if _state == &"static":
		for index: int in range(1, _points.size()):
			draw_line(
				_points[index - 1] + offset,
				_points[index] + offset,
				shadow,
				Tokens.Action.OUTLINE_WIDTH,
				true
			)
			draw_line(_points[index - 1], _points[index], ink, Tokens.Action.OUTLINE_WIDTH, true)
		var end: Vector2 = _points[-1]
		var direction: Vector2 = (_points[-2] - end).normalized() * Tokens.Space.M
		for angle: float in [-PI / 4, PI / 4]:
			var wing: Vector2 = end + direction.rotated(angle)
			draw_line(end + offset, wing + offset, shadow, Tokens.Action.OUTLINE_WIDTH, true)
			draw_line(end, wing, ink, Tokens.Action.OUTLINE_WIDTH, true)
	else:
		var rect: Rect2 = Rect2(_cursor - Vector2(Tokens.Space.M, 0), Vector2.ONE * Tokens.Space.XL)
		draw_texture_rect(GLYPH, Rect2(rect.position + offset, rect.size), false, shadow)
		draw_texture_rect(GLYPH, rect, false, ink)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _enter_tree() -> void:
	if is_node_ready() and _configured and not _dismissed:
		_start.call_deferred()


func _exit_tree() -> void:
	cancel()
