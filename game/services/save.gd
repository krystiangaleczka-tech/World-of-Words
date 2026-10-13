# gdlint: disable=max-public-methods
# Save retains its P1 APIs alongside the explicitly scoped typed transaction boundary.
extends ServiceStub
## @api Save v4 with lossless v3 compatibility; section ownership remains unchanged.

signal setting_changed(key: StringName)
signal backup_restored
signal flush_failed(error: Error)

var _atomic: AtomicSave = AtomicSave.new()
var _storage: SaveStorage = SaveStorage.new()
var _migrations: SaveMigrations = SaveMigrations.new()
var _id_factory: Callable = SaveSchema.new_install_id
var _data: Dictionary = {}
var _loaded: bool = false
var _compat_v3: bool = false
var _dirty: bool = false
var _primary_valid: bool = false
var _loaded_temp: bool = false
var _pending_settings: Dictionary[StringName, bool] = {}


## @api Inject isolated storage/identity generation before loading (tests/tools only).
func configure(storage: SaveStorage, id_factory: Callable = Callable()) -> void:
	assert(not _loaded and storage != null)
	_storage = storage
	_atomic.configure(_storage, _atomic_publish)
	if id_factory.is_valid():
		_id_factory = id_factory


## @api Load primary, temp, backup; migrate/validate before exposing any sections.
## A first install is persisted immediately. Corrupt originals remain until an explicit flush.
func load() -> Error:
	if _loaded:
		return OK
	_atomic.configure(_storage, _atomic_publish)
	assert(get_clock() != null, "Save requires an injected Clock before load")
	for suffix: String in ["", ".tmp", ".bak"]:
		var source: Dictionary = _storage.read_document(suffix)
		var candidate: Dictionary = _migrations.upgrade(source)
		if not SaveSchema.is_valid(candidate):
			var legacy: Dictionary = _legacy_candidate(source)
			if not legacy.is_empty():
				candidate = legacy
				_compat_v3 = true
		if _valid_document(candidate):
			_data = _canonical_document(candidate)
			_atomic.observe(_data)
			_loaded = true
			_primary_valid = suffix.is_empty()
			_loaded_temp = suffix == ".tmp"
			_dirty = not _primary_valid or source.get("schema_version") != _data["schema_version"]
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
	_atomic.observe(_data)
	_loaded = true
	_dirty = true
	if existing:
		Events.save_corrupted.emit()
		return OK
	return flush()


## @api Whether a valid save has been loaded, without triggering domain work.
func is_loaded() -> bool:
	return _loaded


## @api Version adaptation only; ready does not certify any P2/atomic commit capability.
func migration_state() -> String:
	if not _loaded:
		return "unconfigured"
	return "needs_migration" if _compat_v3 else "ready"


func _legacy_candidate(source: Dictionary) -> Dictionary:
	var legacy: Dictionary = source.duplicate(true)
	if legacy.get("schema_version") == 1:
		legacy = MigrateV1ToV2.migrate(legacy)
	if legacy.get("schema_version") == 2:
		legacy = MigrateV2ToV3.migrate(legacy)
	return legacy if SaveSchemaV3.is_valid(legacy) else {}


func _valid_document(data: Dictionary) -> bool:
	return SaveSchemaV3.is_valid(data) if _compat_v3 else SaveSchema.is_valid(data)


func _canonical_document(data: Dictionary) -> Dictionary:
	return SaveSchemaV3.canonical(data) if _compat_v3 else SaveSchema.canonical(data)


func _fresh_document(install_id: String, created_at: String, app_version: String) -> Dictionary:
	return (
		SaveSchemaV3.fresh(install_id, created_at, app_version)
		if _compat_v3
		else SaveSchema.fresh(install_id, created_at, app_version)
	)


## @api Explicit debug reset of gameplay only; identity, settings and purchases are preserved.
## Persist before publishing new memory. Existing storage recovery semantics apply on failure.
func debug_reset() -> Error:
	if writes_blocked():
		return ERR_BUSY
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	if not _loaded:
		return ERR_UNCONFIGURED
	var meta: Dictionary = _data["meta"]
	var candidate: Dictionary = _fresh_document(
		str(meta["install_id"]), str(meta["created_at"]), str(meta["app_version"])
	)
	for section: String in ["meta", "settings", "monetization"]:
		candidate[section] = (_data[section] as Dictionary).duplicate(true)
	if not _compat_v3 and not _reset_atomic(candidate):
		return ERR_INVALID_DATA
	var error: Error = _prepare_write()
	if error == OK:
		error = _storage.commit(JSON.stringify(candidate, "", true, true), _primary_valid)
	if error != OK:
		flush_failed.emit(error)
		return error
	_data = _canonical_document(candidate)
	_atomic.observe(_data)
	_dirty = false
	_primary_valid = true
	_publish_settings()
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
	if writes_blocked():
		return ERR_BUSY
	assert(_loaded)
	if section not in [&"progress", &"economy", &"daily", &"monetization"]:
		return ERR_INVALID_PARAMETER
	var candidate: Dictionary = _data.duplicate(true)
	candidate[str(section)] = values.duplicate(true)
	if not _valid_document(candidate):
		return ERR_INVALID_DATA
	_data = _canonical_document(candidate)
	_dirty = true
	return OK


## @api Read a closed settings key; invalid names return null.
func get_setting(key: StringName) -> Variant:
	assert(_loaded)
	return _data["settings"].get(str(key)) if key in SaveSchema.SETTINGS else null


## @api Persist a structurally valid setting immediately; signal only after successful flush.
## On I/O error the value stays dirty; any successful retry publishes pending keys.
func set_setting(key: StringName, value: Variant) -> Error:
	if writes_blocked():
		return ERR_BUSY
	assert(_loaded)
	if key not in SaveSchema.SETTINGS:
		return ERR_INVALID_PARAMETER
	var candidate: Dictionary = _data.duplicate(true)
	candidate["settings"][str(key)] = value
	if not _valid_document(candidate):
		return ERR_INVALID_DATA
	_data = _canonical_document(candidate)
	_dirty = true
	_pending_settings[key] = true
	return flush()


## @api Synchronous durable write; success is required before a caller finishes a transaction.
func flush() -> Error:
	if writes_blocked():
		return ERR_BUSY
	if not _loaded:
		return ERR_UNCONFIGURED
	if not _dirty:
		return OK
	var candidate: Dictionary = _data.duplicate(true)
	if not _compat_v3 and not _bump_revision(candidate):
		return ERR_INVALID_DATA
	var error: Error = _prepare_write()
	if error == OK:
		error = _storage.commit(JSON.stringify(candidate, "", true, true), _primary_valid)
	if error == OK:
		_data = _canonical_document(candidate)
		_atomic.observe(_data)
		_dirty = false
		_primary_valid = true
		_publish_settings()
	else:
		flush_failed.emit(error)
	return error


func _publish_settings() -> void:
	var keys: Array[StringName] = []
	keys.assign(_pending_settings.keys())
	_pending_settings.clear()
	for key: StringName in keys:
		setting_changed.emit(key)


func _prepare_write() -> Error:
	if not _loaded_temp:
		return OK
	var error: Error = _storage.promote_temp()
	if error == OK:
		_loaded_temp = false
		_primary_valid = true
	return error


## @api Flush at the meaningful event, without a deferred window or per-frame polling.
func request_flush() -> Error:
	return flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and _loaded:
		request_flush()


## @api Durable copied sections, independent of P1's dirty staging document.
func committed_view() -> Dictionary:
	return _atomic.view()


## @api Boot-only binding; typed base plus concrete script ancestry prevents circular preloads.
func configure_atomic(progress: AtomicSaveOwner, economy: AtomicSaveOwner) -> Error:
	return ERR_ALREADY_IN_USE if _loaded else _atomic.bind(progress, economy)


## @api Shared lease/notification barrier for every owner writer.
func writes_blocked() -> bool:
	return _atomic.blocked()


func validates_transaction(transaction: SaveTransaction) -> bool:
	return _atomic.validates(transaction)


func validates_progress(value: ProgressPrepared, transaction: SaveTransaction) -> bool:
	return _atomic.validates_progress(value, transaction)


func validates_receipt(receipt: Dictionary) -> bool:
	return _atomic.validates_receipt(receipt)


func begin_transaction(request: Dictionary) -> Dictionary:
	return _atomic.begin(request, _dirty)


func commit_transaction(
	transaction: SaveTransaction, progress: ProgressPrepared, economy: EconomyPrepared
) -> Dictionary:
	return _atomic.commit(transaction, progress, economy)


func recover_transaction(operation_id: String, request_hash: String) -> Dictionary:
	if _dirty and not writes_blocked():
		return {"error": ERR_BUSY, "state": "pending", "view": committed_view(), "receipt": {}}
	return _atomic.recover(operation_id, request_hash)


func abort_transaction(transaction: SaveTransaction) -> Error:
	return _atomic.abort(transaction)


func _atomic_publish(document: Dictionary, suffix: String) -> void:
	_compat_v3 = document.schema_version == 3
	_data = _canonical_document(document)
	_primary_valid = suffix.is_empty()
	_loaded_temp = suffix == ".tmp"
	_dirty = not _primary_valid


func _bump_revision(candidate: Dictionary) -> bool:
	var prior: int = int(committed_view().revision)
	if prior >= ProgressSnapshot.MAX_SAFE_COUNT:
		return false
	candidate.meta.atomic.revision = prior + 1
	return SaveSchema.is_valid(candidate)


func _reset_atomic(candidate: Dictionary) -> bool:
	var atomic: Dictionary = candidate.meta.atomic
	if atomic.lineage >= ProgressSnapshot.MAX_SAFE_COUNT or not _bump_revision(candidate):
		return false
	atomic.lineage += 1
	atomic.processed = {}
	return SaveSchema.is_valid(candidate)
