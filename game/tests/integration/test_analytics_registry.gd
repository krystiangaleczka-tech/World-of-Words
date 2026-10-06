extends GutTest

const SERVICE_SCRIPT = preload("res://services/analytics.gd")
const DIRECTORY: String = "user://t0038-analytics-tests"
var _previous: AnalyticsAdapter
var _fake: AnalyticsFake


func before_each() -> void:
	_previous = Platform.analytics
	_fake = AnalyticsFake.new()
	Platform.analytics = _fake
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	_clean()


func after_each() -> void:
	Platform.analytics = _previous
	_clean()
	DirAccess.remove_absolute(DIRECTORY)


func _clean() -> void:
	var directory: DirAccess = DirAccess.open(DIRECTORY)
	if directory != null:
		for file: String in directory.get_files():
			DirAccess.remove_absolute(DIRECTORY.path_join(file))


func _service(capacity: int = 3) -> SERVICE_SCRIPT:
	var service: SERVICE_SCRIPT = SERVICE_SCRIPT.new()
	add_child_autofree(service)
	assert_eq(service.load(), OK)
	assert_eq(service.configure_stub(capacity), OK)
	return service


func _write(filename: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(DIRECTORY.path_join(filename), FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()


func test_canonical_seed_and_fifo_delivery_are_explicit() -> void:
	var service: SERVICE_SCRIPT = _service(4)
	for name: StringName in [&"app_boot", &"app_foreground", &"app_background"]:
		assert_eq(service.track(name), OK)
	assert_eq(service.track(&"nav_screen", {"screen": "Level"}), OK)
	assert_eq(_fake.calls.entries.size(), 0)
	assert_eq(service.pending_count(), 4)
	assert_eq(service.flush(), OK)
	assert_eq(service.pending_count(), 0)
	assert_eq(_fake.calls.entries.size(), 4)
	assert_eq(_fake.calls.entries[0]["arguments"], ["app_boot", {}])
	assert_eq(_fake.calls.entries[3]["arguments"], ["nav_screen", {"screen": "Level"}])
	assert_eq(service.flush(), OK)
	assert_eq(_fake.calls.entries.size(), 4)


func test_all_primitive_types_are_strict_and_safe() -> void:
	var registry: AnalyticsRegistry = AnalyticsRegistry.new()
	var definition: Dictionary = {
		"description": "Fixture",
		"params": {"integer": "int", "fraction": "float", "flag": "bool", "text": "string"}
	}
	assert_eq(registry.append_document({"fixture": definition}), OK)
	var payload: Dictionary = {"integer": 1, "fraction": 0.5, "flag": true, "text": "test"}
	assert_true(registry.validate(&"fixture", payload))
	for mutation: Dictionary in [
		{"integer": true},
		{"integer": 1.0},
		{"integer": 9007199254740992},
		{"fraction": 1},
		{"fraction": NAN},
		{"fraction": INF},
		{"flag": 1},
		{"text": []}
	]:
		var invalid: Dictionary = payload.duplicate(true)
		invalid.merge(mutation, true)
		assert_false(registry.validate(&"fixture", invalid))


func test_unknown_missing_extra_or_wrong_params_fail_loudly_without_queueing() -> void:
	var service: SERVICE_SCRIPT = _service()
	assert_eq(service.track(&"not_registered"), ERR_INVALID_DATA)
	assert_push_error("not_registered")
	for params: Dictionary in [{}, {"screen": 1}, {"screen": "Level", "extra": true}]:
		assert_eq(service.track(&"nav_screen", params), ERR_INVALID_DATA)
		assert_push_error("nav_screen")
	assert_push_error_count(4)
	assert_eq(service.pending_count(), 0)
	assert_eq(_fake.calls.entries.size(), 0)


func test_definition_validation_is_atomic_and_copies_metadata() -> void:
	var registry: AnalyticsRegistry = AnalyticsRegistry.new()
	var valid: Dictionary = {"description": "Fixture", "params": {"screen": "string"}}
	assert_eq(registry.append_document({"fixture": valid, "BadName": valid}), ERR_INVALID_DATA)
	assert_eq(registry.definition(&"fixture"), {})
	assert_eq(registry.append_document({"fixture": valid}), OK)
	assert_eq(registry.append_document({"fixture": valid}), ERR_INVALID_DATA)
	valid["params"]["screen"] = "int"
	var snapshot: Dictionary = registry.definition(&"fixture")
	snapshot["params"]["screen"] = "bool"
	assert_true(registry.validate(&"fixture", {"screen": "Level"}))
	for invalid: Variant in [
		{},
		{"params": {}, "description": " "},
		{"params": {"bad-param": "int"}, "description": "Fixture"},
		{"params": {"value": "array"}, "description": "Fixture"},
		{"params": [], "description": "Fixture"},
		{"params": {}, "description": 1},
		{"params": {}, "description": "Fixture", "extra": true},
		[]
	]:
		assert_eq(registry.append_document({"other": invalid}), ERR_INVALID_DATA)
	assert_eq(registry.append_document({}), ERR_INVALID_DATA)


func test_capacity_overflow_snapshot_and_reconfiguration_preserve_accepted_events() -> void:
	var service: SERVICE_SCRIPT = _service(1)
	var payload: Dictionary = {"screen": "Level"}
	assert_eq(service.track(&"nav_screen", payload), OK)
	payload["screen"] = "Home"
	assert_eq(service.track(&"app_boot"), ERR_OUT_OF_MEMORY)
	assert_eq(service.configure_stub(0), ERR_INVALID_PARAMETER)
	assert_eq(service.pending_count(), 1)
	assert_eq(service.flush(), OK)
	assert_eq(_fake.calls.entries[0]["arguments"], ["nav_screen", {"screen": "Level"}])
	assert_eq(service.configure_stub(2), OK)
	assert_eq(service.track(&"app_boot"), OK)
	assert_eq(service.track(&"app_background"), OK)
	assert_eq(service.configure_stub(1), ERR_INVALID_PARAMETER)
	assert_eq(service.pending_count(), 2)


func test_real_adapter_is_never_called_and_pending_data_survives() -> void:
	var service: SERVICE_SCRIPT = _service()
	assert_eq(service.track(&"app_boot"), OK)
	Platform.analytics = AnalyticsAdapter.new()
	assert_eq(service.flush(), ERR_UNAVAILABLE)
	assert_eq(service.pending_count(), 1)
	Platform.analytics = _fake
	assert_eq(service.flush(), OK)
	assert_eq(_fake.calls.entries.size(), 1)


func test_explicit_configuration_and_busy_reload() -> void:
	var service: SERVICE_SCRIPT = SERVICE_SCRIPT.new()
	add_child_autofree(service)
	assert_eq(service.load(), OK)
	assert_eq(service.track(&"app_boot"), ERR_UNCONFIGURED)
	assert_eq(service.flush(), OK)
	assert_eq(service.configure_stub(2), OK)
	assert_eq(service.track(&"app_boot"), OK)
	assert_eq(service.load(), ERR_BUSY)
	assert_eq(service.pending_count(), 1)
	assert_eq(service.flush(), OK)
	assert_eq(service.load(), OK)


func test_file_errors_leave_previous_registry_intact() -> void:
	var service: SERVICE_SCRIPT = _service()
	assert_eq(service.load(DIRECTORY + "/missing"), ERR_CANT_OPEN)
	assert_eq(service.load(DIRECTORY), ERR_FILE_NOT_FOUND)
	_write("README.txt", "ignore")
	assert_eq(service.load(DIRECTORY), ERR_FILE_NOT_FOUND)
	_write("fixture.json", "[]")
	assert_eq(service.load(DIRECTORY), ERR_PARSE_ERROR)
	_write("fixture.json", "{broken")
	assert_eq(service.load(DIRECTORY), ERR_PARSE_ERROR)
	_write("fixture.json", JSON.stringify({"fixture": {"params": {}, "description": "Fixture"}}))
	_write("zbad.json", JSON.stringify({"fixture": {"params": {}, "description": "Duplicate"}}))
	assert_eq(service.load(DIRECTORY), ERR_INVALID_DATA)
	assert_eq(service.track(&"app_boot"), OK)
	assert_eq(service.flush(), OK)
	DirAccess.remove_absolute(DIRECTORY.path_join("zbad.json"))
	assert_eq(service.load(DIRECTORY), OK)
	assert_eq(service.track(&"fixture"), OK)
