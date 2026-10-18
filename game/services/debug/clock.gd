extends Clock
## Transient developer calendar; elapsed time always comes from the original source.

const SECONDS_PER_DAY: int = 86400
const MAX_DAYS: int = 36525
const MAX_ZONE_MINUTES: int = 840
var _source: Clock
var _days: int = 0
var _zone: Variant = null


func _init(source: Clock = null) -> void:
	_source = source if source != null else Clock.new()


func unix_time_seconds() -> int:
	return _source.unix_time_seconds() + _days * SECONDS_PER_DAY


func monotonic_msec() -> int:
	return _source.monotonic_msec()


func monotonic_usec() -> int:
	return _source.monotonic_usec()


func time_zone_bias_minutes() -> int:
	return _source.time_zone_bias_minutes() if _zone == null else int(_zone)


func adjust_days(delta: int) -> Error:
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	if delta < -MAX_DAYS or delta > MAX_DAYS or absi(_days + delta) > MAX_DAYS:
		return ERR_INVALID_PARAMETER
	_days += delta
	return OK


func change_zone(direction: int) -> Error:
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	if direction not in [-1, 1]:
		return ERR_INVALID_PARAMETER
	var next: int = time_zone_bias_minutes() + direction * 60
	if absi(next) > MAX_ZONE_MINUTES:
		return ERR_INVALID_PARAMETER
	_zone = next
	return OK


func reset() -> Error:
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	_days = 0
	_zone = null
	return OK


func snapshot() -> Dictionary:
	return {"offset_days": _days, "zone_bias_minutes": time_zone_bias_minutes()}
