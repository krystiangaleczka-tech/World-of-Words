extends VBoxContainer
## Debug screen composition; provider access stays behind the injected service facade.

const BUTTON: PackedScene = preload("res://ui/components/TextButton.tscn")
var _port: RefCounted
var _last_error: Error = OK
var _status: Label
var _buttons: Array[TextButton] = []
var _handlers: Array[Callable] = []


func configure(port: RefCounted) -> void:
	_port = port


func _ready() -> void:
	add_theme_constant_override("separation", Tokens.Space.S)
	_status = Label.new()
	_status.name = "Wallet"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.theme_type_variation = &"Caption"
	add_child(_status)
	for item: String in ["coins", "hint", "reveal"]:
		for remove: bool in [false, true]:
			_action(
				item + ("Remove" if remove else "Grant"),
				"debug.p2." + item + ("_remove" if remove else "_grant"),
				_modify.bind(item, remove)
			)
	_action("Entitlement", "debug.p2.entitlement", _entitlement)
	for outcome: String in ["fill", "no_fill"]:
		_action(outcome, "debug.p2." + outcome, _ad.bind(StringName(outcome)))
	for outcome: String in ["success", "cancel", "pending", "crash_before_finish"]:
		_action(outcome, "debug.p2." + outcome, _iap.bind(StringName(outcome)))
	_refresh(OK)
	if _port.diagnostics != null:
		var panel: VBoxContainer = load("res://features/debug/diagnostics.gd").new()
		panel.configure(_port.diagnostics)
		add_child(panel)


func _action(node_name: String, key: String, handler: Callable) -> void:
	var button: TextButton = BUTTON.instantiate()
	button.name = node_name
	button.text_key = key
	button.pressed.connect(handler)
	_buttons.append(button)
	_handlers.append(handler)
	add_child(button)


func _modify(item: String, remove: bool) -> void:
	_refresh(_port.modify(item, _port.coin_step() if item == "coins" else 1, remove))


func _entitlement() -> void:
	var state: Dictionary = _port.snapshot()
	_refresh(_port.set_remove_forced_ads(not state.get("remove_forced_ads", false)))


func _ad(outcome: StringName) -> void:
	_refresh(_port.ad_outcome(outcome))


func _iap(outcome: StringName) -> void:
	_refresh(_port.iap_outcome(outcome))


func _refresh(error: Error) -> void:
	_last_error = error
	var state: Dictionary = _port.snapshot()
	if state.is_empty():
		_status.text = tr("debug.p2.error")
		return
	var wallet: Dictionary = state.wallet
	_status.text = (
		"%s\n%s"
		% [
			tr("debug.p2.ok") if error == OK else tr("debug.p2.error"),
			(
				tr("debug.p2.summary")
				% [
					wallet.coins,
					wallet.items.hint,
					wallet.items.reveal,
					tr("debug.p2.yes") if state.remove_forced_ads else tr("debug.p2.no"),
					tr("debug.p2.yes") if state.retry else tr("debug.p2.no")
				]
			)
		]
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(_status):
		_refresh(_last_error)


func _exit_tree() -> void:
	for index: int in _buttons.size():
		if (
			is_instance_valid(_buttons[index])
			and _buttons[index].pressed.is_connected(_handlers[index])
		):
			_buttons[index].pressed.disconnect(_handlers[index])
