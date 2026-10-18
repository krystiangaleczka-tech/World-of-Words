extends RefCounted
## Caller-owned, bounded observer; no queue draining, SDK calls or persistence.

signal changed
const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONFIG: Script = preload("res://services/config.gd")
const ANALYTICS: Script = preload("res://services/analytics.gd")
const EVENTS: Script = preload("res://services/events.gd")
const LOG_LIMIT: int = 32
const PARAM_LIMIT: int = 256
var _clock: Clock
var _config: CONFIG
var _analytics: ANALYTICS
var _events: EVENTS
var _entries: Array[Dictionary] = []


func configure(
	clock: Clock, save: SAVE, economy: ECONOMY, config: CONFIG, analytics: ANALYTICS, events: EVENTS
) -> Error:
	close()
	if (
		not OS.is_debug_build()
		or clock == null
		or not clock.has_method("adjust_days")
		or save.get_clock() != clock
		or economy.get_clock() != clock
		or analytics.get_clock() != clock
		or not economy.atomic_save_matches(save)
	):
		return ERR_UNCONFIGURED
	_clock = clock
	_config = config
	_analytics = analytics
	_events = events
	_analytics.event_accepted.connect(_on_event)
	_events.consent_changed.connect(_on_consent)
	return OK


func snapshot() -> Dictionary:
	if _clock == null:
		return {}
	return {
		"clock": _clock.snapshot(),
		"config": _config.active_values(),
		"buckets": _analytics.experiment_buckets(),
		"events": _entries.duplicate(true)
	}


func adjust_days(delta: int) -> Error:
	return _mutate(&"adjust_days", delta)


func change_zone(direction: int) -> Error:
	return _mutate(&"change_zone", direction)


func reset_clock() -> Error:
	if _clock == null:
		return ERR_UNCONFIGURED
	var error: Error = _clock.reset()
	changed.emit()
	return error


func _mutate(method: StringName, amount: int) -> Error:
	if _clock == null:
		return ERR_UNCONFIGURED
	var error: Error = _clock.call(method, amount)
	changed.emit()
	return error


func _on_event(name: StringName, params: Dictionary) -> void:
	_entries.append({"name": str(name), "params": JSON.stringify(params).left(PARAM_LIMIT)})
	while _entries.size() > LOG_LIMIT:
		_entries.pop_front()
	changed.emit()


func _on_consent(allowed: bool) -> void:
	if not allowed:
		_entries.clear()
		changed.emit()


func close() -> void:
	if is_instance_valid(_analytics) and _analytics.event_accepted.is_connected(_on_event):
		_analytics.event_accepted.disconnect(_on_event)
	if is_instance_valid(_events) and _events.consent_changed.is_connected(_on_consent):
		_events.consent_changed.disconnect(_on_consent)
	_entries.clear()
	_clock = null
	_analytics = null
	_events = null
	_config = null
