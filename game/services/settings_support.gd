extends Node
## Explicit caller-owned support draft composition. The port must never send mail.

signal changed

const SAVE: Script = preload("res://services/save.gd")
var _locales: LocaleCatalog = LocaleCatalog.new()
var _save: SAVE
var _composer: Callable
var _bound: bool = false
var _busy: bool = false
var _notifying: bool = false
var _state: StringName = &"idle"
var _error: Error = OK
var _revision: int = 0


## @api Pure binding; caller supplies approved recipient/native encoding via the port.
func configure(save: Node, composer: Callable) -> Error:
	if _busy or _notifying:
		return ERR_BUSY
	if not save is SAVE or not save.is_loaded() or not composer.is_valid():
		return ERR_UNCONFIGURED
	if composer.get_argument_count() != 2:
		return ERR_INVALID_PARAMETER
	var locale_error: Error = _locales.register_all()
	if locale_error != OK:
		return locale_error
	_save = save
	_composer = composer
	_bound = true
	_set_state(&"idle", OK)
	return OK


func owner_matches(save: Node) -> bool:
	return is_instance_valid(save) and _live() and save == _save


func _live() -> bool:
	return (
		is_inside_tree()
		and _bound
		and is_instance_valid(_save)
		and _save.is_loaded()
		and _composer.is_valid()
	)


## @api Fresh readonly player-editable text, with no provider work or Save mutation.
func draft() -> Dictionary:
	if not _live():
		return {}
	var view: Dictionary = _save.committed_view()
	var lines: PackedStringArray = [
		tr("settings.support.instruction"),
		"",
		"",
		tr("settings.support.install_id") % str(view.sections.meta.install_id),
		(
			tr("settings.support.version")
			% str(ProjectSettings.get_setting("application/config/version", ""))
		),
		tr("settings.support.language") % str(view.sections.settings.language)
	]
	return {"subject": tr("settings.support.subject"), "body": "\n".join(lines)}


func snapshot() -> Dictionary:
	var live: bool = _live()
	return {
		"available": live,
		"state": _state if live else &"unavailable",
		"error": _error if live else ERR_UNAVAILABLE,
		"revision": _revision,
		"short_id": str(_save.committed_view().sections.meta.install_id).left(8) if live else ""
	}


## @api OK certifies port handoff only. No automatic retry or message delivery claim.
func request_draft() -> Error:
	if _busy or _notifying:
		return ERR_BUSY
	if not _live():
		return ERR_UNCONFIGURED
	var text: Dictionary = draft()
	_busy = true
	_set_state(&"requested", OK)
	var error: Error = ERR_UNCONFIGURED
	if _live():
		var result: Variant = _composer.call(text.subject, text.body)
		if result is int and result >= OK and result <= ERR_PRINTER_ON_FIRE:
			error = result as Error
		else:
			error = ERR_INVALID_DATA
	if not _live():
		error = ERR_UNCONFIGURED
	_set_state(&"handed_off" if error == OK else &"failed", error)
	_busy = false
	return error


func _set_state(state: StringName, error: Error) -> void:
	_state = state
	_error = error
	_revision += 1
	_notifying = true
	changed.emit()
	_notifying = false


func _exit_tree() -> void:
	_bound = false
	_locales.unregister()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_locales.unregister()
