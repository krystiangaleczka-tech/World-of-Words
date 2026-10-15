extends GutTest


func _registry() -> ConfigRegistry:
	var registry: ConfigRegistry = ConfigRegistry.new()
	var error: Error = registry.append_document(
		"ads",
		{
			"ads.interstitial.min_levels_between":
			{
				"default": 4,
				"type": "int",
				"range": [1, 20],
				"description": "Cooldown",
				"owner": "Sol",
				"remote": true
			},
			"ads.interstitial.first_slot":
			{
				"default": 16,
				"type": "int",
				"range": [1, 200],
				"description": "Canonical start",
				"owner": "Chris",
				"remote": false
			}
		}
	)
	assert_eq(error, OK)
	return registry


func _document() -> Dictionary:
	return {
		"version": 1,
		"values": {"ads.interstitial.min_levels_between": 5},
		"experiments":
		[
			{
				"id": "ad_frequency",
				"variants": [{"id": "control", "weight": 50}, {"id": "variant", "weight": 50}]
			}
		]
	}


func test_accepts_only_registered_remote_tunable_in_range_values() -> void:
	var result: Dictionary = RemoteConfigContract.validate(_document(), _registry(), "install-a")
	assert_eq(result["overrides"], {"ads.interstitial.min_levels_between": 5})
	assert_eq(result["rejected"], [])
	assert_eq(result["unknown"], [])
	assert_true(result["assignments"]["ad_frequency"] in ["control", "variant"])


func test_unknown_is_logged_and_protected_key_is_rejected() -> void:
	var doc: Dictionary = _document()
	doc["values"]["unused.future"] = 9
	doc["values"]["ads.interstitial.first_slot"] = 1
	var result: Dictionary = RemoteConfigContract.validate(doc, _registry(), "install-a")
	assert_eq(result["unknown"], ["unused.future"])
	assert_eq(result["rejected"], ["ads.interstitial.first_slot"])
	assert_eq(result["overrides"], {"ads.interstitial.min_levels_between": 5})


func test_wrong_type_out_of_range_keeps_defaults() -> void:
	for value: Variant in ["5", 21, 0, true, 5.0]:
		var doc: Dictionary = _document()
		doc["values"]["ads.interstitial.min_levels_between"] = value
		var result: Dictionary = RemoteConfigContract.validate(doc, _registry(), "install")
		assert_eq(result["overrides"], {})
		assert_eq(result["rejected"], ["ads.interstitial.min_levels_between"])


func test_experiment_bucket_is_stable_and_assignment_recomputed() -> void:
	var first: Dictionary = RemoteConfigContract.validate(_document(), _registry(), "same-install")
	var again: Dictionary = RemoteConfigContract.validate(_document(), _registry(), "same-install")
	assert_eq(first["buckets"], again["buckets"])
	assert_eq(first["assignments"], again["assignments"])
	var draw: int = RemoteConfigContract.bucket("same-install", "ad_frequency")
	assert_between(draw, 0, 99)
	assert_eq(first["buckets"]["ad_frequency"], draw)
	assert_eq(RemoteConfigContract.bucket("", "ad_frequency"), -1)


func test_malformed_envelope_and_experiments_fail_atomically() -> void:
	assert_eq(RemoteConfigContract.validate({}, _registry(), "install"), {})
	var doc: Dictionary = _document()
	doc["experiments"][0]["variants"][0]["weight"] = 49
	assert_eq(RemoteConfigContract.validate(doc, _registry(), "install"), {})
	doc = _document()
	doc["experiments"].append(doc["experiments"][0].duplicate(true))
	assert_eq(RemoteConfigContract.validate(doc, _registry(), "install"), {})


func test_invalid_download_keeps_last_good_cache() -> void:
	var current: Dictionary = _document()
	var accepted: Dictionary = RemoteConfigContract.select_snapshot(
		current, {}, _registry(), "install"
	)
	assert_eq(accepted["source"], "remote")
	var recovered: Dictionary = RemoteConfigContract.select_snapshot(
		{}, current, _registry(), "install"
	)
	assert_eq(recovered["source"], "cache")
	assert_eq(recovered["effective"], accepted["effective"])
	assert_eq(
		RemoteConfigContract.select_snapshot({}, {}, _registry(), "install")["source"], "defaults"
	)
