class_name HapticsAndroid
extends HapticsAdapter
## Android built-in vibration patterns, selected only for physical Android devices.

const TICK_DURATION_MS: int = 20
const TICK_STRENGTH: float = 0.30
const SOFT_DURATION_MS: int = 35
const SOFT_STRENGTH: float = 0.45
const SUCCESS_DURATION_MS: int = 65
const SUCCESS_STRENGTH: float = 0.70
const ERROR_DURATION_MS: int = 100
const ERROR_STRENGTH: float = 1.00

var _vibrate: Callable


## @api Inject a vibration callable for deterministic tests; production uses Input.vibrate_handheld.
func _init(vibrate: Callable = Callable()) -> void:
	_vibrate = vibrate if vibrate.is_valid() else _vibrate_handheld


## @api Play one bounded named vibration; unknown patterns are inert.
func play(pattern: String) -> void:
	match pattern:
		"tick":
			_vibrate.call(TICK_DURATION_MS, TICK_STRENGTH)
		"soft":
			_vibrate.call(SOFT_DURATION_MS, SOFT_STRENGTH)
		"success":
			_vibrate.call(SUCCESS_DURATION_MS, SUCCESS_STRENGTH)
		"error":
			_vibrate.call(ERROR_DURATION_MS, ERROR_STRENGTH)


func _vibrate_handheld(duration_ms: int, strength: float) -> void:
	Input.vibrate_handheld(duration_ms, strength)
