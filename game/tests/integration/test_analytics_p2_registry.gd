extends GutTest

const SERVICE_SCRIPT: Script = preload("res://services/analytics.gd")
var _previous: AnalyticsAdapter
var _fake: AnalyticsFake


func before_each() -> void:
	_previous = Platform.analytics
	_fake = AnalyticsFake.new()
	Platform.analytics = _fake


func after_each() -> void:
	Platform.analytics = _previous


func _documents() -> Array[Dictionary]:
	var folder: DirAccess = DirAccess.open("res://data/analytics")
	var result: Array[Dictionary] = []
	for filename: String in folder.get_files():
		if filename.ends_with(".json"):
			var data: Dictionary = JSON.parse_string(
				FileAccess.get_file_as_string("res://data/analytics/" + filename)
			)
			result.append(data)
	return result


func _payload(definition: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in definition["params"]:
		match definition["params"][key]:
			"int":
				result[key] = 1
			"float":
				result[key] = 0.5
			"bool":
				result[key] = true
			"string":
				result[key] = "fixture"
	return result


func test_all_48_events_accept_exact_typed_payloads_and_reject_wrong_shapes() -> void:
	var registry: AnalyticsRegistry = AnalyticsRegistry.new()
	var definitions: Dictionary = {}
	for document: Dictionary in _documents():
		assert_eq(registry.append_document(document), OK)
		definitions.merge(document)
	assert_eq(definitions.size(), 48)
	for name: String in definitions:
		var payload: Dictionary = _payload(definitions[name])
		assert_true(registry.validate(StringName(name), payload), name)
		var extra: Dictionary = payload.duplicate(true)
		extra["unregistered"] = true
		assert_false(registry.validate(StringName(name), extra))
		for key: String in payload:
			var missing: Dictionary = payload.duplicate(true)
			missing.erase(key)
			assert_false(registry.validate(StringName(name), missing))
			var wrong: Dictionary = payload.duplicate(true)
			wrong[key] = 1.0 if definitions[name]["params"][key] == "int" else 1
			assert_false(registry.validate(StringName(name), wrong))
	assert_false(registry.validate(&"unknown", {}))


func test_reserved_event_names_prefixes_lengths_and_params_fail_atomically() -> void:
	var definition: Dictionary = {"params": {}, "description": "Fixture"}
	for name: String in [
		"first_open",
		"session_start",
		"screen_view",
		"ad_impression",
		"error",
		"app_update",
		"google_event",
		"firebase_event",
		"ga_event",
		"_private",
		"BadName",
		"a".repeat(41),
		"fixture\n"
	]:
		var registry: AnalyticsRegistry = AnalyticsRegistry.new()
		assert_eq(
			registry.append_document({"acceptable": definition, name: definition}), ERR_INVALID_DATA
		)
		assert_eq(registry.definition(&"acceptable"), {})
	for parameter: String in [
		"currency",
		"user_id",
		"session_id",
		"firebase_param",
		"google_param",
		"ga_param",
		"_private",
		"a".repeat(41),
		"fixture\n"
	]:
		var registry: AnalyticsRegistry = AnalyticsRegistry.new()
		assert_eq(
			registry.append_document(
				{"fixture": {"params": {parameter: "string"}, "description": "Fixture"}}
			),
			ERR_INVALID_DATA
		)
		assert_eq(registry.definition(&"fixture"), {})
	var registry: AnalyticsRegistry = AnalyticsRegistry.new()
	assert_eq(
		registry.append_document(
			{"a".repeat(40): {"params": {"b".repeat(40): "int"}, "description": "Boundary"}}
		),
		OK
	)
	assert_true(registry.validate(StringName("a".repeat(40)), {"b".repeat(40): 1}))


func test_dictionary_repair_context_and_sensitive_purchase_fields_are_explicit() -> void:
	var registry: AnalyticsRegistry = AnalyticsRegistry.new()
	for document: Dictionary in _documents():
		assert_eq(registry.append_document(document), OK)
	assert_eq_deep(
		registry.definition(&"invalid_word_submitted")["params"],
		{"language": "string", "slot": "int", "letters": "string"}
	)
	var valid: Dictionary = {"language": "pl", "slot": 7, "letters": "KOT"}
	assert_true(registry.validate(&"invalid_word_submitted", valid))
	assert_false(registry.validate(&"invalid_word_submitted", {"slot": 7, "letters": "KOT"}))
	var snapshot: Dictionary = registry.definition(&"invalid_word_submitted")
	snapshot["params"]["letters"] = "int"
	assert_true(registry.validate(&"invalid_word_submitted", valid))
	var purchase: Dictionary = registry.definition(&"iap_purchase_completed")["params"]
	assert_eq_deep(
		purchase, {"product_id": "string", "price_micros": "int", "price_currency": "string"}
	)
	for field: String in ["transaction_id", "receipt", "token", "user_id", "currency"]:
		assert_false(purchase.has(field))


func test_new_registry_load_and_track_are_local_with_rejected_data_not_queued() -> void:
	var service: SERVICE_SCRIPT = SERVICE_SCRIPT.new()
	add_child_autofree(service)
	assert_eq(service.load(), OK)
	assert_eq(service.configure_stub(2), OK)
	var payload: Dictionary = {"language": "pl", "slot": 7, "letters": "KOT"}
	assert_eq(service.track(&"invalid_word_submitted", payload), OK)
	payload["letters"] = "changed"
	assert_eq(
		service.track(&"invalid_word_submitted", {"slot": 7, "letters": "KOT"}), ERR_INVALID_DATA
	)
	assert_push_error("invalid_word_submitted")
	assert_eq(service.pending_count(), 1)
	assert_eq(_fake.calls.entries.size(), 0)
	assert_eq(service.flush(), OK)
	assert_eq(_fake.calls.entries.size(), 1)
	assert_eq(
		_fake.calls.entries[0]["arguments"],
		["invalid_word_submitted", {"language": "pl", "slot": 7, "letters": "KOT"}]
	)
