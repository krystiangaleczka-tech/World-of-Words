class_name SettingsLanguage
extends Node
## Explicit content-coherent language choice. Caller owns safe checkpoint/reload.

signal changed
signal failed(error: Error)

const SAVE: Script = preload("res://services/save.gd")
const CONTENT: Script = preload("res://services/content.gd")
const NAMES: Dictionary[String, String] = {
	"pl": "settings.language.polish",
	"en": "settings.language.english",
	"de": "settings.language.german"
}
var _save: SAVE
var _content: CONTENT
var _reload: Callable
var _root: String
var _catalog: Dictionary[String, String] = {}
var _debug: bool = false
var _preview: bool = false
var _language: String = ""
var _pending: String = ""
var _pending_hash: String = ""
var _state: StringName = &"ready"
var _error: Error = OK
var _busy: bool = false
var _resume_scheduled: bool = false


func configure(
	save: Node,
	content: Node,
	reload: Callable,
	root: String = "res://content",
	debug_preview: bool = false
) -> Error:
	if _busy or not _pending.is_empty():
		return ERR_BUSY
	if (
		not save is SAVE
		or not save.is_loaded()
		or not content is CONTENT
		or not content.is_loaded()
		or not reload.is_valid()
	):
		return ERR_UNCONFIGURED
	var language: String = save.committed_view().sections.settings.language
	var catalog: Dictionary[String, String] = _discover(root)
	if content.get_language() != language or content.manifest_hash() != catalog.get(language, ""):
		return ERR_INVALID_DATA
	_busy = true
	_disconnect()
	_restore_preview()
	_save = save
	_content = content
	_reload = reload
	_root = root
	_catalog = catalog
	_debug = debug_preview and OS.is_debug_build()
	_language = language
	_state = &"ready"
	_error = OK
	_connect()
	TranslationServer.set_locale(_language)
	_busy = false
	return OK


func choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for language: String in _catalog:
		result.append(
			{
				"id": language,
				"name_key": NAMES.get(language, "settings.language.other"),
				"debug": false
			}
		)
	if _debug and not _catalog.has("en"):
		result.append(
			{
				"id": "restore_preview" if _preview else "preview_en",
				"name_key":
				"settings.language.restore_preview" if _preview else "settings.language.preview_en",
				"debug": true
			}
		)
	return result


func snapshot() -> Dictionary:
	return {
		"language": _language,
		"ui_language": "en" if _preview else _language,
		"preview": _preview,
		"pending": _pending,
		"state": _state,
		"error": _error
	}


static func initial_language(device_locale: String, root: String = "res://content") -> String:
	var catalog: Dictionary[String, String] = _discover(root)
	var base: String = device_locale.replace("-", "_").get_slice("_", 0).to_lower()
	return base if catalog.has(base) else ("pl" if catalog.has("pl") else "")


static func configure_initial_defaults(
	save: Node, reduced_motion: bool, device_locale: String, root: String = "res://content"
) -> Error:
	if not save is SAVE:
		return ERR_UNCONFIGURED
	var language: String = initial_language(device_locale, root)
	return (
		ERR_FILE_NOT_FOUND
		if language.is_empty()
		else save.configure_system_defaults(reduced_motion, language)
	)


func select(language: String) -> Error:
	if _busy or not _pending.is_empty():
		return ERR_BUSY
	if not is_instance_valid(_save) or not is_instance_valid(_content):
		return ERR_UNCONFIGURED
	if language in ["preview_en", "restore_preview"]:
		return _select_preview(language)
	if not _catalog.has(language):
		return ERR_INVALID_PARAMETER
	if language == _language:
		_busy = true
		_restore_preview()
		changed.emit()
		_busy = false
		return OK
	_pending = language
	_pending_hash = _catalog[language]
	return _attempt()


func _select_preview(language: String) -> Error:
	if not _debug or _catalog.has("en"):
		return ERR_UNAVAILABLE
	_busy = true
	_preview = language == "preview_en"
	TranslationServer.set_locale("en" if _preview else _language)
	changed.emit()
	_busy = false
	return OK


func retry() -> Error:
	if _busy:
		return ERR_BUSY
	if _pending.is_empty():
		return ERR_DOES_NOT_EXIST
	return _attempt()


func _attempt() -> Error:
	_busy = true
	var error: Error = _resume()
	_busy = false
	return error


func _prepare_target() -> Error:
	if not is_instance_valid(_save) or not is_instance_valid(_content):
		return _fail(ERR_UNCONFIGURED, &"prepare_failed")
	var candidate: CONTENT = CONTENT.new()
	var valid: bool = candidate.load_manifest(_pending, _root) == OK
	valid = valid and candidate.manifest_hash() == _pending_hash
	candidate.free()
	if not valid:
		return _fail(ERR_INVALID_DATA, &"validation_failed")
	if not _reload.is_valid():
		return _fail(ERR_UNAVAILABLE, &"prepare_failed")
	var error: Error = _call_reload(&"prepare")
	if error != OK:
		return _fail(error, &"prepare_failed")
	return OK


func _resume() -> Error:
	var error: Error = _prepare_target()
	if error != OK:
		return error
	if _save.committed_view().sections.settings.language != _pending:
		error = _save.set_setting(&"language", _pending)
		if error != OK:
			return _fail(error, &"write_failed")
	error = _call_reload(&"apply")
	if error != OK:
		return _fail(error, &"reload_pending")
	if _content.get_language() != _pending or _content.manifest_hash() != _pending_hash:
		return _fail(ERR_INVALID_DATA, &"reload_pending")
	_language = _pending
	_pending = ""
	_pending_hash = ""
	_state = &"ready"
	_error = OK
	_preview = false
	TranslationServer.set_locale(_language)
	changed.emit()
	return OK


func _call_reload(phase: StringName) -> Error:
	var result: Variant = _reload.call(phase, _pending)
	return int(result) as Error if result is int else ERR_INVALID_DATA


func _fail(error: Error, state: StringName) -> Error:
	_state = state
	_error = error
	changed.emit()
	failed.emit(error)
	return error


static func _discover(root: String) -> Dictionary[String, String]:
	var catalog: Dictionary[String, String] = {}
	if not DirAccess.dir_exists_absolute(root):
		return catalog
	var directories: PackedStringArray = DirAccess.get_directories_at(root)
	directories.sort()
	for language: String in directories:
		var candidate: CONTENT = CONTENT.new()
		if candidate.load_manifest(language, root) == OK:
			catalog[language] = candidate.manifest_hash()
		candidate.free()
	return catalog


func _restore_preview() -> void:
	if _preview:
		_preview = false
		TranslationServer.set_locale(_language)


func _on_setting_changed(key: StringName) -> void:
	if key == &"language" and not _busy and not _pending.is_empty():
		_queue_resume()


func _queue_resume() -> void:
	if _resume_scheduled or _busy or _pending.is_empty() or not is_instance_valid(_save):
		return
	if _save.committed_view().sections.settings.language == _pending:
		_resume_scheduled = true
		_resume_external.call_deferred()


func _resume_external() -> void:
	_resume_scheduled = false
	if is_inside_tree() and not _busy and not _pending.is_empty():
		if _save.committed_view().sections.settings.language == _pending:
			retry()


func _connect() -> void:
	if is_inside_tree() and is_instance_valid(_save):
		if not _save.setting_changed.is_connected(_on_setting_changed):
			_save.setting_changed.connect(_on_setting_changed)


func _disconnect() -> void:
	if is_instance_valid(_save) and _save.setting_changed.is_connected(_on_setting_changed):
		_save.setting_changed.disconnect(_on_setting_changed)


func _enter_tree() -> void:
	_connect()
	_queue_resume()


func _exit_tree() -> void:
	_disconnect()
	_restore_preview()
