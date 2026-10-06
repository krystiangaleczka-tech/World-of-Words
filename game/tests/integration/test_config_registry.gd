extends GutTest

const CONFIG_SCRIPT = preload("res://services/config.gd")
const DIRECTORY: String = "user://t0037-config-tests"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	_clean_files()


func after_each() -> void:
	_clean_files()
	DirAccess.remove_absolute(DIRECTORY)


func _clean_files() -> void:
	var directory: DirAccess = DirAccess.open(DIRECTORY)
	if directory != null:
		for filename: String in directory.get_files():
			DirAccess.remove_absolute(DIRECTORY.path_join(filename))


func _service() -> CONFIG_SCRIPT:
	var service: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	add_child_autofree(service)
	return service


func _entry(value: Variant, type_name: String, bounds: Variant = null) -> Dictionary:
	return {
		"default": value,
		"type": type_name,
		"range": bounds,
		"description": "Test entry",
		"owner": "Sol",
		"remote": false
	}


func _write(filename: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(DIRECTORY.path_join(filename), FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()


func test_shipped_defaults_match_canonical_documented_values() -> void:
	var service: CONFIG_SCRIPT = _service()
	assert_eq(service.load(), OK)
	var expected: Dictionary = {
		"unlocks.shuffle_slot": 2,
		"unlocks.bonus_meter_slot": 5,
		"unlocks.hint_slot": 7,
		"unlocks.journey_slot": 10,
		"unlocks.reveal_slot": 12,
		"unlocks.double_reward_slot": 12,
		"unlocks.daily_slot": 15,
		"hint.offer_idle_seconds": 45,
		"hint.offer_invalid_streak": 5
	}
	for key: String in expected:
		assert_true(service.has_key(StringName(key)))
		assert_eq(service.get_int(StringName(key)), expected[key])
		assert_typeof(service.get_int(StringName(key)), TYPE_INT)


func test_all_four_types_survive_json_loading_without_coercion() -> void:
	_write(
		"fixture.json",
		JSON.stringify(
			{
				"fixture.integer": _entry(2, "int", [1, 3]),
				"fixture.float": _entry(0.5, "float", [0.0, 1.0]),
				"fixture.bool": _entry(true, "bool"),
				"fixture.string": _entry("test", "string")
			}
		)
	)
	var service: CONFIG_SCRIPT = _service()
	assert_eq(service.load(DIRECTORY), OK)
	assert_eq(service.get_int(&"fixture.integer"), 2)
	assert_eq(service.get_float(&"fixture.float"), 0.5)
	assert_true(service.get_bool(&"fixture.bool"))
	assert_eq(service.get_string(&"fixture.string"), "test")
	assert_typeof(service.get_int(&"fixture.integer"), TYPE_INT)
	assert_typeof(service.get_float(&"fixture.float"), TYPE_FLOAT)


func test_invalid_reads_fail_loudly_in_debug() -> void:
	var service: CONFIG_SCRIPT = _service()
	assert_eq(service.load(), OK)
	assert_false(service.has_key(&"unregistered"))
	assert_eq(service.get_int(&"unregistered"), 0)
	assert_push_error("unregistered")
	assert_eq(service.get_float(&"unlocks.hint_slot"), 0.0)
	assert_push_error("unlocks.hint_slot")
	assert_eq(service.get_string(&"hint.offer_idle_seconds"), "")
	assert_push_error("hint.offer_idle_seconds")
	assert_false(service.get_bool(&"unlocks.shuffle_slot"))
	assert_push_error("unlocks.shuffle_slot")
	assert_push_error_count(4)


func test_inclusive_range_boundaries_and_integer_validation() -> void:
	var registry: ConfigRegistry = ConfigRegistry.new()
	assert_eq(
		registry.append_document(
			"fixture",
			{"fixture.min": _entry(1, "int", [1, 3]), "fixture.max": _entry(3, "int", [1, 3])}
		),
		OK
	)
	for value: Variant in [0, 4, 1.5, true, "2", NAN, INF, 9007199254740992]:
		assert_eq(
			registry.append_document("invalid", {"invalid.value": _entry(value, "int", [1, 3])}),
			ERR_INVALID_DATA
		)
		assert_false(registry.has_key(&"invalid.value"))
	for bounds: Variant in [[3, 1], [1], [1, 2, 3], [1, "3"], [1, 2.5], null]:
		assert_eq(
			registry.append_document("invalid", {"invalid.value": _entry(2, "int", bounds)}),
			ERR_INVALID_DATA
		)


func test_metadata_schema_prefix_remote_and_duplicate_validation() -> void:
	var registry: ConfigRegistry = ConfigRegistry.new()
	var valid: Dictionary = _entry(2, "int", [1, 3])
	assert_eq(registry.append_document("fixture", {"fixture.value": valid}), OK)
	assert_eq(registry.append_document("fixture", {"fixture.value": valid}), ERR_INVALID_DATA)
	assert_eq(registry.append_document("wrong", {"fixture.other": valid}), ERR_INVALID_DATA)
	assert_eq(
		registry.append_document("fixture.alias", {"fixture.alias.key": valid}), ERR_INVALID_DATA
	)
	assert_eq(registry.append_document("fixture", {}), ERR_INVALID_DATA)
	assert_eq(registry.append_document("fixture", {"fixture.Bad": valid}), ERR_INVALID_DATA)
	for field: String in ["default", "type", "range", "description", "owner", "remote"]:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(field)
		assert_eq(registry.append_document("invalid", {"invalid.value": missing}), ERR_INVALID_DATA)
	for mutation: Dictionary in [
		{"type": "array"},
		{"remote": "false"},
		{"description": " "},
		{"owner": ""},
		{"extra": true},
		{"default": []}
	]:
		var invalid: Dictionary = valid.duplicate(true)
		invalid.merge(mutation, true)
		assert_eq(registry.append_document("invalid", {"invalid.value": invalid}), ERR_INVALID_DATA)
	var forbidden: Dictionary = valid.duplicate(true)
	forbidden["remote"] = true
	assert_eq(
		registry.append_document("unlocks", {"unlocks.hint_slot": forbidden}), ERR_INVALID_DATA
	)
	assert_eq(
		registry.append_document("consent", {"consent.ump_after_slot": forbidden}), ERR_INVALID_DATA
	)


func test_document_append_is_atomic_and_metadata_is_a_copy() -> void:
	var registry: ConfigRegistry = ConfigRegistry.new()
	var document: Dictionary = {
		"fixture.valid": _entry(1, "int", [1, 3]), "fixture.invalid": _entry(4, "int", [1, 3])
	}
	assert_eq(registry.append_document("fixture", document), ERR_INVALID_DATA)
	assert_false(registry.has_key(&"fixture.valid"))
	document.erase("fixture.invalid")
	assert_eq(registry.append_document("fixture", document), OK)
	document["fixture.valid"]["default"] = 3
	var metadata: Dictionary = registry.definition(&"fixture.valid")
	metadata["range"][0] = -10
	assert_eq(registry.definition(&"fixture.valid")["range"], [1, 3])
	assert_eq(registry.read_value(&"fixture.valid", &"int", 0), 1)


func test_failed_load_keeps_prior_registry_and_never_publishes_partial_files() -> void:
	var service: CONFIG_SCRIPT = _service()
	assert_eq(service.load(), OK)
	_write("fixture.json", JSON.stringify({"fixture.value": _entry(2, "int", [1, 3])}))
	_write("zbad.json", "{broken")
	assert_eq(service.load(DIRECTORY), ERR_PARSE_ERROR)
	assert_eq(service.get_int(&"unlocks.hint_slot"), 7)
	assert_false(service.has_key(&"fixture.value"))
	_write("zbad.json", JSON.stringify({"zbad.invalid": _entry(9, "int", [1, 3])}))
	assert_eq(service.load(DIRECTORY), ERR_INVALID_DATA)
	assert_false(service.has_key(&"fixture.value"))
	DirAccess.remove_absolute(DIRECTORY.path_join("zbad.json"))
	assert_eq(service.load(DIRECTORY), OK)
	assert_eq(service.get_int(&"fixture.value"), 2)
	assert_false(service.has_key(&"unlocks.hint_slot"))


func test_empty_missing_directory_and_non_object_json_errors() -> void:
	var service: CONFIG_SCRIPT = _service()
	assert_false(service.has_key(&"unlocks.hint_slot"))
	assert_eq(service.load(DIRECTORY + "/missing"), ERR_CANT_OPEN)
	assert_eq(service.load(DIRECTORY), ERR_FILE_NOT_FOUND)
	_write("README.txt", "ignored")
	assert_eq(service.load(DIRECTORY), ERR_FILE_NOT_FOUND)
	_write("fixture.json", "[]")
	assert_eq(service.load(DIRECTORY), ERR_PARSE_ERROR)
