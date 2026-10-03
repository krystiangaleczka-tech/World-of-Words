extends Node2D

const TILE_RADIUS: float = 82.0
const HIT_RADIUS_SQ: float = 118.0 * 118.0
const HAPTIC_MS: int = 12
const TILE_IDLE: Color = Color(0.18, 0.21, 0.28, 1.0)
const TILE_SELECTED: Color = Color(0.16, 0.55, 0.82, 1.0)
const TEXT_COLOR: Color = Color(0.96, 0.97, 1.0, 1.0)

@onready var _line: Line2D = $SwipeLine
@onready var _word_label: Label = $Word
@onready var _metrics_label: Label = $Metrics
@onready var _metrics_timer: Timer = $MetricsTimer

var _positions: PackedVector2Array = PackedVector2Array(
	[
		Vector2(540, 930),
		Vector2(790, 1075),
		Vector2(790, 1365),
		Vector2(540, 1510),
		Vector2(290, 1365),
		Vector2(290, 1075),
	]
)
var _letters: PackedStringArray = PackedStringArray(["K", "O", "T", "A", "R", "S"])
var _selected: PackedInt32Array = PackedInt32Array()
var _dragging: bool = false
var _active_finger: int = -1
var _pointer: Vector2 = Vector2.ZERO
var _last_event_usec: int = 0
var _last_measured_usec: int = -1
var _latency_ms: float = 0.0
var _latency_max_ms: float = 0.0
var _latency_sum_ms: float = 0.0
var _latency_samples: int = 0


func _ready() -> void:
	_line.visible = false
	_metrics_timer.timeout.connect(_refresh_metrics)
	_refresh_metrics()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if not _dragging:
				_try_start(touch.index, touch.position)
		elif _dragging and touch.index == _active_finger:
			_finish_chain()
		return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if _dragging and drag.index == _active_finger:
			_pointer = drag.position
			_last_event_usec = Time.get_ticks_usec()
			_visit_tile(_hit_test(_pointer))


func _process(_delta: float) -> void:
	if not _dragging:
		return

	# The per-frame path intentionally mutates existing data only: cached Vector2, Line2D point,
	# numeric counters. Strings and packed-array structure change only on touch/tile events.
	_line.set_point_position(_line.get_point_count() - 1, _pointer)
	if _last_event_usec != _last_measured_usec:
		_latency_ms = float(Time.get_ticks_usec() - _last_event_usec) / 1000.0
		_latency_max_ms = maxf(_latency_max_ms, _latency_ms)
		_latency_sum_ms += _latency_ms
		_latency_samples += 1
		_last_measured_usec = _last_event_usec


func _draw() -> void:
	for index: int in _positions.size():
		var fill: Color = TILE_SELECTED if _selected.has(index) else TILE_IDLE
		draw_circle(_positions[index], TILE_RADIUS, fill)
		draw_string(
			ThemeDB.fallback_font,
			_positions[index] + Vector2(-60, 22),
			_letters[index],
			HORIZONTAL_ALIGNMENT_CENTER,
			120.0,
			58,
			TEXT_COLOR
		)


func _try_start(finger: int, position: Vector2) -> void:
	var hit: int = _hit_test(position)
	if hit < 0:
		return

	_dragging = true
	_active_finger = finger
	_pointer = position
	_last_event_usec = Time.get_ticks_usec()
	_selected.clear()
	_selected.append(hit)
	_line.clear_points()
	_line.add_point(_positions[hit])
	_line.add_point(position)
	_line.visible = true
	Input.vibrate_handheld(HAPTIC_MS)
	_refresh_word()
	queue_redraw()


func _finish_chain() -> void:
	_dragging = false
	_active_finger = -1
	_line.visible = false
	_word_label.text = "Puść → " + _word_from_chain()
	queue_redraw()


func _visit_tile(hit: int) -> void:
	if hit < 0 or _selected.is_empty():
		return

	var count: int = _selected.size()
	if count >= 2 and hit == _selected[count - 2]:
		_selected.resize(count - 1)
		_line.remove_point(_line.get_point_count() - 2)
		_refresh_word()
		queue_redraw()
		return

	if _selected.has(hit):
		return

	_line.set_point_position(_line.get_point_count() - 1, _positions[hit])
	_line.add_point(_pointer)
	_selected.append(hit)
	Input.vibrate_handheld(HAPTIC_MS)
	_refresh_word()
	queue_redraw()


func _hit_test(position: Vector2) -> int:
	for index: int in _positions.size():
		if position.distance_squared_to(_positions[index]) <= HIT_RADIUS_SQ:
			return index
	return -1


func _word_from_chain() -> String:
	var word: String = ""
	for index: int in _selected:
		word += _letters[index]
	return word


func _refresh_word() -> void:
	_word_label.text = _word_from_chain()


func _refresh_metrics() -> void:
	var average: float = 0.0
	if _latency_samples > 0:
		average = _latency_sum_ms / float(_latency_samples)
	_metrics_label.text = (
		"event→frame estimate: %.2f ms | avg %.2f | max %.2f | samples %d\nFPS: %.0f"
		% [_latency_ms, average, _latency_max_ms, _latency_samples, Engine.get_frames_per_second()]
	)
