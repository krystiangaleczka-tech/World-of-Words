extends GutTest

const CONTENT_SCRIPT = preload("res://services/content.gd")
const FIXTURE: String = "res://tests/fixtures/content"
const SCRATCH: String = "user://t0041-content"


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _clean() -> void:
	for sub: String in ["pl/packs", "pl", ""]:
		var path: String = SCRATCH.path_join(sub)
		var directory: DirAccess = DirAccess.open(path)
		if directory != null:
			for filename: String in directory.get_files():
				DirAccess.remove_absolute(path.path_join(filename))
			DirAccess.remove_absolute(path)


func _service() -> CONTENT_SCRIPT:
	var service: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	add_child_autofree(service)
	return service


func _fixture_manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE.path_join("pl/manifest.json")))


func _fixture_pack() -> String:
	return FileAccess.get_file_as_string(FIXTURE.path_join("pl/packs/c-0001-0003.json"))


func _write_scratch(manifest: Dictionary, pack: String) -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH.path_join("pl/packs"))
	var file: FileAccess = FileAccess.open(SCRATCH.path_join("pl/manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	file = FileAccess.open(SCRATCH.path_join("pl/packs/c-0001-0003.json"), FileAccess.WRITE)
	file.store_string(pack)
	file.close()


func test_fixture_manifest_loads() -> void:
	var service: CONTENT_SCRIPT = _service()
	assert_false(service.is_loaded())
	assert_eq(service.load_manifest("pl", FIXTURE), OK)
	assert_true(service.is_loaded())
	assert_eq(service.get_language(), "pl")
	assert_eq(service.content_version(), 1)
	assert_eq(service.slot_count(), 3)


func test_every_fixture_slot_resolves() -> void:
	var service: CONTENT_SCRIPT = _service()
	service.load_manifest("pl", FIXTURE)
	watch_signals(service)
	for slot: int in [1, 2, 3]:
		var level: LevelData = service.level_for_slot(slot)
		assert_not_null(level)
		assert_eq(level.get_slot(), slot)
		assert_eq(level.get_id(), "pl-c-%06d" % slot)
	assert_eq(service.level_for_slot(3).get_letters(), PackedStringArray(["L", "A", "S", "K", "A"]))
	assert_signal_not_emitted(service, "pack_failed")


func test_slots_outside_range_are_null_without_signal() -> void:
	var service: CONTENT_SCRIPT = _service()
	assert_null(service.level_for_slot(1))
	service.load_manifest("pl", FIXTURE)
	watch_signals(service)
	for slot: int in [0, -1, 4]:
		assert_null(service.level_for_slot(slot))
	assert_signal_not_emitted(service, "pack_failed")


func test_unknown_language_is_not_found() -> void:
	assert_eq(_service().load_manifest("de", FIXTURE), ERR_FILE_NOT_FOUND)


func test_invalid_manifests_keep_prior_state() -> void:
	var service: CONTENT_SCRIPT = _service()
	assert_eq(service.load_manifest("pl", FIXTURE), OK)
	var edits: Array[Callable] = [
		func(m: Dictionary) -> void: m["schema_version"] = 2,
		func(m: Dictionary) -> void: m["lang"] = "en",
		func(m: Dictionary) -> void: m["content_version"] = 0,
		func(m: Dictionary) -> void: m["slots"] = 4,
		func(m: Dictionary) -> void: m["packs"][0]["first"] = 2,
		func(m: Dictionary) -> void: m["packs"][0]["file"] = "../c-0001-0003.json",
		func(m: Dictionary) -> void: m["packs"][0]["file"] = "packs/x/c.json",
		func(m: Dictionary) -> void: m["packs"][0]["kind"] = "daily",
		func(m: Dictionary) -> void: m["packs"] = [],
	]
	for edit: Callable in edits:
		var manifest: Dictionary = _fixture_manifest()
		edit.call(manifest)
		_write_scratch(manifest, _fixture_pack())
		assert_eq(service.load_manifest("pl", SCRATCH), ERR_INVALID_DATA, str(manifest))
		assert_eq(service.slot_count(), 3)
		assert_eq(service.level_for_slot(1).get_id(), "pl-c-000001")


func test_hash_mismatch_emits_pack_failed() -> void:
	var service: CONTENT_SCRIPT = _service()
	_write_scratch(_fixture_manifest(), _fixture_pack().replace("TOK", "KTO"))
	assert_eq(service.load_manifest("pl", SCRATCH), OK)
	watch_signals(service)
	assert_null(service.level_for_slot(1))
	assert_signal_emitted_with_parameters(
		service, "pack_failed", ["packs/c-0001-0003.json", ERR_FILE_CORRUPT]
	)


func test_pack_not_matching_manifest_emits_pack_failed() -> void:
	var pack: Dictionary = JSON.parse_string(_fixture_pack())
	pack["levels"][1]["slot"] = 5
	var text: String = JSON.stringify(pack)
	var manifest: Dictionary = _fixture_manifest()
	manifest["packs"][0]["sha256"] = text.sha256_text()
	_write_scratch(manifest, text)
	var service: CONTENT_SCRIPT = _service()
	assert_eq(service.load_manifest("pl", SCRATCH), OK)
	watch_signals(service)
	assert_null(service.level_for_slot(1))
	assert_signal_emitted_with_parameters(
		service, "pack_failed", ["packs/c-0001-0003.json", ERR_INVALID_DATA]
	)


func test_missing_pack_emits_pack_failed() -> void:
	_write_scratch(_fixture_manifest(), _fixture_pack())
	DirAccess.remove_absolute(SCRATCH.path_join("pl/packs/c-0001-0003.json"))
	var service: CONTENT_SCRIPT = _service()
	assert_eq(service.load_manifest("pl", SCRATCH), OK)
	watch_signals(service)
	assert_null(service.level_for_slot(2))
	assert_signal_emitted_with_parameters(
		service, "pack_failed", ["packs/c-0001-0003.json", ERR_FILE_NOT_FOUND]
	)
