extends Node
## Caller-owned privacy-policy browser handoff, with no destination or transport.

signal changed

const SAVE: Script = preload("res://services/save.gd")
var _save: SAVE
var _browser: Callable
var _bound: bool = false
var _busy: bool = false
var _notifying: bool = false
var _state: StringName = &"idle"
var _error: Error = OK
var _revision: int = 0


## @api Browser(language:String)->Error owns approved HTTPS URL/native error mapping.
func configure(save: Node, browser: Callable) -> Error:
	if _busy or _notifying:
		return ERR_BUSY
	if not save is SAVE or not save.is_loaded() or not browser.is_valid():
		return ERR_UNCONFIGURED
	if browser.get_argument_count() != 1:
		return ERR_INVALID_PARAMETER
	_save = save
	_browser = browser
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
		and _browser.is_valid()
	)


func snapshot() -> Dictionary:
	var live: bool = _live()
	return {
		"available": live,
		"state": _state if live else &"unavailable",
		"error": _error if live else ERR_UNAVAILABLE,
		"revision": _revision
	}


## @api Explicit handoff only; no proof of page load or consent is inferred.
func request_policy() -> Error:
	if _busy or _notifying:
		return ERR_BUSY
	if not _live():
		return ERR_UNCONFIGURED
	var language: String = _save.committed_view().sections.settings.language
	_busy = true
	_set_state(&"requested", OK)
	var error: Error = ERR_UNCONFIGURED
	if _live():
		var result: Variant = _browser.call(language)
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
