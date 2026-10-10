extends RefCounted
## All accepted events, bounded storage; timestamps are injected by the owner.

const CAPACITY: int = 512
const USEC_PER_SECOND: float = 1000000.0
const USEC_PER_MSEC: float = 1000.0

var _times: PackedInt64Array = PackedInt64Array()
var _head: int = 0
var _count: int = 0
var _drawn: int = 0
var _samples: int = 0
var _dropped: int = 0
var _sum: int = 0
var _maximum: int = 0
var _previous_frame: int = -1
var _intervals: int = 0
var _elapsed: int = 0


func _init() -> void:
	_times.resize(CAPACITY)


func record_input(timestamp: int) -> void:
	if _count == CAPACITY:
		_dropped += 1
		return
	_times[(_head + _count) % CAPACITY] = timestamp
	_count += 1


func mark_drawn() -> void:
	_drawn = _count


func frame_post_draw(timestamp: int) -> void:
	if _previous_frame >= 0 and timestamp > _previous_frame:
		_intervals += 1
		_elapsed += timestamp - _previous_frame
	_previous_frame = timestamp
	for index: int in _drawn:
		var duration: int = maxi(0, timestamp - _times[(_head + index) % CAPACITY])
		_sum += duration
		_maximum = maxi(_maximum, duration)
		_samples += 1
	_head = (_head + _drawn) % CAPACITY
	_count -= _drawn
	_drawn = 0


func reset() -> void:
	_head = 0
	_count = 0
	_drawn = 0
	_samples = 0
	_dropped = 0
	_sum = 0
	_maximum = 0
	_previous_frame = -1
	_intervals = 0
	_elapsed = 0


func snapshot() -> Dictionary:
	return {
		"fps": _intervals * USEC_PER_SECOND / _elapsed if _elapsed > 0 else -1.0,
		"mean_ms": float(_sum) / _samples / USEC_PER_MSEC if _samples > 0 else -1.0,
		"max_ms": _maximum / USEC_PER_MSEC if _samples > 0 else -1.0,
		"samples": _samples,
		"pending": _count,
		"dropped": _dropped,
	}
