extends VBoxContainer
## Feature composition of existing catalog controls; emits intent only.

signal primary_requested
signal secondary_requested
var _kind: StringName
var _panel: StatePanel
var _secondary: TextButton
var _status: Label
var _status_key: String = ""
var _modal: bool = true
var _catalog: LocaleCatalog = LocaleCatalog.new()


func configure(kind: StringName) -> void:
	_kind = kind


func _enter_tree() -> void:
	_catalog.register_all()
	if _panel != null:
		_connect_actions()


func _ready() -> void:
	name = "StartupRecovery"
	add_theme_constant_override("separation", Tokens.Space.M)
	_panel = StatePanel.new()
	_panel.name = "State"
	var lost: bool = _kind == &"lost"
	_panel.configure(
		&"error",
		"recovery.lost.title" if lost else "recovery.error.title",
		"recovery.lost.body" if lost else "recovery.error.body",
		"recovery.action.restore" if lost else "recovery.action.retry"
	)
	add_child(_panel)
	_secondary = load("res://ui/components/TextButton.tscn").instantiate()
	_secondary.name = "Secondary"
	_secondary.text_key = "recovery.action.continue" if lost else "recovery.action.home"
	add_child(_secondary)
	_status = CatalogSurface.label(&"Caption")
	_status.name = "Status"
	add_child(_status)
	_connect_actions()


func _connect_actions() -> void:
	if not _panel.action_requested.is_connected(_on_primary):
		_panel.action_requested.connect(_on_primary)
	if not _secondary.pressed.is_connected(_on_secondary):
		_secondary.pressed.connect(_on_secondary)


func _on_primary() -> void:
	primary_requested.emit()


func _on_secondary() -> void:
	secondary_requested.emit()


func show_status(key: String) -> void:
	_status_key = key
	_status.text = tr(key) if not key.is_empty() else ""


func restore_requested() -> void:
	_panel.configure(&"error", "recovery.lost.title", "recovery.lost.body")
	show_status("recovery.status.requested")


func set_inline() -> void:
	_modal = false
	_secondary.hide()


func _unhandled_key_input(_event: InputEvent) -> void:
	if _modal:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _status != null:
		show_status(_status_key)


func _exit_tree() -> void:
	if _panel != null and _panel.action_requested.is_connected(_on_primary):
		_panel.action_requested.disconnect(_on_primary)
	if _secondary != null and _secondary.pressed.is_connected(_on_secondary):
		_secondary.pressed.disconnect(_on_secondary)
	_catalog.unregister()
