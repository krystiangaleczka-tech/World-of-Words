extends GutTest

const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const FIXTURE: String = "res://tests/fixtures/content"
const SCRATCH: String = "user://t0238-content"


func after_each() -> void:
	var path: String = SCRATCH.path_join("pl/manifest.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	for directory: String in [SCRATCH.path_join("pl"), SCRATCH]:
		if DirAccess.dir_exists_absolute(directory):
			DirAccess.remove_absolute(directory)


func _service() -> CONTENT_SCRIPT:
	var result: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	add_child_autofree(result)
	return result


func _manifest() -> Dictionary:
	var result: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(FIXTURE + "/pl/manifest.json")
	)
	result["regions"] = [{"id": "r01", "name_key": "journey.region.r01", "first": 1, "last": 3}]
	result["locations"] = [
		{
			"id": "r01-l01",
			"region": "r01",
			"name_key": "journey.location.r01_l01",
			"first": 1,
			"last": 2,
			"postcard": "postcards/r01-l01.webp",
			"pieces": 4
		},
		{
			"id": "r01-l02",
			"region": "r01",
			"name_key": "journey.location.r01_l02",
			"first": 3,
			"last": 3,
			"postcard": "postcards/r01-l02.webp",
			"pieces": 4
		}
	]
	result["landmarks"] = [{"slot": 2, "landmark": true}]
	return result


func _write(value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH.path_join("pl"))
	var file: FileAccess = FileAccess.open(SCRATCH.path_join("pl/manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()


func test_preload_p1_fallback_and_query_boundaries() -> void:
	var service: CONTENT_SCRIPT = _service()
	assert_eq(service.regions(), [])
	assert_eq(service.location_for_slot(1), {})
	assert_false(service.is_landmark(1))
	assert_eq(service.load_manifest("pl", FIXTURE), OK)
	assert_eq(service.regions()[0]["id"], "campaign")
	assert_eq(service.location_for_slot(3)["last"], 3)
	assert_eq(service.location_for_slot(3)["pieces"], 0)
	assert_eq(service.region_for_slot(1)["id"], "campaign")
	for slot: int in [-1, 0, 4]:
		assert_eq(service.location_for_slot(slot), {})
		assert_eq(service.region_for_slot(slot), {})
		assert_false(service.is_landmark(slot))


func test_metadata_queries_are_copied_and_need_no_pack_io() -> void:
	var service: CONTENT_SCRIPT = _service()
	_write(_manifest())
	watch_signals(service)
	assert_eq(service.load_manifest("pl", SCRATCH), OK)
	assert_eq(service.location_for_slot(1)["id"], "r01-l01")
	assert_eq(service.location_for_slot(2)["id"], "r01-l01")
	assert_eq(service.location_for_slot(3)["id"], "r01-l02")
	assert_eq(service.region_for_slot(3)["id"], "r01")
	assert_true(service.is_landmark(2))
	assert_false(service.is_landmark(1))
	var regions: Array[Dictionary] = service.regions()
	regions[0]["id"] = "changed"
	var location: Dictionary = service.location_for_slot(1)
	location["pieces"] = 99
	assert_eq(service.regions()[0]["id"], "r01")
	assert_eq(service.location_for_slot(1)["pieces"], 4)
	assert_signal_not_emitted(service, "pack_failed")


func test_invalid_catalog_keeps_previous_manifest_and_cached_pack() -> void:
	var service: CONTENT_SCRIPT = _service()
	assert_eq(service.load_manifest("pl", FIXTURE), OK)
	var level: LevelData = service.level_for_slot(1)
	var edits: Array[Callable] = [
		func(m: Dictionary) -> void: m.erase("regions"),
		func(m: Dictionary) -> void: m["regions"] = [],
		func(m: Dictionary) -> void: m["locations"][1]["first"] = 2,
		func(m: Dictionary) -> void: m["locations"][1]["first"] = 4,
		func(m: Dictionary) -> void: m["locations"][1]["id"] = "r01-l01",
		func(m: Dictionary) -> void: m["locations"][0]["region"] = "absent",
		func(m: Dictionary) -> void: m["locations"][0]["postcard"] = "postcards/../bad.webp",
		func(m: Dictionary) -> void: m["locations"][0]["pieces"] = true,
		func(m: Dictionary) -> void: m["locations"][0]["pieces"] = 1.5,
		func(m: Dictionary) -> void: m["regions"][0]["extra"] = true,
		func(m: Dictionary) -> void: m["landmarks"].append({"slot": 2, "landmark": false}),
		func(m: Dictionary) -> void: m["landmarks"][0]["landmark"] = 1,
		func(m: Dictionary) -> void: m["landmarks"][0]["slot"] = 4
	]
	for edit: Callable in edits:
		var value: Dictionary = _manifest()
		edit.call(value)
		_write(value)
		assert_eq(service.load_manifest("pl", SCRATCH), ERR_INVALID_DATA)
		assert_eq(service.regions()[0]["id"], "campaign")
		assert_same(service.level_for_slot(1), level)


func test_integral_input_factory_isolation_and_successful_replacement() -> void:
	var source: Dictionary = _manifest()
	source["regions"][0]["last"] = 3.0
	source["locations"][0]["pieces"] = 4.0
	var catalog: ContentCatalog = ContentCatalog.from_manifest(source)
	assert_not_null(catalog)
	source["locations"][0]["id"] = "changed"
	assert_eq(catalog.location_for_slot(1)["id"], "r01-l01")
	assert_typeof(catalog.location_for_slot(1)["pieces"], TYPE_INT)
	var service: CONTENT_SCRIPT = _service()
	assert_eq(service.load_manifest("pl", FIXTURE), OK)
	_write(_manifest())
	assert_eq(service.load_manifest("pl", SCRATCH), OK)
	assert_eq(service.regions()[0]["id"], "r01")
	assert_true(service.is_landmark(2))
