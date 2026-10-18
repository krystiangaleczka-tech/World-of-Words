extends VBoxContainer
## Translated chrome around verbatim canonical diagnostic identifiers.

const BUTTON: PackedScene = preload("res://ui/components/TextButton.tscn")
var _monitor: RefCounted
var _state: Label
var _buttons: Array[TextButton] = []
var _handlers: Array[Callable] = []


func configure(monitor: RefCounted) -> void:
	_monitor = monitor


func _ready() -> void:
	name = "Diagnostics"
	add_theme_constant_override("separation", Tokens.Space.S)
	for direction: int in [-1, 1]:
		_action(
			"DayMinus" if direction < 0 else "DayPlus",
			"debug.time.day_minus" if direction < 0 else "debug.time.day_plus",
			_monitor.adjust_days.bind(direction)
		)
		_action(
			"ZoneMinus" if direction < 0 else "ZonePlus",
			"debug.time.zone_minus" if direction < 0 else "debug.time.zone_plus",
			_monitor.change_zone.bind(direction)
		)
	_action("ResetClock", "debug.time.reset", _monitor.reset_clock)
	_action("Refresh", "debug.time.refresh", _refresh)
	_state = Label.new()
	_state.name = "RuntimeState"
	_state.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state.theme_type_variation = &"Caption"
	add_child(_state)
	_monitor.changed.connect(_refresh)
	_refresh()


func _action(node_name: String, key: String, handler: Callable) -> void:
	var button: TextButton = BUTTON.instantiate()
	button.name = node_name
	button.text_key = key
	button.pressed.connect(handler)
	_buttons.append(button)
	_handlers.append(handler)
	add_child(button)


func _refresh() -> void:
	var state: Dictionary = _monitor.snapshot()
	if state.is_empty():
		_state.text = tr("debug.p2.error")
		return
	var lines: PackedStringArray = [
		tr("debug.time.summary") % [state.clock.offset_days, state.clock.zone_bias_minutes],
		tr("debug.time.config"),
		JSON.stringify(state.config),
		tr("debug.time.buckets"),
		JSON.stringify(state.buckets),
		tr("debug.time.events")
	]
	for event: Dictionary in state.events:
		lines.append("%s %s" % [event.name, event.params])
	_state.text = "\n".join(lines)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(_state):
		_refresh()


func _exit_tree() -> void:
	if _monitor.changed.is_connected(_refresh):
		_monitor.changed.disconnect(_refresh)
	for index: int in _buttons.size():
		if (
			is_instance_valid(_buttons[index])
			and _buttons[index].pressed.is_connected(_handlers[index])
		):
			_buttons[index].pressed.disconnect(_handlers[index])
