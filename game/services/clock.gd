class_name Clock
extends RefCounted
## Injectable time source. Tests override these methods with fixed values.


## @api Unix seconds for calendar and persistence decisions.
func unix_time_seconds() -> int:
	return int(Time.get_unix_time_from_system())


## @api Monotonic milliseconds for elapsed durations only.
func monotonic_msec() -> int:
	return Time.get_ticks_msec()
