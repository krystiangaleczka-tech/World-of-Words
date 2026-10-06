extends RefCounted
## Independent-run metrics. Timestamps are injected; no clock or I/O in this class.

const QUEUE_CAPACITY: int = 512
const HISTOGRAM_BINS: int = 251

var active: bool = false
var run_id: String = ""
var target_fps: int = 60
var swipes: int = 0
var aborted_swipes: int = 0
var dropped_events: int = 0
var _started_usec: int = 0
var _stopped_usec: int = -1
var _events: PackedInt64Array = PackedInt64Array()
var _draw_events: PackedInt64Array = PackedInt64Array()
var _pending: int = 0
var _awaiting_draw: int = 0
var _update_hist: PackedInt32Array = PackedInt32Array()
var _draw_hist: PackedInt32Array = PackedInt32Array()
var _frame_hist: PackedInt32Array = PackedInt32Array()
var _update_count: int = 0
var _update_sum: int = 0
var _update_max: int = 0
var _draw_count: int = 0
var _draw_sum: int = 0
var _draw_max: int = 0
var _over_budget: int = 0
var _frame_count: int = 0
var _frame_sum: int = 0
var _frame_max: int = 0
var _last_draw_usec: int = -1


func begin(id: String, fps: int, now_usec: int) -> void:
	active = true
	run_id = id
	target_fps = fps
	_started_usec = now_usec
	_stopped_usec = -1
	swipes = 0
	aborted_swipes = 0
	dropped_events = 0
	_pending = 0
	_awaiting_draw = 0
	_update_count = 0
	_update_sum = 0
	_update_max = 0
	_draw_count = 0
	_draw_sum = 0
	_draw_max = 0
	_over_budget = 0
	_frame_count = 0
	_frame_sum = 0
	_frame_max = 0
	_last_draw_usec = -1
	_events.resize(QUEUE_CAPACITY)
	_draw_events.resize(QUEUE_CAPACITY)
	_update_hist.resize(HISTOGRAM_BINS)
	_draw_hist.resize(HISTOGRAM_BINS)
	_frame_hist.resize(HISTOGRAM_BINS)
	_update_hist.fill(0)
	_draw_hist.fill(0)
	_frame_hist.fill(0)


func record_event(now_usec: int) -> void:
	if not active:
		return
	if _pending == QUEUE_CAPACITY:
		dropped_events += 1
		return
	_events[_pending] = now_usec
	_pending += 1


func frame_updated(now_usec: int) -> void:
	if not active:
		return
	# All events affecting this update are measured, not only the latest drag event.
	for index: int in range(_pending):
		var elapsed: int = maxi(0, now_usec - _events[index])
		_update_count += 1
		_update_sum += elapsed
		_update_max = maxi(_update_max, elapsed)
		_update_hist[mini(int(float(elapsed) / 1000.0), HISTOGRAM_BINS - 1)] += 1
		if _awaiting_draw < QUEUE_CAPACITY:
			_draw_events[_awaiting_draw] = _events[index]
			_awaiting_draw += 1
		else:
			dropped_events += 1
	_pending = 0


func frame_drawn(now_usec: int) -> void:
	if not active:
		return
	if _last_draw_usec >= 0:
		var interval: int = now_usec - _last_draw_usec
		if interval > 0:
			_frame_count += 1
			_frame_sum += interval
			_frame_max = maxi(_frame_max, interval)
			_frame_hist[mini(int(float(interval) / 1000.0), HISTOGRAM_BINS - 1)] += 1
	_last_draw_usec = now_usec
	for index: int in range(_awaiting_draw):
		var elapsed: int = maxi(0, now_usec - _draw_events[index])
		_draw_count += 1
		_draw_sum += elapsed
		_draw_max = maxi(_draw_max, elapsed)
		_draw_hist[mini(int(float(elapsed) / 1000.0), HISTOGRAM_BINS - 1)] += 1
		if elapsed > 1000000.0 / float(target_fps):
			_over_budget += 1
	_awaiting_draw = 0


func finish_swipe() -> void:
	if active:
		swipes += 1


func abort_swipe() -> void:
	if active:
		aborted_swipes += 1


func stop(now_usec: int) -> Dictionary:
	active = false
	_stopped_usec = now_usec
	return snapshot(now_usec)


func snapshot(now_usec: int) -> Dictionary:
	var end_usec: int = _stopped_usec if _stopped_usec >= 0 else now_usec
	return {
		"run_id": run_id,
		"target_fps": target_fps,
		"duration_ms": float(end_usec - _started_usec) / 1000.0,
		"completed_swipes": swipes,
		"aborted_swipes": aborted_swipes,
		"dropped_events": dropped_events,
		"unmeasured_events": _pending + _awaiting_draw,
		"event_to_update": _stats(_update_count, _update_sum, _update_max, _update_hist),
		"event_to_post_draw": _stats(_draw_count, _draw_sum, _draw_max, _draw_hist),
		"events_over_target_frame_budget": _over_budget,
		"render_frame_intervals": _stats(_frame_count, _frame_sum, _frame_max, _frame_hist),
		"average_render_fps": (
			float(_frame_count) * 1000000.0 / float(_frame_sum) if _frame_sum > 0 else 0.0
		),
		"histogram_bin_ms": 1,
		"histogram_overflow_from_ms": HISTOGRAM_BINS - 1,
	}


func _stats(count: int, total: int, maximum: int, histogram: PackedInt32Array) -> Dictionary:
	return {
		"samples": count,
		"average_ms": float(total) / float(count) / 1000.0 if count > 0 else 0.0,
		"maximum_ms": float(maximum) / 1000.0,
		"p95_bin_ms": _percentile(histogram, count, 0.95),
		"overflow_samples": histogram[HISTOGRAM_BINS - 1],
	}


func _percentile(histogram: PackedInt32Array, count: int, quantile: float) -> int:
	if count == 0:
		return -1
	var rank: int = ceili(float(count) * quantile)
	var cumulative: int = 0
	for index: int in range(histogram.size()):
		cumulative += histogram[index]
		if cumulative >= rank:
			return index
	return -1
