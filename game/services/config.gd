extends ServiceStub
## @api Validated local defaults with nonblocking remote overrides and an offline last-valid cache.

const ANALYTICS_SCRIPT: Script = preload("res://services/analytics.gd")
const CACHE_PATH: String = "user://config_cache.json"

var _registry: ConfigRegistry = ConfigRegistry.new()
var _overrides: Dictionary = {}
var _cache: SaveStorage = null
var _analytics: ANALYTICS_SCRIPT = null
var _install_id: String = ""
var _remote_started: bool = false
var _request: HTTPRequest = null


## @api Load sorted prefix JSON files atomically. Any invalid file keeps the prior registry.
func load(directory: String = "res://data/config") -> Error:
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null:
		return ERR_CANT_OPEN
	var files: PackedStringArray = folder.get_files()
	files.sort()
	var candidate: ConfigRegistry = ConfigRegistry.new()
	var count: int = 0
	for filename: String in files:
		if filename.get_extension() != "json":
			continue
		var file: FileAccess = FileAccess.open(directory.path_join(filename), FileAccess.READ)
		if file == null:
			return FileAccess.get_open_error()
		var parser: JSON = JSON.new()
		var error: Error = parser.parse(file.get_as_text())
		file.close()
		if error != OK or not parser.data is Dictionary:
			return ERR_PARSE_ERROR
		error = candidate.append_document(filename.get_basename(), parser.data as Dictionary)
		if error != OK:
			return error
		count += 1
	if count == 0:
		return ERR_FILE_NOT_FOUND
	if _request != null:
		_request.cancel_request()
		_request.queue_free()
		_request = null
	_registry = candidate
	_overrides.clear()
	_remote_started = false
	_analytics = null
	_cache = null
	_install_id = ""
	return OK


## @api Restore cached configuration immediately, then fetch HTTPS asynchronously when given a URL.
## An empty URL means cache/defaults only until T-0257 supplies a hosted endpoint.
## Bad network responses never block boot and never replace the last valid configuration.
func start_remote(
	install_id: String,
	analytics: ANALYTICS_SCRIPT,
	endpoint: String = "",
	cache_path: String = CACHE_PATH
) -> Error:
	if _remote_started:
		return ERR_ALREADY_IN_USE
	if (
		install_id.is_empty()
		or not is_instance_valid(analytics)
		or not _registry.has_key(&"config.remote.timeout_ms")
		or cache_path.is_empty()
	):
		return ERR_UNCONFIGURED
	if not endpoint.is_empty() and not endpoint.begins_with("https://"):
		return ERR_INVALID_PARAMETER
	_install_id = install_id
	_analytics = analytics
	_cache = SaveStorage.new(cache_path)
	_remote_started = true
	_restore_cache()
	if endpoint.is_empty():
		return OK
	_request = HTTPRequest.new()
	_request.timeout = float(get_int(&"config.remote.timeout_ms")) / 1000.0
	add_child(_request)
	_request.request_completed.connect(_on_remote_finished)
	var error: Error = _request.request(endpoint)
	if error != OK:
		push_warning("Remote config request could not start: %s" % error)
	return OK


## @api Validate and cache downloads atomically, without discarding earlier valid values.
## This method also permits deterministic integration tests without external HTTP.
func accept_remote_document(document: Dictionary) -> Error:
	if not _remote_started:
		return ERR_UNCONFIGURED
	var checked: Dictionary = RemoteConfigContract.validate(document, _registry, _install_id)
	if checked.is_empty():
		return ERR_INVALID_DATA
	var error: Error = _cache.commit(
		JSON.stringify(document, "", true, true), FileAccess.file_exists(_cache.path)
	)
	if error != OK:
		push_warning("Remote config cache write failed: %s" % error)
	_activate(checked)
	_analytics.track(
		&"remote_config_applied", {"config_version": str(RemoteConfigContract.VERSION)}
	)
	return error


## @api Test for a registered key without emitting errors.
func has_key(key: StringName) -> bool:
	return _registry.has_key(key)


## @api Read an int default or validated remote override.
func get_int(key: StringName) -> int:
	var fallback: int = int(_registry.read_value(key, &"int", 0))
	return int(_overrides.get(str(key), fallback))


## @api Read a float default or validated remote override.
func get_float(key: StringName) -> float:
	var fallback: float = float(_registry.read_value(key, &"float", 0.0))
	return float(_overrides.get(str(key), fallback))


## @api Read a bool default or validated remote override.
func get_bool(key: StringName) -> bool:
	var fallback: bool = bool(_registry.read_value(key, &"bool", false))
	return bool(_overrides.get(str(key), fallback))


## @api Read a string default or validated remote override.
func get_string(key: StringName) -> String:
	var fallback: String = str(_registry.read_value(key, &"string", ""))
	return str(_overrides.get(str(key), fallback))


func _restore_cache() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var document: Dictionary = _cache.read_document(suffix)
		var normalized: Dictionary = _normalize_json_numbers(document)
		var checked: Dictionary = RemoteConfigContract.validate(
			normalized, _registry, _install_id
		)
		if not checked.is_empty():
			_activate(checked)
			return


func _on_remote_finished(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var parser: JSON = JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return
	accept_remote_document(_normalize_json_numbers(parser.data as Dictionary))


## Godot's JSON parser may materialize integer tokens as integral floats.
## Restore those numbers only at contract-declared integer fields, never arbitrary keys.
func _normalize_json_numbers(document: Dictionary) -> Dictionary:
	var result: Dictionary = document.duplicate(true)
	if result.get("version") is float and _integral(result["version"]):
		result["version"] = int(result["version"])
	var values: Variant = result.get("values")
	if values is Dictionary:
		for raw_key: Variant in values:
			if not raw_key is String:
				continue
			var key: StringName = StringName(raw_key)
			var definition: Dictionary = _registry.definition(key)
			if definition.get("type") == "int" and _integral(values[raw_key]):
				values[raw_key] = int(values[raw_key])
	var experiments: Variant = result.get("experiments")
	if experiments is Array:
		for raw_experiment: Variant in experiments:
			if not raw_experiment is Dictionary:
				continue
			var variants: Variant = raw_experiment.get("variants")
			if not variants is Array:
				continue
			for raw_variant: Variant in variants:
				if raw_variant is Dictionary and _integral(raw_variant.get("weight")):
					raw_variant["weight"] = int(raw_variant["weight"])
	return result


func _integral(value: Variant) -> bool:
	if not value is float:
		return false
	var number: float = float(value)
	return (
		is_finite(number)
		and abs(number) <= 9007199254740991.0
		and number == floor(number)
	)


func _activate(checked: Dictionary) -> void:
	_overrides = (checked["overrides"] as Dictionary).duplicate(true)
	for key: String in checked["unknown"]:
		push_warning("Unknown remote config key: %s" % key)
	for key: String in checked["rejected"]:
		push_warning("Rejected remote config key: %s" % key)
	if _analytics.set_experiment_buckets(checked["buckets"], true) != OK:
		return
	var buckets: Dictionary = checked["buckets"]
	for experiment_id: String in buckets:
		_analytics.track(
			&"experiment_assigned", {"experiment_id": experiment_id, "bucket": buckets[experiment_id]}
		)
