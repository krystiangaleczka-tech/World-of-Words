extends ServiceStub
## @api Global wallet owner. Durable grant/spend implementation follows in T-0233.

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")


## @api Inject owners without I/O. Contract stub remains unavailable until T-0233.
func configure(_save: SAVE_SCRIPT, _config: CONFIG_SCRIPT, _events: EVENTS_SCRIPT) -> void:
	pass


## @api Readiness requires loaded dependencies and an injected Clock in T-0233.
func is_ready() -> bool:
	return false


## @api Isolated coins/items/bonus_counter value; empty while unavailable.
func snapshot() -> Dictionary:
	return {}


## @api Isolated oldest-first bounded transaction history; empty while unavailable.
func journal() -> Array[Dictionary]:
	return []


## @api Validate the complete flat coins/hint/reveal request before any mutation.
func can_afford(_items: Dictionary) -> bool:
	return false


## @api Reasoned atomic grant; OK means durable success in T-0233.
func grant(_source: StringName, _items: Dictionary) -> Error:
	return ERR_UNCONFIGURED


## @api Reasoned atomic spend; true means durable success in T-0233.
func spend(_sink: StringName, _items: Dictionary) -> bool:
	return false
