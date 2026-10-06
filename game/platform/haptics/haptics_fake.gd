class_name HapticsFake
extends HapticsAdapter
## @api SDK-free named haptics with an explicitly supplied preference and debug diagnostics.

const PATTERNS: PackedStringArray = ["tick", "soft", "success", "error"]

var calls: FakeCalls = FakeCalls.new()
var _haptics_enabled: bool = true
var _debug_logger: Callable = Callable()


## @api Services supply the preference; the optional debug logger takes one String.
func configure(haptics_enabled: bool, debug_logger: Callable = Callable()) -> void:
	_haptics_enabled = haptics_enabled
	_debug_logger = debug_logger


## @api Record supported, enabled patterns; disabled/unknown patterns are inert.
func play(pattern: String) -> void:
	if not _haptics_enabled or not PATTERNS.has(pattern):
		return
	calls.record("play", [pattern])
	if OS.is_debug_build():
		var message: String = "HapticsFake.play: " + pattern
		if _debug_logger.is_valid():
			_debug_logger.call(message)
		else:
			print(message)
