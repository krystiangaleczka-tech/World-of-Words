extends ServiceStub
## @api Save v2. Other services use only their own section; settings/meta belong to Save.

signal setting_changed(key: StringName)
signal backup_restored
signal flush_failed(error: Error)

var _storage: SaveStorage = SaveStorage.new()
var _migrations: SaveMigrations = SaveMigrations.new()
var _id_factory: Callable = SaveSchema.new_install_id
var _data: Dictionary = {}
var _loaded: bool = false
var _dirty: bool = false
var _primary_valid: bool = false


## @api Inject isolated storage/identity generation before loading (tests/tools only).
func configure(storage: SaveStorage, id_factory: Callable = Callable()) -> void:
	assert(not _loaded and storage != null)
	_storage = storage
	if id_factory.is_valid():
		_id_factory = id_factory


## @api Load primary, temp, backup; migrate/validate before exposing any sections.
## A first install is persisted immediately. Corrupt originals remain until an explicit flush.
func load() -> Error:
	if _loaded:
		return OK
	assert(get_clock() != null, "Save requires an injected Clock before load")
	for suffix: String in ["", ".tmp", ".bak"]:
		var source: Dictionary = _storage.read_document(suffix)
		var candidate: Dictionary = _migrations.upgrade(source)
		if SaveSchema.is_valid(candidate):
			_data = SaveSchema.canonical(candidate)
			_loaded = true
			_primary_valid = suffix.is_empty()
			_dirty = not _primary_valid or source.get("schema_version") != SaveSchema.VERSION
			if not _primary_valid:
				backup_restored.emit()
			return OK
	var existing: bool = _storage.has_any_file()
	var identity: String = str(_id_factory.call())
	var created_at: String = (
		Time.get_datetime_string_from_unix_time(get_clock().unix_time_seconds()) + "Z"
	)
	_data = SaveSchema.fresh(
		identity, created_at, str(ProjectSettings.get_setting("application/config/version", ""))
	)
	if not SaveSchema.is_valid(_data):
		_data = {}
		return ERR_INVALID_DATA
	_loaded = true
	_dirty = true
	if existing:
		Events.save_corrupted.emit()
		return OK
	return flush()


## @api Whether a valid save has been loaded, without triggering domain work.
func is_loaded() -> bool:
	return _loaded


## @api Explicit debug reset of gameplay only; identity, settings and purchases are preserved.
## Persist before publishing new memory. Existing storage recovery semantics apply on failure.
func debug_reset() -> Error:
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	if not _loaded:
		return ERR_UNCONFIGURED
	var meta: Dictionary = _data["meta"]
	var candidate: Dictionary = SaveSchema.fresh(
		str(meta["install_id"]), str(meta["created_at"]), str(meta["app_version"])
	)
	for section: String in ["meta", "settings", "monetization"]:
		candidate[section] = (_data[section] as Dictionary).duplicate(true)
	var error: Error = _storage.commit(JSON.stringify(candidate, "", true, true), _primary_valid)
	if error != OK:
		flush_failed.emit(error)
		return error
	_data = SaveSchema.canonical(candidate)
	_dirty = false
	_primary_valid = true
	return OK


## @api Return an independent copy for the owning service; unknown names return {}.
func get_section(section: StringName) -> Dictionary:
	assert(_loaded)
	if section not in SaveSchema.SECTIONS:
		return {}
	return (_data[str(section)] as Dictionary).duplicate(true)


## @api Replace an owner section after structural validation; flush only on meaningful events.
## meta/settings changes must use Save-owned accessors, not another service.
func set_section(section: StringName, values: Dictionary) -> Error:
	assert(_loaded)
	if section not in [&"progress", &"economy", &"daily", &"monetization"]:
		return ERR_INVALID_PARAMETER
	var candidate: Dictionary = _data.duplicate(true)
	candidate[str(section)] = values.duplicate(true)
	if not SaveSchema.is_valid(candidate):
		return ERR_INVALID_DATA
	_data = SaveSchema.canonical(candidate)
	_dirty = true
	return OK


## @api Read a closed settings key; invalid names return null.
func get_setting(key: StringName) -> Variant:
	assert(_loaded)
	return _data["settings"].get(str(key)) if key in SaveSchema.SETTINGS else null


## @api Persist a structurally valid setting immediately; signal only after successful flush.
## On I/O error the new value remains dirty for retry; caller receives the error.
func set_setting(key: StringName, value: Variant) -> Error:
	assert(_loaded)
	if key not in SaveSchema.SETTINGS:
		return ERR_INVALID_PARAMETER
	var candidate: Dictionary = _data.duplicate(true)
	candidate["settings"][str(key)] = value
	if not SaveSchema.is_valid(candidate):
		return ERR_INVALID_DATA
	_data = SaveSchema.canonical(candidate)
	_dirty = true
	var error: Error = flush()
	if error == OK:
		setting_changed.emit(key)
	return error


## @api Synchronous durable write; success is required before a caller finishes a transaction.
func flush() -> Error:
	if not _loaded:
		return ERR_UNCONFIGURED
	if not _dirty:
		return OK
	var error: Error = _storage.commit(JSON.stringify(_data, "", true, true), _primary_valid)
	if error == OK:
		_dirty = false
		_primary_valid = true
	else:
		flush_failed.emit(error)
	return error


## @api Flush at the meaningful event, without a deferred window or per-frame polling.
func request_flush() -> Error:
	return flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and _loaded:
		request_flush()
