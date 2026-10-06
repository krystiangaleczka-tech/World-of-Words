extends Node2D

const RADIUS: float = 82.0
const HIT_RADIUS_SQ: float = RADIUS * RADIUS * 1.35 * 1.35
const HAPTIC_MS: int = 12
const Measurement = preload("res://measurement.gd")

@onready var _line: Line2D = $SwipeLine
@onready var _word: Label = $Word
@onready var _metrics: Label = $Metrics
@onready var _timer: Timer = $MetricsTimer

var _positions: PackedVector2Array = PackedVector2Array([
	Vector2(540, 930), Vector2(790, 1075), Vector2(790, 1365),
	Vector2(540, 1510), Vector2(290, 1365), Vector2(290, 1075),
])
var _letters: PackedStringArray = PackedStringArray(["K", "O", "T", "A", "R", "S"])
var _selected: PackedInt32Array = PackedInt32Array()
var _dragging: bool = false
var _finger: int = -1
var _pointer: Vector2 = Vector2.ZERO
var _measurement: Measurement = Measurement.new()
var _run_sequence: int = 0
var _frozen_report: Dictionary = {}
var _unsaved: bool = false
var _original_cap: int = 0
var _started_at_local: String = ""

@onready var _start_60: Button = $Start60
@onready var _start_90: Button = $Start90
@onready var _stop: Button = $StopSave
@onready var _status: Label = $RunStatus


func _ready() -> void:
	_line.visible = false
	_original_cap = Engine.max_fps
	_timer.timeout.connect(_refresh_metrics)
	_start_60.pressed.connect(_begin.bind(60))
	_start_90.pressed.connect(_begin.bind(90))
	_stop.pressed.connect(_stop_and_save)
	RenderingServer.frame_post_draw.connect(_frame_drawn)
	_refresh_metrics()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _measurement.active:
		return
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
			_measurement.record_event(Time.get_ticks_usec())
			_visit(_hit(_pointer))


func _process(_delta: float) -> void:
	if not _measurement.active:
		return
	if _dragging:
		_line.set_point_position(_line.get_point_count() - 1, _pointer)
	_measurement.frame_updated(Time.get_ticks_usec())


func _frame_drawn() -> void:
	_measurement.frame_drawn(Time.get_ticks_usec())

func _draw() -> void:
	for index: int in range(_positions.size()):
		var fill: Color = Color(0.16, 0.55, 0.82) if _selected.has(index) else Color(0.18, 0.21, 0.28)
		draw_circle(_positions[index], RADIUS, fill)
		draw_string(ThemeDB.fallback_font, _positions[index] + Vector2(-60, 22), _letters[index],
			HORIZONTAL_ALIGNMENT_CENTER, 120.0, 58, Color(0.96, 0.97, 1.0))


func _start(finger: int, position: Vector2) -> void:
	var hit: int = _hit(position)
	if hit < 0:
		return
	_dragging = true
	_finger = finger
	_pointer = position
	_measurement.record_event(Time.get_ticks_usec())
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
	_measurement.finish_swipe()
	_dragging = false
	_finger = -1
	_line.visible = false
	_word.text = "Puść → " + _chain_word()
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
	if not _measurement.active:
		return
	var report: Dictionary = _measurement.snapshot(Time.get_ticks_usec())
	var timing: Dictionary = report["event_to_post_draw"]
	_metrics.text = (
		"Próba %d | cel %d FPS | średni FPS %.1f | swipy %d\n"
		+ "event→post_draw: avg %.2f ms | max %.2f ms | próbki %d"
	) % [
		_run_sequence, report["target_fps"], report["average_render_fps"],
		report["completed_swipes"], timing["average_ms"], timing["maximum_ms"], timing["samples"]
	]


func _begin(fps: int) -> void:
	if _measurement.active or _unsaved:
		return
	_run_sequence += 1
	var now_usec: int = Time.get_ticks_usec()
	var id: String = "s2_%d_%d_%d" % [OS.get_process_id(), now_usec, _run_sequence]
	_measurement.begin(id, fps, now_usec)
	_started_at_local = Time.get_datetime_string_from_system(false, true)
	_frozen_report = {}
	Engine.max_fps = fps
	_start_60.disabled = true
	_start_90.disabled = true
	_stop.disabled = false
	_status.text = "Próba %d rozpoczęta. Po próbie: ZAKOŃCZ I ZAPISZ." % _run_sequence
	_refresh_metrics()


func _stop_and_save() -> void:
	if _measurement.active:
		if _dragging:
			_measurement.abort_swipe()
		_dragging = false
		_finger = -1
		_line.visible = false
		_frozen_report = _measurement.stop(Time.get_ticks_usec())
		_frozen_report["device"] = OS.get_model_name()
		_frozen_report["os"] = OS.get_name()
		_frozen_report["engine"] = Engine.get_version_info()["string"]
		_frozen_report["exported_at_local"] = Time.get_datetime_string_from_system(false, true)
		_frozen_report["started_at_local"] = _started_at_local
		_frozen_report["display_refresh_hz"] = DisplayServer.screen_get_refresh_rate()
		_frozen_report["measurement_boundary"] = (
			"Input dispatch to line update / RenderingServer.frame_post_draw; "
			+ "not hardware touch-to-photon latency. FPS is measured over rendered-frame intervals."
		)
		_unsaved = true
		Engine.max_fps = _original_cap
		queue_redraw()
	if _frozen_report.is_empty():
		return
	var json: String = JSON.stringify(_frozen_report, "  ")
	var text: String = "S2 INDEPENDENT RUN\n" + json + "\n"
	var prefix: String = "user://" + str(_frozen_report["run_id"])
	if not _write_file(prefix + ".json", json) or not _write_file(prefix + ".txt", text):
		_unsaved = true
		_status.text = "Błąd zapisu. Użyj ZAKOŃCZ I ZAPISZ ponownie; próba jest zachowana."
		return
	_unsaved = false
	_start_60.disabled = false
	_start_90.disabled = false
	_stop.disabled = true
	_status.text = "Zapisano: %s.json / .txt" % str(_frozen_report["run_id"])
	_metrics.text += "\nZakończono. Każdy START zeruje wszystkie pomiary."
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(text)
	print(text)


func _write_file(path: String, content: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var result: Error = file.get_error()
	file.close()
	return result == OK


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _measurement.active:
		_stop_and_save()


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_frame_drawn):
		RenderingServer.frame_post_draw.disconnect(_frame_drawn)
	Engine.max_fps = _original_cap
