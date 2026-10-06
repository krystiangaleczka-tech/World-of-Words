extends GutTest

const PREFIXES: PackedStringArray = ["hint", "unlocks"]


func _document(prefix: String) -> Dictionary:
	var source: String = "res://data/config/" + prefix + ".json"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
	assert_typeof(data, TYPE_DICTIONARY, source)
	return data if data is Dictionary else {}


func _mutated(document: Dictionary, key: String, fields: Dictionary) -> Dictionary:
	var copy: Dictionary = document.duplicate(true)
	var entry: Dictionary = copy[key]
	entry.merge(fields, true)
	return copy


func _assert_rejected(prefix: String, document: Dictionary) -> void:
	var registry: ConfigRegistry = ConfigRegistry.new()
	var other_prefix: String = "unlocks" if prefix == "hint" else "hint"
	var previous: Dictionary = _document(other_prefix)
	assert_eq(registry.append_document(other_prefix, previous), OK)
	assert_eq(registry.append_document(prefix, document), ERR_INVALID_DATA)
	for key: String in document:
		assert_false(registry.has_key(StringName(key)), "no partial entry: " + key)
	for key: String in previous:
		assert_true(registry.has_key(StringName(key)), "retained prefix: " + key)
		assert_eq(registry.read_value(StringName(key), &"int", 0), int(previous[key]["default"]))


func test_actual_documents_and_inclusive_bounds() -> void:
	for prefix: String in PREFIXES:
		var document: Dictionary = _document(prefix)
		assert_eq(document.size(), 2 if prefix == "hint" else 7)
		var original: ConfigRegistry = ConfigRegistry.new()
		assert_eq(original.append_document(prefix, document), OK)
		for key: String in document:
			var entry: Dictionary = document[key]
			assert_true(key.begins_with(prefix + "."))
			assert_eq(entry["type"], "int", key)
			assert_eq(original.read_value(StringName(key), &"int", 0), int(entry["default"]))
			for value: Variant in [entry["range"][0], entry["range"][1], entry["default"]]:
				var registry: ConfigRegistry = ConfigRegistry.new()
				assert_eq(
					registry.append_document(prefix, _mutated(document, key, {"default": value})),
					OK
				)
				var actual: Variant = registry.read_value(StringName(key), &"int", 0)
				assert_typeof(actual, TYPE_INT)
				assert_eq(actual, int(value), key)


func test_actual_defaults_reject_wrong_types_and_out_of_range_values() -> void:
	for prefix: String in PREFIXES:
		var document: Dictionary = _document(prefix)
		for key: String in document:
			var bounds: Array = document[key]["range"]
			for value: Variant in [
				bounds[0] - 1, bounds[1] + 1, bounds[0] + 0.5, "3", true, [], null
			]:
				_assert_rejected(prefix, _mutated(document, key, {"default": value}))


func test_actual_ranges_reject_bad_endpoints_and_shapes() -> void:
	for prefix: String in PREFIXES:
		var document: Dictionary = _document(prefix)
		for key: String in document:
			var lower: Variant = document[key]["range"][0]
			var upper: Variant = document[key]["range"][1]
			for bounds: Variant in [
				[upper, lower],
				[lower + 0.5, upper],
				[lower, upper + 0.5],
				[true, upper],
				[lower, false],
				[str(lower), upper],
				[lower, str(upper)],
				[null, upper],
				[lower, null],
				[lower],
				[lower, upper, upper],
				[],
				null,
			]:
				_assert_rejected(prefix, _mutated(document, key, {"range": bounds}))


func test_rejected_document_preserves_prior_prefix_and_publishes_nothing() -> void:
	for prefix: String in PREFIXES:
		var document: Dictionary = _document(prefix)
		var other_prefix: String = "unlocks" if prefix == "hint" else "hint"
		var other: Dictionary = _document(other_prefix)
		for bad_key: String in document:
			var registry: ConfigRegistry = ConfigRegistry.new()
			assert_eq(registry.append_document(other_prefix, other), OK)
			var invalid: Variant = document[bad_key]["range"][1] + 1
			assert_eq(
				registry.append_document(prefix, _mutated(document, bad_key, {"default": invalid})),
				ERR_INVALID_DATA
			)
			for key: String in document:
				assert_false(registry.has_key(StringName(key)), "rejected prefix: " + key)
			for key: String in other:
				assert_true(registry.has_key(StringName(key)))
				assert_eq(
					registry.read_value(StringName(key), &"int", 0), int(other[key]["default"]), key
				)
