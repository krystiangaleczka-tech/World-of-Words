extends Node2D

const RADIUS: float = 82.0
const HIT_RADIUS_SQ: float = RADIUS * RADIUS * 1.35 * 1.35
const HAPTIC_MS: int = 12

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
var _finger: int = -1
var _pointer: Vector2 = Vector2.ZERO
var _event_usec: int = 0
var _measured_usec: int = -1
var _latency_ms: float = 0.0
var _max_ms: float = 0.0
var _sum_ms: float = 0.0
var _samples: int = 0
var _swipe_counter: int = 0
var _swipe_start_usec: int = 0
var _swipes_history: Array[Dictionary] = []

@onready var _line: Line2D = $SwipeLine
@onready var _word: Label = $Word
@onready var _metrics: Label = $Metrics
@onready var _timer: Timer = $MetricsTimer
@onready var _export_btn: Button = $ExportButton
@onready var _export_status: Label = $ExportStatus


func _ready() -> void:
	_line.visible = false
	_timer.timeout.connect(_refresh_metrics)
	_export_btn.pressed.connect(_on_export_pressed)

	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.18, 0.52, 0.88)
	style_normal.set_corner_radius_all(18)
	_export_btn.add_theme_stylebox_override("normal", style_normal)

	var style_pressed: StyleBoxFlat = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.12, 0.40, 0.70)
	style_pressed.set_corner_radius_all(18)
	_export_btn.add_theme_stylebox_override("pressed", style_pressed)

	_refresh_metrics()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and not _dragging:
			_start(touch.index, touch.position)
		elif not touch.pressed and _dragging and touch.index == _finger:
			_finish()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if _dragging and drag.index == _finger:
			_pointer = drag.position
			_event_usec = Time.get_ticks_usec()
			_visit(_hit(_pointer))


func _process(_delta: float) -> void:
	if not _dragging:
		return
	_line.set_point_position(_line.get_point_count() - 1, _pointer)
	if _event_usec != _measured_usec:
		_latency_ms = float(Time.get_ticks_usec() - _event_usec) / 1000.0
		_max_ms = maxf(_max_ms, _latency_ms)
		_sum_ms += _latency_ms
		_samples += 1
		_measured_usec = _event_usec


func _draw() -> void:
	for index: int in range(_positions.size()):
		var fill: Color = (
			Color(0.16, 0.55, 0.82) if _selected.has(index) else Color(0.18, 0.21, 0.28)
		)
		draw_circle(_positions[index], RADIUS, fill)
		draw_string(
			ThemeDB.fallback_font,
			_positions[index] + Vector2(-60, 22),
			_letters[index],
			HORIZONTAL_ALIGNMENT_CENTER,
			120.0,
			58,
			Color(0.96, 0.97, 1.0)
		)


func _start(finger: int, position: Vector2) -> void:
	var hit: int = _hit(position)
	if hit < 0:
		return
	_dragging = true
	_finger = finger
	_pointer = position
	_event_usec = Time.get_ticks_usec()
	_swipe_start_usec = _event_usec
	_selected.clear()
	_selected.append(hit)
	_line.clear_points()
	_line.add_point(_positions[hit])
	_line.add_point(position)
	_line.visible = true
	Input.vibrate_handheld(HAPTIC_MS)
	_refresh_word()
	queue_redraw()


func _finish() -> void:
	_dragging = false
	_finger = -1
	_line.visible = false
	var word_str: String = _chain_word()
	if not _selected.is_empty():
		_swipe_counter += 1
		var duration_ms: float = float(Time.get_ticks_usec() - _swipe_start_usec) / 1000.0
		_swipes_history.append(
			{
				"id": _swipe_counter,
				"word": word_str,
				"letters": _selected.size(),
				"duration_ms": duration_ms
			}
		)
	_word.text = "Puść → " + word_str
	queue_redraw()


func _visit(hit: int) -> void:
	if hit < 0 or _selected.is_empty():
		return
	var count: int = _selected.size()
	if count >= 2 and hit == _selected[count - 2]:
		_selected.resize(count - 1)
		_line.remove_point(_line.get_point_count() - 2)
	elif not _selected.has(hit):
		_line.set_point_position(_line.get_point_count() - 1, _positions[hit])
		_line.add_point(_pointer)
		_selected.append(hit)
		Input.vibrate_handheld(HAPTIC_MS)
	else:
		return
	_refresh_word()
	queue_redraw()


func _hit(position: Vector2) -> int:
	for index: int in range(_positions.size()):
		if position.distance_squared_to(_positions[index]) <= HIT_RADIUS_SQ:
			return index
	return -1


func _chain_word() -> String:
	var value: String = ""
	for index: int in _selected:
		value += _letters[index]
	return value


func _refresh_word() -> void:
	_word.text = _chain_word()


func _refresh_metrics() -> void:
	var average: float = _sum_ms / float(_samples) if _samples > 0 else 0.0
	_metrics.text = (
		"event→frame %.2f ms | avg %.2f | max %.2f | n %d\nFPS %.0f"
		% [_latency_ms, average, _max_ms, _samples, Engine.get_frames_per_second()]
	)


func _on_export_pressed() -> void:
	var average: float = _sum_ms / float(_samples) if _samples > 0 else 0.0
	var now_str: String = Time.get_datetime_string_from_system(false, true)
	var device_name: String = OS.get_model_name()
	if device_name.is_empty():
		device_name = OS.get_name()

	var report: String = ""
	report += "========================================\n"
	report += "S2 SWIPE SPIKE — TEST LOG\n"
	report += "========================================\n"
	report += "Data i czas: %s\n" % now_str
	report += "Urządzenie: %s (%s)\n" % [device_name, OS.get_name()]
	report += "Silnik: Godot %s\n" % Engine.get_version_info()["string"]
	report += "\nPODSUMOWANIE METRYK:\n"
	report += "- Liczba przeciągnięć (swipes): %d\n" % _swipe_counter
	report += "- Liczba próbek opóźnienia: %d\n" % _samples
	report += "- Średnie opóźnienie event→frame: %.2f ms\n" % average
	report += "- Maksymalne opóźnienie: %.2f ms\n" % _max_ms
	report += "- Ostatnie opóźnienie: %.2f ms\n" % _latency_ms
	report += "- Bieżący FPS: %.1f\n" % Engine.get_frames_per_second()
	report += "\nHISTORIA PRZECIĄGNIĘĆ (%d):\n" % _swipes_history.size()
	for item: Dictionary in _swipes_history:
		report += (
			'  #%d: "%s" (%d liter, %.1f ms)\n'
			% [item["id"], item["word"], item["letters"], item["duration_ms"]]
		)
	report += "========================================\n"

	print(report)
	DisplayServer.clipboard_set(report)

	var file: FileAccess = FileAccess.open("user://swipe_test_log.txt", FileAccess.WRITE)
	if is_instance_valid(file):
		file.store_string(report)
		file.close()

	_export_status.text = (
		"✓ Zapisano user://swipe_test_log.txt\noraz skopiowano do schowka! (swipes: %d)"
		% _swipe_counter
	)
