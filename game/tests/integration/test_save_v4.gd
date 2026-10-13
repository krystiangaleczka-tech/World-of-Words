extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const PATH: String = "user://t0331-v4.json"
const ID: String = "12345678-1234-4234-8234-123456789abc"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class ObservedStorage:
	extends SaveStorage
	var commits: int = 0
	var stop_at: StringName = &""

	func commit(text: String, rotate_primary: bool) -> Error:
		commits += 1
		return super.commit(text, rotate_primary)

	func checkpoint(step: StringName) -> Error:
		return ERR_BUSY if step == stop_at else OK


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _fixture(version: int) -> Dictionary:
	return JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/save/v%d.json" % version)
	)


func _write(data: Dictionary, suffix: String = "") -> void:
	var file: FileAccess = FileAccess.open(PATH + suffix, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "", true, true))
	file.close()


func _save(storage: SaveStorage = null) -> SAVE_SCRIPT:
	var service: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(service)
	service.initialize(FixedClock.new())
	service.configure(
		storage if storage != null else SaveStorage.new(PATH),
		func() -> String:
			fail_test("Valid legacy/current files must never regenerate identity")
			return ID
	)
	return service


func _legacy_collision() -> Dictionary:
	var data: Dictionary = _fixture(3)
	data["meta"]["atomic"] = {"legacy": ["keep", {"nested": true}]}
	data["economy"]["coins"] = 99
	data["economy"]["items"]["hint"] = 8
	data["monetization"]["processed_transactions"] = ["retained-purchase"]
	return data


func test_v3_v4_golden_full_chain_and_clean_defaults() -> void:
	var source: Dictionary = _fixture(3)
	var original: Dictionary = source.duplicate(true)
	var result: Dictionary = MigrateV3ToV4.migrate(source)
	assert_false(result.is_empty())
	assert_eq_deep(SaveSchema.canonical(result), SaveSchema.canonical(_fixture(4)))
	for version: int in [1, 2, 3]:
		assert_eq_deep(
			SaveSchema.canonical(SaveMigrations.new().upgrade(_fixture(version))),
			SaveSchema.canonical(result)
		)
	assert_eq_deep(source, original)
	assert_true(SaveSchemaV3.is_valid(source))
	assert_false(SaveSchema.is_valid(source))
	assert_eq_deep(
		SaveSchema.fresh(ID, "2026-10-02T12:00:00Z", "0.1.0"), SaveSchema.canonical(result)
	)
	result["progress"]["by_lang"]["pl"]["location_stars"]["changed"] = 1
	assert_eq_deep(source, original)
	assert_eq(SaveSchema.fresh(ID, "", "")["progress"]["by_lang"]["pl"]["location_stars"], {})


func test_v3_v4_lossless_extensions_and_languages_without_backfill() -> void:
	var source: Dictionary = _fixture(3)
	source["economy"]["coins"] = 999
	source["economy"]["items"]["hint"] = 7
	source["economy"]["bonus_counter"] = 17
	source["monetization"]["processed_transactions"] = ["provider:retired-id"]
	source["root_extension"] = {"nested": [1, true, null]}
	source["progress"]["unlocked"] = ["shop"]
	var state: Dictionary = source["progress"]["by_lang"]["pl"]
	state["stars"] = 12
	state["highest_completed_slot"] = 5
	state["current_slot"] = 3
	state["postcards"] = ["retired-location"]
	state["location_pieces"] = {"retired-location": 4}
	source["progress"]["by_lang"]["en"] = state.duplicate(true)
	source["progress"]["by_lang"]["en"]["location_stars"] = {"retired-location": 3}
	var original: Dictionary = source.duplicate(true)
	var result: Dictionary = MigrateV3ToV4.migrate(source)
	assert_false(
		result.is_empty(), "Nonsequential legacy state is preserved, not silently repaired"
	)
	for section: String in ["settings", "economy", "daily", "monetization", "root_extension"]:
		assert_eq_deep(result[section], source[section])
	for lang: String in source["progress"]["by_lang"]:
		for field: String in source["progress"]["by_lang"][lang]:
			assert_eq_deep(
				result["progress"]["by_lang"][lang][field],
				source["progress"]["by_lang"][lang][field]
			)
	assert_eq(result["progress"]["by_lang"]["pl"]["location_stars"], {})
	assert_eq(
		result["progress"]["by_lang"]["pl"]["unlocked"],
		[],
		"Global features are not copied into every language"
	)
	assert_eq_deep(result["progress"]["by_lang"]["en"]["location_stars"], {"retired-location": 3})
	assert_eq(result["meta"]["atomic"]["processed"], {})
	result["root_extension"]["nested"].append("changed")
	assert_eq_deep(source, original)
	assert_false(ProgressCommitPort.new().is_available(), "Version upgrade never activates P2")


func test_v3_v4_conflicting_atomic_or_invalid_local_credits() -> void:
	for collision: Variant in [
		null, "legacy", [], {}, {"lineage": 0, "revision": 0, "processed": {}}
	]:
		var source: Dictionary = _fixture(3)
		source["meta"]["atomic"] = collision
		var original: Dictionary = source.duplicate(true)
		assert_true(SaveSchemaV3.is_valid(source))
		assert_eq(MigrateV3ToV4.migrate(source), {})
		assert_eq_deep(source, original)
	for credits: Variant in [
		null, [], {"x": -1}, {"x": 0.5}, {"x": true}, {"": 0}, {"x": 2, "y": 2}
	]:
		var source: Dictionary = _fixture(3)
		source["progress"]["by_lang"]["pl"]["stars"] = 3
		source["progress"]["by_lang"]["pl"]["location_stars"] = credits
		assert_true(SaveSchemaV3.is_valid(source))
		assert_eq(MigrateV3ToV4.migrate(source), {})
	var source: Dictionary = _fixture(3)
	source["progress"]["by_lang"]["pl"]["stars"] = WalletSnapshot.MAX_SAFE_COUNT
	source["progress"]["by_lang"]["pl"]["location_stars"] = {
		"x": WalletSnapshot.MAX_SAFE_COUNT, "y": 1
	}
	assert_eq(MigrateV3ToV4.migrate(source), {}, "Sum checked before safe integer overflow")


func _proof_document() -> Dictionary:
	var data: Dictionary = _fixture(4)
	data["meta"]["atomic"]["revision"] = 1
	data["meta"]["atomic"]["processed"]["0:campaign_complete:pl:1"] = {
		"operation_id": "campaign_complete:pl:1",
		"request_hash": "a".repeat(64),
		"lineage": 0,
		"revision": 1,
		"language": "pl",
		"slot": 1,
		"context_hash": "b".repeat(64),
		"committed_snapshot": {},
		"delta": {},
		"economy_snapshot": {},
		"notifications": []
	}
	return data


func test_v4_atomic_structural_proof_bounds_and_canonical_numbers() -> void:
	var source: Dictionary = _proof_document()
	source["progress"]["by_lang"]["pl"]["stars"] = 3
	source["progress"]["by_lang"]["pl"]["location_stars"] = {"x": 2}
	var canonical: Dictionary = SaveSchema.canonical(JSON.parse_string(JSON.stringify(source)))
	assert_false(canonical.is_empty())
	var proof: Dictionary = canonical["meta"]["atomic"]["processed"]["0:campaign_complete:pl:1"]
	for field: String in ["lineage", "revision", "slot"]:
		assert_typeof(proof[field], TYPE_INT)
	assert_typeof(canonical["progress"]["by_lang"]["pl"]["location_stars"]["x"], TYPE_INT)
	for field: String in proof:
		var bad: Dictionary = _proof_document()
		bad["meta"]["atomic"]["processed"]["0:campaign_complete:pl:1"].erase(field)
		assert_false(SaveSchema.is_valid(bad))
	for patch: Dictionary in [
		{"lineage": 1},
		{"revision": 0},
		{"revision": 2},
		{"slot": true},
		{"slot": 2},
		{"request_hash": "not-sha256"},
		{"context_hash": "B".repeat(64)},
		{"language": " pl"},
		{"operation_id": "another"},
		{"notifications": ["invalid"]},
		{"delta": []}
	]:
		var bad: Dictionary = _proof_document()
		bad["meta"]["atomic"]["processed"]["0:campaign_complete:pl:1"].merge(patch, true)
		assert_false(SaveSchema.is_valid(bad), str(patch))
	for value: Variant in [-1, true, 0.5, WalletSnapshot.MAX_SAFE_COUNT + 1]:
		var bad: Dictionary = _fixture(4)
		bad["meta"]["atomic"]["revision"] = value
		assert_false(SaveSchema.is_valid(bad))
	var bad: Dictionary = _proof_document()
	bad["meta"]["atomic"]["processed"] = {"wrong-key": proof}
	assert_false(SaveSchema.is_valid(bad))


func test_v3_atomic_collision_reopen_preserves_p1() -> void:
	var legacy: Dictionary = _legacy_collision()
	_write(legacy)
	_write(_fixture(4), ".bak")
	var original: String = FileAccess.get_file_as_string(PATH)
	var storage: ObservedStorage = ObservedStorage.new(PATH)
	var service: SAVE_SCRIPT = _save(storage)
	watch_signals(Events)
	watch_signals(service)
	assert_eq(service.migration_state(), "unconfigured")
	assert_eq(service.load(), OK)
	assert_eq(service.migration_state(), "needs_migration")
	assert_eq(service.get_section(&"economy")["coins"], 99)
	assert_eq(service.get_section(&"economy")["items"]["hint"], 8)
	assert_eq(service.get_section(&"monetization")["processed_transactions"], ["retained-purchase"])
	assert_eq_deep(service.get_section(&"meta")["atomic"], legacy["meta"]["atomic"])
	assert_signal_not_emitted(Events, "save_corrupted")
	assert_signal_not_emitted(service, "backup_restored")
	assert_eq(service.flush(), OK)
	assert_eq(storage.commits, 0, "Loading collision never rewrites valid original")
	assert_eq(FileAccess.get_file_as_string(PATH), original)
	assert_eq(service.set_setting(&"music_volume", 0.4), OK)
	var progress: Dictionary = service.get_section(&"progress")
	progress["by_lang"]["pl"]["current_slot"] = 3
	assert_eq(service.set_section(&"progress", progress), OK)
	assert_eq(service.flush(), OK)
	var reopened: SAVE_SCRIPT = _save()
	assert_eq(reopened.load(), OK)
	assert_eq(reopened.migration_state(), "needs_migration")
	assert_eq(reopened.get_setting(&"music_volume"), 0.4)
	assert_eq(reopened.get_section(&"progress")["by_lang"]["pl"]["current_slot"], 3)
	assert_eq_deep(reopened.get_section(&"economy"), service.get_section(&"economy"))
	assert_eq_deep(reopened.get_section(&"meta")["atomic"], legacy["meta"]["atomic"])
	assert_eq(SaveStorage.new(PATH).read_document()["schema_version"], 3.0)


func test_v3_atomic_collision_recovered_temp_backup_and_debug_reset() -> void:
	for suffix: String in [".tmp", ".bak"]:
		_clean()
		var legacy: Dictionary = _legacy_collision()
		_write(legacy, suffix)
		var service: SAVE_SCRIPT = _save()
		watch_signals(service)
		assert_eq(service.load(), OK)
		assert_eq(service.migration_state(), "needs_migration")
		assert_signal_emit_count(service, "backup_restored", 1)
		assert_eq(service.get_section(&"economy")["coins"], 99)
		assert_eq(service.set_setting(&"haptics_enabled", false), OK)
		assert_eq(service.debug_reset(), OK)
		var reopened: SAVE_SCRIPT = _save()
		assert_eq(reopened.load(), OK)
		assert_eq(reopened.migration_state(), "needs_migration")
		assert_eq_deep(reopened.get_section(&"meta")["atomic"], legacy["meta"]["atomic"])
		assert_eq(
			reopened.get_section(&"monetization")["processed_transactions"], ["retained-purchase"]
		)
		assert_false(reopened.get_setting(&"haptics_enabled"))
		assert_eq(
			reopened.get_section(&"economy")["coins"],
			0,
			"Explicit debug reset keeps established reset semantics"
		)
		assert_eq(SaveStorage.new(PATH).read_document()["schema_version"], 3.0)


func test_compatibility_temp_interruption_retry_preserves_original_and_credit() -> void:
	_write(_legacy_collision(), ".tmp")
	var storage: ObservedStorage = ObservedStorage.new(PATH)
	var service: SAVE_SCRIPT = _save(storage)
	assert_eq(service.load(), OK)
	var progress: Dictionary = service.get_section(&"progress")
	progress["by_lang"]["pl"]["current_slot"] = 4
	assert_eq(service.set_section(&"progress", progress), OK)
	storage.stop_at = &"temp_flushed"
	assert_eq(service.flush(), ERR_BUSY)
	var reopened: SAVE_SCRIPT = _save()
	assert_eq(reopened.load(), OK)
	assert_eq(reopened.migration_state(), "needs_migration")
	assert_eq(reopened.get_section(&"economy")["coins"], 99)
	assert_eq(reopened.get_section(&"progress")["by_lang"]["pl"]["current_slot"], 1)
	storage.stop_at = &""
	assert_eq(service.flush(), OK)
	reopened = _save()
	assert_eq(reopened.load(), OK)
	assert_eq(reopened.get_section(&"progress")["by_lang"]["pl"]["current_slot"], 4)
	assert_eq(reopened.get_section(&"economy")["items"]["hint"], 8)
	assert_eq_deep(reopened.get_section(&"meta")["atomic"], _legacy_collision()["meta"]["atomic"])


func test_invalid_v3_recovers_backup_and_successful_v4_load_is_only_version_ready() -> void:
	var bad: Dictionary = _legacy_collision()
	bad["economy"]["coins"] = -1
	_write(bad)
	_write(_fixture(4), ".bak")
	var service: SAVE_SCRIPT = _save()
	watch_signals(service)
	assert_eq(service.load(), OK)
	assert_eq(service.migration_state(), "ready")
	assert_signal_emit_count(service, "backup_restored", 1)
	assert_false(ProgressCommitPort.new().is_available())
	_clean()
	var source: Dictionary = _fixture(3)
	source["progress"]["by_lang"]["pl"]["location_stars"] = {"legacy-invalid": true}
	_write(source)
	service = _save()
	assert_eq(service.load(), OK)
	assert_eq(service.migration_state(), "needs_migration")
	assert_eq_deep(
		service.get_section(&"progress")["by_lang"]["pl"]["location_stars"],
		{"legacy-invalid": true}
	)


func test_v1_v2_collision_preserves_the_valid_v3_intermediate_without_rewrite() -> void:
	for version: int in [1, 2]:
		_clean()
		var source: Dictionary = _fixture(version)
		source["meta"]["atomic"] = {"old-owner": ["preserved"]}
		source["economy"]["coins"] = 91
		source["economy"]["items"]["reveal"] = 6
		_write(source)
		var original: String = FileAccess.get_file_as_string(PATH)
		var service: SAVE_SCRIPT = _save()
		watch_signals(Events)
		assert_eq(service.load(), OK)
		assert_eq(service.migration_state(), "needs_migration")
		assert_eq(service.get_section(&"economy")["coins"], 91)
		assert_eq(service.get_section(&"economy")["items"]["reveal"], 6)
		assert_eq_deep(service.get_section(&"meta")["atomic"], source["meta"]["atomic"])
		assert_eq(FileAccess.get_file_as_string(PATH), original)
		assert_signal_not_emitted(Events, "save_corrupted")
		assert_eq(service.set_setting(&"sfx_volume", 0.3), OK)
		assert_eq(SaveStorage.new(PATH).read_document()["schema_version"], 3.0)
		var restored: SAVE_SCRIPT = _save()
		assert_eq(restored.load(), OK)
		assert_eq(restored.migration_state(), "needs_migration")
		assert_eq(restored.get_section(&"economy")["items"]["reveal"], 6)
