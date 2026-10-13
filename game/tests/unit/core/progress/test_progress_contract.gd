extends GutTest


func _config() -> Dictionary:
	var values: Dictionary = {
		"meta.stars.per_level": 1, "meta.postcard.pieces": 4, "meta.postcard.piece_star_cost": 12
	}
	var slots: Array[int] = [2, 5, 7, 10, 12, 12, 15]
	for index: int in ProgressRules.FEATURES.size():
		values["unlocks." + ProgressRules.FEATURES[index] + "_slot"] = slots[index]
	return values


func test_snapshot_json_isolated_retired_values_and_canonical_counts() -> void:
	var source: Dictionary = ProgressSnapshot.new().snapshot()
	source["stars"] = 9
	source["location_stars"] = {"retired": 7}
	source["location_pieces"] = {"retired": 5}
	source["completed_locations"] = ["retired"]
	source["unlocked"] = ["old_feature"]
	var value: ProgressSnapshot = ProgressSnapshot.from_dict(
		JSON.parse_string(JSON.stringify(source))
	)
	assert_not_null(value)
	assert_eq(value.snapshot(), source)
	assert_typeof(value.snapshot()["stars"], TYPE_INT)
	assert_typeof(value.snapshot()["location_stars"]["retired"], TYPE_INT)
	source["location_stars"]["retired"] = 0
	var read: Dictionary = value.snapshot()
	read["location_pieces"]["retired"] = 0
	read["completed_locations"].clear()
	assert_eq(value.snapshot()["location_stars"]["retired"], 7)
	assert_eq(value.snapshot()["location_pieces"]["retired"], 5)
	assert_eq(value.snapshot()["completed_locations"], ["retired"])


func test_snapshot_invalid_closed_shapes_and_counts_are_rejected() -> void:
	for field: String in ProgressSnapshot.KEYS:
		var source: Dictionary = ProgressSnapshot.new().snapshot()
		source.erase(field)
		assert_null(ProgressSnapshot.from_dict(source))
	var extra: Dictionary = ProgressSnapshot.new().snapshot()
	extra["unknown"] = 0
	assert_null(ProgressSnapshot.from_dict(extra))
	for bad: Variant in [-1, true, 1.5, "1", NAN, ProgressSnapshot.MAX_SAFE_COUNT + 1]:
		var source: Dictionary = ProgressSnapshot.new().snapshot()
		source["stars"] = bad
		assert_null(ProgressSnapshot.from_dict(source))
		source["stars"] = 1
		source["location_pieces"] = {"id": bad}
		assert_null(ProgressSnapshot.from_dict(source))
	for ids: Array in [["x", "x"], [""], [" x"], [true]]:
		var source: Dictionary = ProgressSnapshot.new().snapshot()
		source["unlocked"] = ids
		assert_null(ProgressSnapshot.from_dict(source))
	var inconsistent: Dictionary = ProgressSnapshot.new().snapshot()
	inconsistent["location_stars"] = {"id": 1}
	assert_null(ProgressSnapshot.from_dict(inconsistent))
	inconsistent = ProgressSnapshot.new().snapshot()
	inconsistent["current_slot"] = 0
	assert_null(ProgressSnapshot.from_dict(inconsistent))


func test_fixed_one_star_config_and_copy_isolation() -> void:
	var values: Dictionary = _config()
	var rules: ProgressRules = ProgressRules.from_config(values)
	assert_not_null(rules)
	values["meta.postcard.pieces"] = 1
	assert_eq(rules.piece_count(), 4)
	assert_eq(rules.stars_per_level(), 1)
	for bad: Variant in [0, 2, true, 1.0]:
		values = _config()
		values["meta.stars.per_level"] = bad
		assert_null(ProgressRules.from_config(values))
	for key: String in _config():
		values = _config()
		values.erase(key)
		assert_null(ProgressRules.from_config(values))
	values = _config()
	values["meta.postcard.pieces"] = ProgressSnapshot.MAX_SAFE_COUNT + 1
	assert_null(ProgressRules.from_config(values))


func test_piece_threshold_completion_cap_and_no_credit_removal() -> void:
	var rules: ProgressRules = ProgressRules.from_config(_config())
	for stars: int in [0, 11, 12, 23, 24, 47, 48, 100]:
		var expected: Dictionary = {0: 0, 11: 0, 12: 1, 23: 1, 24: 2, 47: 3, 48: 4, 100: 4}
		assert_eq(rules.revealed_pieces(stars, 0), expected[stars])
	assert_eq(rules.revealed_pieces(2, 0, true), 4)
	assert_eq(rules.revealed_pieces(0, 7), 7)
	assert_eq(rules.revealed_pieces(-1, 0), -1)
	var config: Dictionary = _config()
	config["meta.postcard.pieces"] = ProgressSnapshot.MAX_SAFE_COUNT
	config["meta.postcard.piece_star_cost"] = 7
	var exact: ProgressRules = ProgressRules.from_config(config)
	assert_eq(exact.revealed_pieces(ProgressSnapshot.MAX_SAFE_COUNT, 0), 1286742750677284)


func test_unlock_boundaries_prior_ids_and_config_changes() -> void:
	var rules: ProgressRules = ProgressRules.from_config(_config())
	assert_eq(rules.unlocked_features(1, PackedStringArray()), PackedStringArray())
	assert_eq(rules.unlocked_features(2, PackedStringArray()), PackedStringArray(["shuffle"]))
	var prior: PackedStringArray = PackedStringArray(["retired", "hint"])
	assert_eq(rules.unlocked_features(1, prior), prior)
	assert_eq(
		rules.unlocked_features(7, PackedStringArray()),
		PackedStringArray(["shuffle", "bonus_meter", "hint"])
	)
	var changed: Dictionary = _config()
	changed["unlocks.hint_slot"] = 50
	var later: ProgressRules = ProgressRules.from_config(changed)
	assert_true(later.unlocked_features(7, prior).has("hint"))
	assert_eq(prior, PackedStringArray(["retired", "hint"]))
	assert_true(rules.unlocked_features(12, PackedStringArray()).has("double_reward"))
	assert_false(rules.unlocked_features(14, PackedStringArray()).has("daily"))
	assert_true(rules.unlocked_features(15, PackedStringArray()).has("daily"))


func test_location_region_and_unconfigured_boundaries() -> void:
	var rules: ProgressRules = ProgressRules.from_config(_config())
	assert_false(rules.location_complete(19, 20))
	assert_true(rules.location_complete(20, 20))
	assert_true(rules.location_complete(21, 20))
	assert_false(rules.region_unlocked(20, 21))
	assert_true(rules.region_unlocked(21, 21))
	assert_true(rules.region_unlocked(1, 1))
	var empty: ProgressRules = ProgressRules.new()
	assert_eq(empty.revealed_pieces(12, 0), -1)
	assert_eq(empty.unlocked_features(50, PackedStringArray()), PackedStringArray())
	assert_false(empty.location_complete(20, 20))
	assert_false(empty.region_unlocked(21, 21))
