extends Node
## Explicit local screen composition; global navigation remains caller-owned.

var _settings: SettingsScreen
var _licences: LicencesScreen
var _bound: bool = false
var _active: bool = false
var _busy: bool = false
var _scroll: int = 0
var _focus: WeakRef
var _previous_theme: Theme


func configure(settings: Node, licences: Node) -> Error:
	if _busy or _active:
		return ERR_BUSY
	if not is_inside_tree() or not settings is SettingsScreen or not licences is LicencesScreen:
		return ERR_UNCONFIGURED
	if (
		not settings.is_node_ready()
		or not licences.is_node_ready()
		or not settings.is_inside_tree()
		or not licences.is_inside_tree()
		or settings.get_parent() != licences.get_parent()
		or settings.get_viewport() != licences.get_viewport()
		or settings.snapshot().is_empty()
		or not settings.is_visible_in_tree()
		or licences.is_visible_in_tree()
	):
		return ERR_UNCONFIGURED
	_disconnect()
	_settings = settings
	_licences = licences
	_bound = true
	_settings.action_requested.connect(_action)
	_settings.tree_exiting.connect(_lost)
	_settings.theme_changed.connect(_sync_theme)
	_licences.back_requested.connect(_return)
	_licences.tree_exiting.connect(_lost)
	return OK


func snapshot() -> Dictionary:
	var valid: bool = _valid()
	return {
		"bound": valid,
		"state": (&"licences" if _active else &"settings") if valid else &"unavailable"
	}


func _open_check() -> Error:
	if _busy:
		return ERR_BUSY
	if not _valid():
		_lost()
		return ERR_UNCONFIGURED
	if _active:
		return ERR_ALREADY_IN_USE
	if not _settings.is_visible_in_tree() or _licences.is_visible_in_tree():
		return ERR_UNAVAILABLE
	if _settings.text_sheet.state != &"closed" or _settings.language_sheet.state != &"closed":
		return ERR_BUSY
	return OK


func open() -> Error:
	var error: Error = _open_check()
	if error != OK:
		return error
	_busy = true
	_scroll = _settings.scroll.scroll_vertical
	var focused: Control = _settings.get_viewport().gui_get_focus_owner()
	_focus = (
		weakref(focused)
		if is_instance_valid(focused) and _settings.is_ancestor_of(focused)
		else null
	)
	_previous_theme = _licences.theme
	_active = true
	_sync_theme()
	_settings.hide()
	if not _valid() or not _active:
		_busy = false
		return ERR_UNCONFIGURED
	_licences.show()
	if not _valid() or not _active:
		_busy = false
		return ERR_UNCONFIGURED
	_licences.scroll.grab_focus()
	_busy = false
	return OK


func handle_back() -> bool:
	if _busy or not _active:
		return false
	if not _valid():
		_lost()
		return false
	_licences.handle_back()
	return true


func _action(action: StringName) -> void:
	if action == &"licences":
		open()


func _valid() -> bool:
	return (
		is_inside_tree()
		and _bound
		and is_instance_valid(_settings)
		and is_instance_valid(_licences)
		and _settings.is_inside_tree()
		and _licences.is_inside_tree()
		and _settings.get_parent() == _licences.get_parent()
		and _settings.get_viewport() == _licences.get_viewport()
		and not _settings.snapshot().is_empty()
	)


func _sync_theme() -> void:
	if _active and _valid():
		_licences.theme = _settings.theme


func _return() -> void:
	if _busy or not _active:
		return
	if not _valid():
		_lost()
		return
	_busy = true
	_licences.hide()
	if not _valid():
		_busy = false
		return
	_active = false
	_licences.theme = _previous_theme
	_settings.show()
	if _valid():
		_restore_settings.call_deferred()
	_busy = false


func _restore_settings() -> void:
	if not _valid() or _active or not _settings.is_visible_in_tree():
		return
	_settings.scroll.scroll_vertical = _scroll
	var focused: Control = _focus.get_ref() as Control if _focus != null else null
	if (
		not is_instance_valid(focused)
		or not _settings.is_ancestor_of(focused)
		or not focused.is_visible_in_tree()
	):
		focused = _settings.rows[&"licences"]
	focused.grab_focus()


func _lost() -> void:
	var was_active: bool = _active
	_active = false
	_bound = false
	_disconnect()
	if was_active:
		if is_instance_valid(_licences):
			_licences.hide()
			_licences.theme = _previous_theme
		if is_instance_valid(_settings):
			_settings.show()


func _disconnect() -> void:
	if is_instance_valid(_settings):
		if _settings.action_requested.is_connected(_action):
			_settings.action_requested.disconnect(_action)
		if _settings.tree_exiting.is_connected(_lost):
			_settings.tree_exiting.disconnect(_lost)
		if _settings.theme_changed.is_connected(_sync_theme):
			_settings.theme_changed.disconnect(_sync_theme)
	if is_instance_valid(_licences):
		if _licences.back_requested.is_connected(_return):
			_licences.back_requested.disconnect(_return)
		if _licences.tree_exiting.is_connected(_lost):
			_licences.tree_exiting.disconnect(_lost)


func _exit_tree() -> void:
	_lost()
