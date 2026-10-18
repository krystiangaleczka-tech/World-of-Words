extends RefCounted
## Caller-owned startup presentation and best-effort deferred content-error telemetry.

signal started

const NAV: Script = preload("res://services/nav.gd")
const SAVE: Script = preload("res://services/save.gd")
const CONFIG: Script = preload("res://services/config.gd")
const CONTENT: Script = preload("res://services/content.gd")
const MONETIZATION: Script = preload("res://services/monetization.gd")
const ANALYTICS: Script = preload("res://services/analytics.gd")
var _nav: NAV
var _save: SAVE
var _config: CONFIG
var _content: CONTENT
var _monetization: MONETIZATION
var _analytics: ANALYTICS
var _host: Node
var _root: String
var _layer: CanvasLayer
var _box: VBoxContainer
var _kind: StringName = &""
var _restore_started: bool = false
var _lost_acknowledged: bool = false
var _busy: bool = false
var _pending_content_error: int = -1


func configure(
	nav: NAV,
	save: SAVE,
	config: CONFIG,
	content: CONTENT,
	monetization: MONETIZATION,
	analytics: ANALYTICS
) -> void:
	_nav = nav
	_save = save
	_config = config
	_content = content
	_monetization = monetization
	_analytics = analytics


func start(host: Node, content_root: String = "res://content") -> Error:
	if _busy or not is_instance_valid(host) or not host.is_inside_tree():
		return ERR_BUSY
	_busy = true
	_clear()
	_host = host
	_root = content_root
	var error: Error = _nav.start(host, content_root)
	if error != OK:
		if _nav.boot_failure_stage == &"content":
			_pending_content_error = int(error)
		_show(&"error")
	else:
		_publish_content_error()
		if not _lost_acknowledged and _save.last_load_report().get("corrupted", false):
			_show(&"lost")
		started.emit()
	_busy = false
	return error


func _publish_content_error() -> void:
	if _pending_content_error < 0 or not _analytics.runtime_ready():
		return
	var receipt: Dictionary = {"accepted": false}
	var observe: Callable = func(name: StringName, _params: Dictionary) -> void:
		if name == &"content_load_failed":
			receipt.accepted = true
	_analytics.event_accepted.connect(observe)
	var error: Error = _analytics.track(
		&"content_load_failed", {"error_code": _pending_content_error}
	)
	_analytics.event_accepted.disconnect(observe)
	if error == OK or receipt.accepted:
		_pending_content_error = -1


func _show(kind: StringName) -> void:
	_kind = kind
	_layer = CanvasLayer.new()
	_layer.name = "StartupRecoveryLayer"
	_layer.layer = 1
	_host.add_child(_layer)
	_box = load("res://features/recovery/startup.gd").new()
	_box.configure(kind)
	if kind == &"lost":
		var sheet: Sheet = Sheet.new()
		sheet.name = "LostSaveModal"
		sheet.dismissible = false
		sheet.configure_content(_box)
		_layer.add_child(sheet)
		sheet.open()
	else:
		var shell: ScreenScaffold = ScreenScaffold.new()
		_layer.add_child(shell)
		shell.body.add_child(_box)
	if kind == &"lost" and _restore_started:
		_box.restore_requested()
	_box.primary_requested.connect(_primary)
	_box.secondary_requested.connect(_secondary)


func _primary() -> void:
	if _busy or not is_instance_valid(_box):
		return
	if _kind == &"error":
		start(_host, _root)
	elif _kind == &"lost" and not _restore_started:
		_busy = true
		var error: Error = _monetization.restore_purchases()
		if error == OK:
			_restore_started = true
			_box.restore_requested()
		else:
			_box.show_status("recovery.status.restore_error")
		_busy = false


func _secondary() -> void:
	if _busy or not is_instance_valid(_box):
		return
	_busy = true
	if _kind == &"lost":
		if _save.flush() == OK:
			_lost_acknowledged = true
			_clear()
		else:
			_box.show_status("recovery.status.save_error")
	elif _nav.go_home(true) == OK:
		var home: ScreenScaffold = _nav.mounted_screen() as ScreenScaffold
		_box.reparent(home.body)
		_box.set_inline()
		_layer.queue_free()
		_layer = null
	else:
		_box.show_status("recovery.status.home_error")
	_busy = false


func presentation() -> Control:
	return _box if is_instance_valid(_box) else null


func _clear() -> void:
	if is_instance_valid(_box):
		if _box.primary_requested.is_connected(_primary):
			_box.primary_requested.disconnect(_primary)
		if _box.secondary_requested.is_connected(_secondary):
			_box.secondary_requested.disconnect(_secondary)
		if _box.get_parent() != null:
			_box.get_parent().remove_child(_box)
		_box.queue_free()
	_box = null
	if is_instance_valid(_layer):
		if _layer.get_parent() != null:
			_layer.get_parent().remove_child(_layer)
		_layer.queue_free()
	_layer = null
	_kind = &""


func close() -> void:
	_clear()
	_pending_content_error = -1
	_host = null
