class_name ServiceStub
extends Node
## Shared injection contract for the closed autoload skeleton (T-0034).
## Domain APIs are introduced by their own contract tasks, starting at T-0035.

var _clock: Clock


## @api Inject the boot-owned time source; initialization performs no I/O.
func initialize(clock: Clock) -> void:
	assert(clock != null, "A service requires a Clock")
	_clock = clock


## @api Return the injected source, or null before explicit boot initialization.
func get_clock() -> Clock:
	return _clock
