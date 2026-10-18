extends Node
## Nonvisual feature controller. Settings owns mounted catalog controls.

const POLICY: Script = preload("res://services/settings_policy.gd")
var message: Label
var toast: Toast
var _root: Control
var _row: ListRow
var _save: Node
var _service: POLICY
var _bound: bool = false
var _dispatch: bool = false
var _command_error: Error = OK
var _error_revision: int = -1
var _attempt: int = 0
var _seen: String = ""


func bind(service: Node, save: Node) -> Error:
	if _dispatch:
		return ERR_BUSY
	if not is_instance_valid(save) or not service is POLICY or not service.owner_matches(save):
		return ERR_UNCONFIGURED
	if is_instance_valid(_service) and service != _service:
		if _service.snapshot().state == &"requested":
			return ERR_BUSY
	if service != _service:
		_attempt = 0
		_seen = ""
	_disconnect()
	_save = save
	_service = service
	_bound = true
	_command_error = OK
	_connect()
	refresh()
	return OK


func is_bound() -> bool:
	return _bound


func mount(root: Control, row: ListRow, save: Node) -> void:
	_root = root
	_row = row
	_save = save
	message = CatalogSurface.label(&"Caption")
	message.visible = false
	var column: Node = row.get_parent()
	column.add_child(message)
	column.move_child(message, row.get_index() + 1)
	toast = Toast.new()
	root.add_child(toast)
	root.add_child(self)


func _enter_tree() -> void:
	_connect()
	refresh.call_deferred()


func _connect() -> void:
	if is_inside_tree() and _bound:
		if (
			not is_instance_valid(_save)
			or not is_instance_valid(_service)
			or not _service.owner_matches(_save)
		):
			_lost()
			return
		if not _service.changed.is_connected(_changed):
			_service.changed.connect(_changed)
			_service.tree_exiting.connect(_lost)


func _disconnect() -> void:
	if is_instance_valid(_service):
		if _service.changed.is_connected(_changed):
			_service.changed.disconnect(_changed)
		if _service.tree_exiting.is_connected(_lost):
			_service.tree_exiting.disconnect(_lost)


func _lost() -> void:
	_command_error = OK
	if is_instance_valid(toast):
		toast.hide_message()
	_disconnect()
	_service = null
	refresh()


func _changed() -> void:
	_command_error = OK
	refresh()


func request() -> void:
	if _dispatch or not is_inside_tree() or not is_instance_valid(_service):
		return
	if not _row.is_visible_in_tree() or _row.disabled or _row.loading:
		return
	_dispatch = true
	toast.hide_message()
	_attempt += 1
	_command_error = OK
	var error: Error = _service.request_policy()
	_dispatch = false
	if is_instance_valid(_service) and error != OK:
		_command_error = error
		_error_revision = _service.snapshot().revision
	refresh()


func refresh() -> void:
	if not _bound or not is_instance_valid(message):
		return
	if (
		is_instance_valid(_service)
		and (not is_instance_valid(_save) or not _service.owner_matches(_save))
	):
		_lost()
		return
	var data: Dictionary = (
		_service.snapshot()
		if is_instance_valid(_service)
		else {"state": &"unavailable", "available": false, "revision": 0}
	)
	if data.state == &"unavailable" or data.revision != _error_revision:
		_command_error = OK
	var key: String = "" if data.state == &"idle" else "settings.policy." + str(data.state)
	if _command_error != OK:
		key = "settings.policy.busy" if _command_error == ERR_BUSY else "settings.policy.failed"
	_row.loading = data.state == &"requested"
	_row.leading_icon = _row.icon if _row.loading else null
	_row.disabled = _dispatch or not data.available or _row.loading
	message.visible = not key.is_empty()
	message.text = tr(key) if not key.is_empty() else ""
	var terminal: bool = data.state in [&"handed_off", &"failed"] or _command_error != OK
	var identity: int = _service.get_instance_id() if is_instance_valid(_service) else 0
	var fingerprint: String = "%s/%s/%s/%s" % [identity, data.revision, _attempt, key]
	if terminal and _root.is_visible_in_tree() and fingerprint != _seen:
		var success: bool = data.state == &"handed_off" and _command_error == OK
		if toast.show_message(key, &"success" if success else &"error") == OK:
			_seen = fingerprint


func _exit_tree() -> void:
	_disconnect()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh()
