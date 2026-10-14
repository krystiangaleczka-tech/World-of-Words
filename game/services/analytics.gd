extends ServiceStub
## @api Registry validation plus explicit stub or durable consent-gated runtime delivery.

enum Mode { NONE, STUB, RUNTIME }
enum ConsentState { UNKNOWN, ALLOWED, DENIED }

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const QUEUE_KEY: StringName = &"analytics.queue.max_events"
const COMMON_KEYS: Array[String] = [
	"install_id", "app_version", "content_version", "language", "experiment_buckets"
]

var _registry: AnalyticsRegistry = AnalyticsRegistry.new()
var _pending: Array[Dictionary] = []
var _capacity: int = 0
var _mode: Mode = Mode.NONE
var _consent: ConsentState = ConsentState.UNKNOWN
var _save: SAVE_SCRIPT = null
var _config: CONFIG_SCRIPT = null
var _content: CONTENT_SCRIPT = null
var _event_bus: EVENTS_SCRIPT = null
var _queue: AnalyticsQueue = null
var _buckets: Dictionary = {}


## @api Load sorted area JSON files atomically; reject reload while events are queued.
func load(directory: String = "res://data/analytics") -> Error:
	if not _pending.is_empty():
		return ERR_BUSY
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null:
		return ERR_CANT_OPEN
	var files: PackedStringArray = folder.get_files()
	files.sort()
	var candidate: AnalyticsRegistry = AnalyticsRegistry.new()
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
		error = candidate.append_document(parser.data as Dictionary)
		if error != OK:
			return error
		count += 1
	if count > 0:
		_registry = candidate
	return OK if count > 0 else ERR_FILE_NOT_FOUND


## @api Set a positive test/development queue capacity without discarding pending events.
## This preserves the pre-T-0250 in-memory Fake-only contract.
func configure_stub(capacity: int) -> Error:
	if _mode == Mode.RUNTIME:
		return ERR_ALREADY_IN_USE
	if capacity < 1 or capacity < _pending.size():
		return ERR_INVALID_PARAMETER
	_capacity = capacity
	_mode = Mode.STUB
	return OK


## @api Bind loaded boot services and restore the durable analytics FIFO.
## Rebinding the same event bus updates service references without resetting consent.
# gdlint: disable=max-returns
func start_runtime(
	save: SAVE_SCRIPT,
	config: CONFIG_SCRIPT,
	content: CONTENT_SCRIPT,
	event_bus: EVENTS_SCRIPT = null,
	queue: AnalyticsQueue = null
) -> Error:
	if _mode == Mode.STUB:
		return ERR_ALREADY_IN_USE
	var selected_bus: EVENTS_SCRIPT = event_bus if event_bus != null else Events
	if not _runtime_dependencies_valid(save, config, content) or selected_bus == null:
		return ERR_UNCONFIGURED
	if _mode == Mode.RUNTIME:
		if selected_bus != _event_bus:
			return ERR_ALREADY_IN_USE
		_save = save
		_config = config
		_content = content
		_capacity = config.get_int(QUEUE_KEY)
		return OK
	var error: Error = self.load()
	if error != OK:
		return error
	var selected_queue: AnalyticsQueue = queue if queue != null else AnalyticsQueue.new()
	var capacity: int = config.get_int(QUEUE_KEY)
	var restored: Dictionary = selected_queue.restore(capacity, _stored_event_valid)
	error = restored["error"]
	if error != OK:
		return error
	var events: Array[Dictionary] = []
	events.assign(restored["events"])
	_save = save
	_config = config
	_content = content
	_event_bus = selected_bus
	_queue = selected_queue
	_capacity = capacity
	_pending = events
	_consent = ConsentState.UNKNOWN
	_mode = Mode.RUNTIME
	_event_bus.consent_changed.connect(_on_consent_changed)
	return OK


## @api Replace bucket context for subsequently accepted events.
func set_experiment_buckets(buckets: Dictionary) -> Error:
	if not _buckets_valid(buckets):
		return ERR_INVALID_PARAMETER
	_buckets = buckets.duplicate(true)
	return OK


## @api Whether durable runtime setup completed successfully.
func runtime_ready() -> bool:
	return _mode == Mode.RUNTIME


## @api Validate and snapshot a registered event. Debug misuse emits push_error and is rejected.
## Full queue rejects the new event; already accepted events stay in FIFO order.
# gdlint: disable=max-returns
func track(name: StringName, params: Dictionary = {}) -> Error:
	if not _registry.validate(name, params):
		if OS.is_debug_build():
			push_error("Analytics event '%s' is unknown or has invalid parameters" % name)
		return ERR_INVALID_DATA
	if _mode == Mode.NONE:
		return ERR_UNCONFIGURED
	if _mode == Mode.STUB:
		return _track_stub(name, params)
	if _consent == ConsentState.DENIED:
		return OK
	if _pending.size() >= _capacity:
		return ERR_OUT_OF_MEMORY
	var entry: Dictionary = _runtime_entry(name, params)
	if entry.is_empty():
		return ERR_INVALID_DATA
	var candidate: Array[Dictionary] = _pending.duplicate(true)
	candidate.append(entry)
	var error: Error = _queue.replace(candidate)
	if error != OK:
		return error
	_pending = candidate
	return flush() if _consent == ConsentState.ALLOWED else OK


## @api Drain FIFO. Stub mode targets Fakes only; runtime waits for consent and persists removals.
# gdlint: disable=max-returns
func flush() -> Error:
	if _pending.is_empty():
		return OK
	if _mode == Mode.STUB:
		var fake: AnalyticsFake = Platform.analytics as AnalyticsFake
		if fake == null:
			return ERR_UNAVAILABLE
		var delivery: Array[Dictionary] = _pending
		_pending = []
		for event: Dictionary in delivery:
			fake.log_event(event["name"], event["params"])
		return OK
	if _mode != Mode.RUNTIME or _consent == ConsentState.UNKNOWN:
		return OK
	if _consent == ConsentState.DENIED:
		return _drop_pending()
	while not _pending.is_empty():
		var event: Dictionary = _pending[0]
		Platform.analytics.log_event(event["name"], _delivery_params(event))
		var remaining: Array[Dictionary] = _pending.duplicate(true)
		remaining.remove_at(0)
		var error: Error = _queue.replace(remaining)
		if error != OK:
			return error
		_pending = remaining
	return OK


## @api Pending count for assertions/debugging; payload storage is never exposed.
func pending_count() -> int:
	return _pending.size()


func _track_stub(name: StringName, params: Dictionary) -> Error:
	if _capacity == 0:
		return ERR_UNCONFIGURED
	if _pending.size() >= _capacity:
		return ERR_OUT_OF_MEMORY
	_pending.append({"name": str(name), "params": params.duplicate(true)})
	return OK


func _runtime_dependencies_valid(
	save: SAVE_SCRIPT, config: CONFIG_SCRIPT, content: CONTENT_SCRIPT
) -> bool:
	return (
		is_instance_valid(save)
		and save.is_loaded()
		and is_instance_valid(config)
		and config.has_key(QUEUE_KEY)
		and config.get_int(QUEUE_KEY) > 0
		and is_instance_valid(content)
		and content.is_loaded()
		and str(save.get_setting(&"language")) == content.get_language()
	)


func _runtime_entry(name: StringName, params: Dictionary) -> Dictionary:
	var context: Dictionary = {
		"install_id": str(_save.get_section(&"meta").get("install_id", "")),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"content_version": _content.content_version(),
		"language": _content.get_language(),
		"experiment_buckets": JSON.stringify(_buckets, "", true, true),
	}
	if not _context_valid(context):
		return {}
	for key: String in COMMON_KEYS:
		if params.has(key) and params[key] != context[key]:
			return {}
	return {"name": str(name), "event_params": params.duplicate(true), "context": context}


func _stored_event_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var event: Dictionary = value
	if (
		event.size() != 3
		or not event.get("name") is String
		or not event.get("event_params") is Dictionary
		or not event.get("context") is Dictionary
	):
		return false
	var name: StringName = StringName(event["name"])
	var params: Dictionary = event["event_params"]
	var context: Dictionary = event["context"]
	if not _normalize_stored_numbers(name, params, context):
		return false
	if not _registry.validate(name, params) or not _context_valid(context):
		return false
	for key: String in COMMON_KEYS:
		if params.has(key) and params[key] != context[key]:
			return false
	return true


func _context_valid(context: Dictionary) -> bool:
	if context.size() != COMMON_KEYS.size():
		return false
	for key: String in COMMON_KEYS:
		if not context.has(key):
			return false
	if (
		not context["install_id"] is String
		or (context["install_id"] as String).is_empty()
		or not context["app_version"] is String
		or (context["app_version"] as String).is_empty()
		or not context["content_version"] is int
		or int(context["content_version"]) < 1
		or not context["language"] is String
		or (context["language"] as String).is_empty()
		or not context["experiment_buckets"] is String
	):
		return false
	var parsed: Variant = JSON.parse_string(context["experiment_buckets"])
	if not parsed is Dictionary or not _buckets_valid(parsed as Dictionary, true):
		return false
	var normalized: Dictionary = {}
	for key: Variant in parsed:
		normalized[key] = int(parsed[key])
	return context["experiment_buckets"] == JSON.stringify(normalized, "", true, true)


func _buckets_valid(buckets: Dictionary, json_numbers: bool = false) -> bool:
	var pattern: RegEx = RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]{0,39}$")
	for raw_key: Variant in buckets:
		if not raw_key is String or pattern.search(raw_key) == null:
			return false
		var value: Variant = buckets[raw_key]
		if value is int and value >= 0 and value <= 99:
			continue
		if (
			not json_numbers
			or not value is float
			or not is_finite(value)
			or value != floorf(value)
			or value < 0.0
			or value > 99.0
		):
			return false
	return true


func _normalize_stored_numbers(name: StringName, params: Dictionary, context: Dictionary) -> bool:
	var definition: Dictionary = _registry.definition(name)
	if definition.is_empty() or not definition.get("params") is Dictionary:
		return false
	var expected: Dictionary = definition["params"]
	for key: Variant in params:
		if not key is String or not expected.has(key):
			return false
		var value: Variant = params[key]
		if expected[key] == "int" and value is float:
			if not is_finite(value) or value != floorf(value) or abs(value) > 9007199254740991.0:
				return false
			params[key] = int(value)
		elif expected[key] == "float" and value is int:
			params[key] = float(value)
	var version: Variant = context.get("content_version")
	if version is float:
		if not is_finite(version) or version != floorf(version):
			return false
		context["content_version"] = int(version)
	return true


func _delivery_params(event: Dictionary) -> Dictionary:
	var params: Dictionary = (event["event_params"] as Dictionary).duplicate(true)
	params.merge(event["context"] as Dictionary, true)
	return params


func _on_consent_changed(analytics_allowed: bool) -> void:
	_consent = ConsentState.ALLOWED if analytics_allowed else ConsentState.DENIED
	if analytics_allowed:
		flush()
	else:
		_drop_pending()


func _drop_pending() -> Error:
	var error: Error = _queue.clear()
	# Privacy state wins in memory even if storage reports a failure.
	_pending = []
	return error


func _exit_tree() -> void:
	if (
		is_instance_valid(_event_bus)
		and _event_bus.consent_changed.is_connected(_on_consent_changed)
	):
		_event_bus.consent_changed.disconnect(_on_consent_changed)
