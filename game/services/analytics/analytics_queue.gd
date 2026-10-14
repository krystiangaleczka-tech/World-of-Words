class_name AnalyticsQueue
extends RefCounted
## Durable analytics-only FIFO document with SaveStorage's atomic recovery boundaries.

const VERSION: int = 1

var _storage: SaveStorage
var _primary_valid: bool = false
var _pending_temp: bool = false


func _init(storage: SaveStorage = null) -> void:
	_storage = storage if storage != null else SaveStorage.new("user://analytics_queue.json")


## @api Restore the first valid primary/temp/backup document and canonicalize recovery.
## A wholly corrupt analytics-only queue is replaced with an empty document.
func restore(capacity: int, validator: Callable) -> Dictionary:
	if capacity < 1 or not validator.is_valid():
		return {"error": ERR_INVALID_PARAMETER, "events": []}
	for suffix: String in ["", ".tmp", ".bak"]:
		var document: Dictionary = _storage.read_document(suffix)
		if _valid_document(document, capacity, validator):
			var events: Array[Dictionary] = []
			events.assign(document["events"])
			if suffix.is_empty():
				_primary_valid = true
				return {"error": OK, "events": events.duplicate(true)}
			var recovery_error: Error = (
				_promote_temp_recovery() if suffix == ".tmp" else _replace_backup_recovery(events)
			)
			return {"error": recovery_error, "events": events.duplicate(true)}
	if not _storage.has_any_file():
		return {"error": replace([]), "events": []}
	var reset_error: Error = _replace_corrupt([])
	return {"error": reset_error, "events": []}


## @api Atomically replace the FIFO snapshot.
func replace(events: Array[Dictionary]) -> Error:
	if _pending_temp:
		var promotion_error: Error = _storage.promote_temp()
		if promotion_error != OK:
			return promotion_error
		_pending_temp = false
		_primary_valid = true
	var document: Dictionary = {"schema_version": VERSION, "events": events.duplicate(true)}
	var text: String = JSON.stringify(document, "", true, true)
	var had_primary: bool = _primary_valid
	var error: Error = _storage.commit(text, had_primary)
	if error == OK:
		_primary_valid = true
		return OK
	return _resolve_commit_error(error, text, had_primary)


## @api Publish an empty primary and remove recovery copies that could contain denied events.
## If publishing fails, best-effort deletion still prevents a stale queue from being restored.
func clear() -> Error:
	var publish_error: Error = replace([])
	if publish_error != OK:
		var purge_error: Error = _remove_all()
		_primary_valid = false
		_pending_temp = false
		return purge_error
	var purge_error: Error = _purge_paths([_storage.path + ".tmp", _storage.path + ".bak"])
	_pending_temp = false
	_primary_valid = FileAccess.file_exists(_storage.path)
	return purge_error


func _promote_temp_recovery() -> Error:
	var remove_error: Error = _remove_if_present(_storage.path)
	if remove_error != OK:
		return remove_error
	var error: Error = _storage.promote_temp()
	if error == OK:
		_primary_valid = true
		_pending_temp = false
	return error


func _replace_backup_recovery(events: Array[Dictionary]) -> Error:
	var remove_error: Error = _remove_if_present(_storage.path)
	if remove_error != OK:
		return remove_error
	_primary_valid = false
	# Keep the accepted backup until a new primary is durably published.
	return replace(events)


func _replace_corrupt(events: Array[Dictionary]) -> Error:
	var remove_error: Error = _remove_all()
	if remove_error != OK:
		return remove_error
	_primary_valid = false
	return replace(events)


func _resolve_commit_error(error: Error, text: String, had_primary: bool) -> Error:
	# A checkpoint can fail after the desired primary is already durable.
	if _file_matches(_storage.path, text):
		_primary_valid = true
		_pending_temp = false
		return OK
	# With a previously valid primary, its absence proves rotation happened after temp flush.
	# Keep the accepted temp recoverable if the final rename cannot be completed now.
	if (
		had_primary
		and not FileAccess.file_exists(_storage.path)
		and _file_matches(_storage.path + ".tmp", text)
	):
		var promotion_error: Error = _storage.promote_temp()
		if promotion_error == OK:
			_primary_valid = true
			_pending_temp = false
		else:
			_primary_valid = false
			_pending_temp = true
		return OK
	# Before rotation, the old primary remains authoritative and the candidate was rejected.
	_remove_if_present(_storage.path + ".tmp")
	return error


func _file_matches(path: String, text: String) -> bool:
	return FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == text


func _remove_all() -> Error:
	return _purge_paths([_storage.path, _storage.path + ".tmp", _storage.path + ".bak"])


func _purge_paths(paths: Array[String]) -> Error:
	var first_error: Error = OK
	for path: String in paths:
		var error: Error = _purge_if_present(path)
		if first_error == OK and error != OK:
			first_error = error
	return first_error


func _purge_if_present(path: String) -> Error:
	var remove_error: Error = _remove_if_present(path)
	if remove_error == OK or not FileAccess.file_exists(path):
		return remove_error
	# Directory permissions can block unlink while the analytics-only file remains writable.
	# Invalidate its contents so recovery cannot resurrect revoked events.
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return remove_error
	file.store_string("")
	if file.get_error() == OK:
		file.flush()
	var wipe_error: Error = file.get_error()
	file.close()
	return remove_error if wipe_error == OK else wipe_error


func _remove_if_present(path: String) -> Error:
	return DirAccess.remove_absolute(path) if FileAccess.file_exists(path) else OK


func _valid_document(document: Dictionary, capacity: int, validator: Callable) -> bool:
	if (
		document.size() != 2
		or document.get("schema_version") != VERSION
		or not document.get("events") is Array
	):
		return false
	var events: Array = document["events"]
	if events.size() > capacity:
		return false
	for event: Variant in events:
		if not event is Dictionary or not bool(validator.call(event)):
			return false
	return true
