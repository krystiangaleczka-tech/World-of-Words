class_name SettingsRuntime
extends Node
## Caller-owned committed settings application. A failed intent has one explicit retry.

signal changed
signal write_failed(error: Error)

const SAVE: Script = preload("res://services/save.gd")
const THEMES: Array[Theme] = [
	preload("res://ui/theme/generated/theme_default_100.tres"),
	preload("res://ui/theme/generated/theme_default_115.tres"),
	preload("res://ui/theme/generated/theme_default_130.tres"),
	preload("res://ui/theme/generated/theme_hc_100.tres"),
	preload("res://ui/theme/generated/theme_hc_115.tres"),
	preload("res://ui/theme/generated/theme_hc_130.tres")
]
var _save: SAVE
var _root: Control
var _pending: Dictionary = {}
var _values: Dictionary = {}
var _busy: bool = false
var _notifying: bool = false


func configure(save: Node, root: Control) -> Error:
	if _busy or _notifying or not _pending.is_empty():
		return ERR_BUSY
	if not save is SAVE or not save.is_loaded() or not is_instance_valid(root):
		return ERR_UNCONFIGURED
	_disconnect()
	_save = save
	_root = root
	_connect()
	_sync()
	return OK


func snapshot() -> Dictionary:
	return _values.duplicate(true)


func set_value(key: StringName, value: Variant) -> Error:
	if _busy or _notifying or not _pending.is_empty():
		return ERR_BUSY
	if not is_instance_valid(_save) or not is_instance_valid(_root):
		return ERR_UNCONFIGURED
	if key == &"language" or key not in SaveSchema.SETTINGS:
		return ERR_INVALID_PARAMETER
	_pending = {"key": key, "value": value, "revision": _save.committed_view().revision}
	return _write()


func retry() -> Error:
	if _busy or _notifying:
		return ERR_BUSY
	if _pending.is_empty():
		return ERR_DOES_NOT_EXIST
	return _write()


func _write() -> Error:
	if not is_instance_valid(_save) or not is_instance_valid(_root):
		return ERR_UNCONFIGURED
	_busy = true
	var error: Error = _save.set_setting(_pending.key, _pending.value)
	if error == OK:
		_pending.clear()
		_sync()
	elif error in [ERR_INVALID_DATA, ERR_INVALID_PARAMETER]:
		_pending.clear()
	if error != OK:
		write_failed.emit(error)
	_busy = false
	return error


func _sync() -> void:
	if not is_instance_valid(_save) or not is_instance_valid(_root):
		return
	var values: Dictionary = _save.committed_view().sections.settings
	if not _pending.is_empty():
		var key: StringName = _pending.key
		var replaced: bool = (
			_save.committed_view().revision > _pending.revision
			and _save.get_setting(key) != _pending.value
		)
		if replaced or values[key] == _pending.value or values[key] != _values.get(key):
			_pending.clear()
	var different: bool = values != _values
	_values = values.duplicate(true)
	_notifying = true
	_root.theme = THEMES[int(values.text_scale) + (3 if values.high_contrast else 0)]
	Tokens.reduced_motion = values.reduced_motion
	if different:
		changed.emit()
	_notifying = false


func _on_setting_changed(key: StringName) -> void:
	# A committed external winner supersedes the failed intent, including a reset to old value.
	if not _pending.is_empty() and _pending.key == key:
		_pending.clear()
	_sync()


func _connect() -> void:
	if is_inside_tree() and is_instance_valid(_save):
		if not _save.setting_changed.is_connected(_on_setting_changed):
			_save.setting_changed.connect(_on_setting_changed)


func _disconnect() -> void:
	if is_instance_valid(_save) and _save.setting_changed.is_connected(_on_setting_changed):
		_save.setting_changed.disconnect(_on_setting_changed)


func _enter_tree() -> void:
	_connect()
	_sync()


func _exit_tree() -> void:
	_disconnect()
