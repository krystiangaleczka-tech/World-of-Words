extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const PATH: String = "user://t0229-v3.json"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class InterruptedStorage:
	extends SaveStorage
	var stop: bool = false

	func checkpoint(step: StringName) -> Error:
		return ERR_BUSY if stop and step == &"temp_flushed" else OK


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


func _save(storage: SaveStorage) -> SAVE_SCRIPT:
	var service: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(service)
	service.initialize(FixedClock.new())
	service.configure(storage)
	return service


func test_goldens_complete_chain_and_independent_defaults() -> void:
	var source: Dictionary = _fixture(2)
	var snapshot: Dictionary = source.duplicate(true)
	var result: Dictionary = MigrateV2ToV3.migrate(source)
	assert_eq_deep(SaveSchema.canonical(result), SaveSchema.canonical(_fixture(3)))
	assert_eq_deep(SaveMigrations.new().upgrade(_fixture(1)), result)
	assert_eq_deep(source, snapshot)
	assert_true(SaveSchema.is_valid(result))
	var meta: Dictionary = result["meta"]
	assert_eq_deep(
		SaveSchema.fresh(meta["install_id"], meta["created_at"], meta["app_version"]),
		SaveSchema.canonical(result)
	)
	result["meta"]["coach_marks_seen"].append("changed")
	assert_eq(source["progress"]["coach_marks_seen"], [])
	assert_eq(SaveSchema.fresh(meta["install_id"], "", "")["meta"]["coach_marks_seen"], [])


func test_earned_items_wallet_transactions_and_languages_never_decrease() -> void:
	var source: Dictionary = _fixture(2)
	source["economy"].merge(
		{
			"coins": 321,
			"items": {"hint": 9, "reveal": 4},
			"journal": [{"source": "earned", "coins": 321}]
		},
		true
	)
	source["progress"]["bonus_meter"] = 17
	source["progress"]["coach_marks_seen"] = ["hint"]
	source["progress"]["by_lang"]["pl"]["location_pieces"] = {"forest": 3}
	source["progress"]["by_lang"]["pl"]["stars"] = 12
	source["progress"]["by_lang"]["en"] = source["progress"]["by_lang"]["pl"].duplicate(true)
	source["progress"]["by_lang"]["en"]["current_slot"] = 8
	source["monetization"]["remove_forced_ads"] = true
	source["monetization"]["processed_transactions"] = ["android:token", "ios:original"]
	source["monetization"]["last_interstitial"] = 1234
	source["monetization"]["shop_coins_ads"] = {"date": "2026-10-13", "count": 2}
	source["extension"] = {"nested": [1, {"kept": true}]}
	var before: Dictionary = source.duplicate(true)
	var upgraded: Dictionary = MigrateV2ToV3.migrate(source)
	assert_false(upgraded.is_empty())
	assert_eq_deep(source, before)
	assert_eq(upgraded["economy"]["coins"], 321)
	assert_eq_deep(upgraded["economy"]["items"], source["economy"]["items"])
	assert_eq_deep(upgraded["economy"]["journal"], source["economy"]["journal"])
	assert_eq(upgraded["economy"]["bonus_counter"], 17)
	assert_eq_deep(upgraded["meta"]["coach_marks_seen"], ["hint"])
	assert_eq(upgraded["monetization"]["last_interstitial_time"], 1234)
	assert_eq_deep(
		upgraded["monetization"]["processed_transactions"],
		source["monetization"]["processed_transactions"]
	)
	assert_true(upgraded["monetization"]["remove_forced_ads"])
	assert_eq_deep(
		upgraded["monetization"]["shop_coins_ads"], source["monetization"]["shop_coins_ads"]
	)
	for lang: String in source["progress"]["by_lang"]:
		for field: String in source["progress"]["by_lang"][lang]:
			assert_eq_deep(
				upgraded["progress"]["by_lang"][lang][field],
				source["progress"]["by_lang"][lang][field]
			)
	upgraded["extension"]["nested"].append("changed")
	assert_eq_deep(source, before)


func test_legacy_opaque_values_preserved_and_partial_new_fields_kept() -> void:
	var source: Dictionary = _fixture(2)
	source["monetization"]["last_interstitial"] = "legacy-timestamp"
	source["monetization"]["shop_coins_ads"] = {"2026-10-12": 2}
	source["meta"]["onboarding_step"] = 7
	source["monetization"]["consent_state"] = {"resolved": true}
	var result: Dictionary = MigrateV2ToV3.migrate(source)
	assert_eq(result["monetization"]["last_interstitial"], "legacy-timestamp")
	assert_null(result["monetization"]["last_interstitial_time"])
	assert_eq_deep(result["monetization"]["shop_coins_ads"]["legacy"], {"2026-10-12": 2})
	assert_eq(result["meta"]["onboarding_step"], 7)
	assert_eq_deep(result["monetization"]["consent_state"], {"resolved": true})
	source["economy"]["bonus_counter"] = 42
	assert_eq(
		MigrateV2ToV3.migrate(source), {}, "Conflicting earned counters cannot be overwritten"
	)
	source["economy"].erase("bonus_counter")
	source["meta"]["coach_marks_seen"] = ["conflict"]
	assert_eq(MigrateV2ToV3.migrate(source), {})


func test_partial_legacy_cap_keys_preserved_and_timestamp_conflicts_rejected() -> void:
	for cap: Dictionary in [
		{"date": "historical"}, {"count": {"provider": 2}}, {"date": "x", "count": -1}
	]:
		var source: Dictionary = _fixture(2)
		source["economy"]["items"]["hint"] = 7
		source["monetization"]["shop_coins_ads"] = cap
		var result: Dictionary = MigrateV2ToV3.migrate(source)
		assert_false(result.is_empty())
		assert_eq(result["economy"]["items"]["hint"], 7)
		assert_eq_deep(result["monetization"]["shop_coins_ads"]["legacy"], cap)
	var source: Dictionary = _fixture(2)
	source["monetization"]["last_interstitial"] = 1234
	source["monetization"]["last_interstitial_time"] = 9999
	assert_eq(MigrateV2ToV3.migrate(source), {})
	source["monetization"]["last_interstitial_time"] = 1234
	assert_false(MigrateV2ToV3.migrate(source).is_empty())


func test_bad_v2_shapes_and_versions_rejected_before_defaults() -> void:
	for section: StringName in SaveSchema.SECTIONS:
		var source: Dictionary = _fixture(2)
		source.erase(str(section))
		assert_eq(MigrateV2ToV3.migrate(source), {})
	var source: Dictionary = _fixture(2)
	source["economy"]["items"].erase("hint")
	assert_eq(MigrateV2ToV3.migrate(source), {})
	source = _fixture(2)
	source["progress"]["by_lang"]["pl"].erase("stars")
	assert_eq(MigrateV2ToV3.migrate(source), {})
	for version: Variant in [null, true, 1, 2.5, 4]:
		source = _fixture(2)
		source["schema_version"] = version
		assert_eq(MigrateV2ToV3.migrate(source), {})


func test_numeric_roundtrip_and_invalid_p2_values() -> void:
	var source: Dictionary = _fixture(3)
	source["monetization"]["last_purchase_slot"] = 9
	source["progress"]["by_lang"]["pl"]["location_pieces"] = {"forest": 3}
	var result: Dictionary = SaveSchema.canonical(JSON.parse_string(JSON.stringify(source)))
	assert_typeof(result["economy"]["bonus_counter"], TYPE_INT)
	assert_typeof(result["meta"]["onboarding_step"], TYPE_INT)
	assert_typeof(result["monetization"]["last_purchase_slot"], TYPE_INT)
	assert_typeof(result["monetization"]["shop_coins_ads"]["count"], TYPE_INT)
	assert_typeof(result["progress"]["by_lang"]["pl"]["location_pieces"]["forest"], TYPE_INT)
	for value: Variant in [-1, 1.5, true, "9", NAN, 9007199254740992]:
		for field: String in ["coins", "bonus_counter"]:
			var bad: Dictionary = source.duplicate(true)
			bad["economy"][field] = value
			assert_false(SaveSchema.is_valid(bad))
		var bad: Dictionary = source.duplicate(true)
		bad["economy"]["items"]["hint"] = value
		assert_false(SaveSchema.is_valid(bad))
		bad = source.duplicate(true)
		bad["monetization"]["shop_coins_ads"]["count"] = value
		assert_false(SaveSchema.is_valid(bad))
	for values: Array in [["duplicate", "duplicate"], [""], [42]]:
		var bad: Dictionary = source.duplicate(true)
		bad["monetization"]["processed_transactions"] = values
		assert_false(SaveSchema.is_valid(bad))


func test_migrated_save_flush_retry_backup_and_reload_preserve_wallet() -> void:
	var source: Dictionary = _fixture(2)
	source["economy"]["coins"] = 99
	source["economy"]["items"]["hint"] = 8
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(source))
	file.close()
	var storage: InterruptedStorage = InterruptedStorage.new(PATH)
	var service: SAVE_SCRIPT = _save(storage)
	assert_eq(service.load(), OK)
	assert_eq(service.get_section(&"economy")["items"]["hint"], 8)
	storage.stop = true
	assert_eq(service.flush(), ERR_BUSY)
	assert_eq_deep(storage.read_document(), JSON.parse_string(JSON.stringify(source)))
	storage.stop = false
	assert_eq(service.flush(), OK)
	assert_eq_deep(storage.read_document(".bak"), JSON.parse_string(JSON.stringify(source)))
	assert_eq(storage.read_document()["schema_version"], 3.0)
	var restored: SAVE_SCRIPT = _save(SaveStorage.new(PATH))
	assert_eq(restored.load(), OK)
	assert_eq_deep(restored.get_section(&"economy"), service.get_section(&"economy"))
	assert_eq(restored.get_section(&"meta")["install_id"], source["meta"]["install_id"])
