extends ServiceStub
## @api Registry validation and an explicitly configured, in-memory FIFO stub for Fakes only.
## Production consent, durable queue, common params and collection are implemented in T-0250.

var _registry: AnalyticsRegistry = AnalyticsRegistry.new()
var _pending: Array[Dictionary] = []
var _capacity: int = 0


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
## No default duplicates the future analytics.queue.max_events config; callers choose explicitly.
func configure_stub(capacity: int) -> Error:
	if capacity < 1 or capacity < _pending.size():
		return ERR_INVALID_PARAMETER
	_capacity = capacity
	return OK


## @api Validate and snapshot a registered event. Debug misuse emits push_error and is rejected.
## Full queue rejects the new event; already accepted events stay in FIFO order.
func track(name: StringName, params: Dictionary = {}) -> Error:
	if not _registry.validate(name, params):
		if OS.is_debug_build():
			push_error("Analytics event '%s' is unknown or has invalid parameters" % name)
		return ERR_INVALID_DATA
	if _capacity == 0:
		return ERR_UNCONFIGURED
	if _pending.size() >= _capacity:
		return ERR_OUT_OF_MEMORY
	_pending.append({"name": str(name), "params": params.duplicate(true)})
	return OK


## @api Drain FIFO into Platform's Fake only; a real adapter leaves pending data untouched.
## No SDK initialization, persistence, consent decision or user-property calls occur here.
func flush() -> Error:
	if _pending.is_empty():
		return OK
	var fake: AnalyticsFake = Platform.analytics as AnalyticsFake
	if fake == null:
		return ERR_UNAVAILABLE
	var delivery: Array[Dictionary] = _pending
	_pending = []
	for event: Dictionary in delivery:
		fake.log_event(event["name"], event["params"])
	return OK


## @api Pending count for assertions/debugging; payload storage is never exposed.
func pending_count() -> int:
	return _pending.size()
