extends GutTest


func _rules(pieces: int = 4, cost: int = 2) -> ProgressRules:
	var values: Dictionary = {
		"meta.stars.per_level": 1,
		"meta.postcard.pieces": pieces,
		"meta.postcard.piece_star_cost": cost
	}
	var slots: Array[int] = [2, 5, 7, 10, 12, 12, 15]
	for index: int in ProgressRules.FEATURES.size():
		values["unlocks." + ProgressRules.FEATURES[index] + "_slot"] = slots[index]
	return ProgressRules.from_config(values)


func _metadata() -> Dictionary:
	return {
		"slots": 5,
		"regions": [{"id": "r1", "first": 1, "last": 2}, {"id": "r2", "first": 3, "last": 5}],
		"locations":
		[
			{"id": "a", "region": "r1", "first": 1, "last": 2},
			{"id": "b", "region": "r2", "first": 3, "last": 4},
			{"id": "c", "region": "r2", "first": 5, "last": 5}
		]
	}


func _ledger(source: Dictionary = {}) -> ProgressLedger:
	return ProgressLedger.from_snapshot(
		ProgressSnapshot.new().snapshot() if source.is_empty() else source, _rules(), _metadata()
	)


func test_five_levels_exact_stars_short_cards_regions_and_feature_unlocks() -> void:
	var ledger: ProgressLedger = _ledger()
	assert_eq(ledger.unlocked_regions(), PackedStringArray(["r1"]))
	assert_eq(ledger.location_status(&"a"), {"stars": 0, "pieces": 0, "complete": false})
	var first: Dictionary = ledger.complete(1)
	assert_eq(first["stars"], 1)
	assert_eq(first["unlocked"], ["shuffle"])
	assert_eq(first["piece_delta"], {})
	var second: Dictionary = ledger.complete(2)
	assert_eq(second["piece_delta"], {"a": 4})
	assert_eq(second["completed_locations"], ["a"])
	assert_eq(second["regions_unlocked"], ["r2"])
	assert_eq(ledger.unlocked_regions(), PackedStringArray(["r1", "r2"]))
	assert_eq(ledger.location_status(&"a"), {"stars": 2, "pieces": 4, "complete": true})
	assert_eq(ledger.complete(3)["stars"], 1)
	assert_eq(ledger.complete(4)["unlocked"], ["bonus_meter"])
	assert_eq(ledger.complete(5)["piece_delta"], {"c": 4})
	assert_eq(ledger.snapshot()["stars"], 5)
	assert_eq(ledger.snapshot()["current_slot"], 6)
	assert_eq(ledger.snapshot()["location_stars"], {"a": 2, "b": 2, "c": 1})
	assert_eq(ledger.snapshot()["location_pieces"], {"a": 4, "b": 4, "c": 4})
	assert_eq(ledger.snapshot()["completed_locations"], ["a", "b", "c"])


func test_duplicates_stale_skipped_end_and_reload_never_award_twice() -> void:
	var ledger: ProgressLedger = _ledger()
	for bad: int in [-1, 0, 2, 6]:
		var before: Dictionary = ledger.snapshot()
		assert_eq(ledger.complete(bad), {})
		assert_eq(ledger.snapshot(), before)
	ledger.complete(1)
	var restored: ProgressLedger = _ledger(JSON.parse_string(JSON.stringify(ledger.snapshot())))
	assert_not_null(restored)
	assert_eq(restored.complete(1), {})
	assert_eq(restored.snapshot()["stars"], 1)
	for slot: int in [2, 3, 4, 5]:
		assert_eq(restored.complete(slot)["stars"], 1)
	var completed: Dictionary = restored.snapshot()
	assert_eq(restored.complete(5), {})
	assert_eq(restored.complete(6), {})
	assert_eq(restored.snapshot(), completed)


func test_threshold_order_multi_piece_catchup_and_forced_final_fill() -> void:
	var metadata: Dictionary = {
		"slots": 6,
		"regions": [{"id": "r", "first": 1, "last": 6}],
		"locations": [{"id": "a", "region": "r", "first": 1, "last": 6}]
	}
	var ledger: ProgressLedger = ProgressLedger.from_snapshot(
		ProgressSnapshot.new().snapshot(), _rules(), metadata
	)
	ledger.complete(1)
	assert_eq(ledger.complete(2)["piece_delta"], {"a": 1})
	assert_eq(ledger.complete(3)["piece_delta"], {})
	assert_eq(ledger.complete(4)["piece_delta"], {"a": 1})
	ledger.complete(5)
	assert_eq(ledger.complete(6)["piece_delta"], {"a": 2})
	var source: Dictionary = ProgressSnapshot.new().snapshot()
	source["current_slot"] = 3
	source["stars"] = 2
	source["location_stars"] = {"a": 2}
	var changed: ProgressLedger = ProgressLedger.from_snapshot(source, _rules(4, 1), metadata)
	assert_eq(changed.complete(3)["piece_delta"], {"a": 3})


func test_retired_credits_cap_reduction_and_configured_unlocks_are_monotonic() -> void:
	var source: Dictionary = ProgressSnapshot.new().snapshot()
	source["current_slot"] = 2
	source["stars"] = 4
	source["location_stars"] = {"a": 1, "retired": 3}
	source["location_pieces"] = {"a": 7, "retired": 9}
	source["completed_locations"] = ["retired"]
	source["unlocked"] = ["hint", "retired_feature"]
	var ledger: ProgressLedger = _ledger(source)
	assert_true(ledger.snapshot()["unlocked"].has("hint"))
	assert_true(ledger.snapshot()["unlocked"].has("retired_feature"))
	assert_eq(ledger.complete(2)["piece_delta"], {})
	assert_eq(ledger.snapshot()["location_pieces"], {"a": 7, "retired": 9})
	assert_eq(ledger.snapshot()["location_stars"]["retired"], 3)
	assert_eq(ledger.snapshot()["stars"], 5)
	assert_eq(ledger.snapshot()["completed_locations"], ["retired", "a"])


func test_inputs_snapshots_queries_and_results_are_isolated() -> void:
	var source: Dictionary = ProgressSnapshot.new().snapshot()
	var metadata: Dictionary = _metadata()
	var ledger: ProgressLedger = ProgressLedger.from_snapshot(source, _rules(), metadata)
	source["stars"] = 99
	metadata["locations"][0]["id"] = "changed"
	metadata["regions"][1]["first"] = 99
	ledger.complete(1)
	var result: Dictionary = ledger.complete(2)
	result["piece_delta"]["a"] = 99
	result["completed_locations"].append("fake")
	var read: Dictionary = ledger.snapshot()
	read["location_stars"]["a"] = 99
	var status: Dictionary = ledger.location_status(&"a")
	status["pieces"] = 0
	var regions: PackedStringArray = ledger.unlocked_regions()
	regions.clear()
	assert_eq(ledger.location_status(&"a"), {"stars": 2, "pieces": 4, "complete": true})
	assert_eq(ledger.unlocked_regions(), PackedStringArray(["r1", "r2"]))
	assert_eq(ledger.snapshot()["completed_locations"], ["a"])


func test_overflow_and_invalid_context_fail_without_mutation() -> void:
	var source: Dictionary = ProgressSnapshot.new().snapshot()
	source["stars"] = ProgressSnapshot.MAX_SAFE_COUNT
	var ledger: ProgressLedger = _ledger(source)
	var before: Dictionary = ledger.snapshot()
	assert_eq(ledger.complete(1), {})
	assert_eq(ledger.snapshot(), before)
	var edits: Array[Callable] = [
		func(m: Dictionary) -> void: m["slots"] = 0,
		func(m: Dictionary) -> void: m["slots"] = ProgressSnapshot.MAX_SAFE_COUNT,
		func(m: Dictionary) -> void: m["regions"] = [],
		func(m: Dictionary) -> void: m["locations"][0]["first"] = 1.0,
		func(m: Dictionary) -> void: m["locations"][1]["first"] = 4,
		func(m: Dictionary) -> void: m["locations"][1]["first"] = 2,
		func(m: Dictionary) -> void: m["locations"][1]["id"] = "a",
		func(m: Dictionary) -> void: m["locations"][1]["region"] = "absent",
		func(m: Dictionary) -> void: m["regions"][0]["last"] = 3
	]
	for edit: Callable in edits:
		var metadata: Dictionary = _metadata()
		edit.call(metadata)
		assert_null(
			ProgressLedger.from_snapshot(ProgressSnapshot.new().snapshot(), _rules(), metadata)
		)
	assert_null(ProgressLedger.from_snapshot({}, _rules(), _metadata()))
	assert_null(
		ProgressLedger.from_snapshot(
			ProgressSnapshot.new().snapshot(), ProgressRules.new(), _metadata()
		)
	)
	source = ProgressSnapshot.new().snapshot()
	source["stars"] = 1
	source["location_stars"] = {"a": 1}
	assert_null(ProgressLedger.from_snapshot(source, _rules(), _metadata()))
	source = ProgressSnapshot.new().snapshot()
	source["completed_locations"] = ["a"]
	assert_null(ProgressLedger.from_snapshot(source, _rules(), _metadata()))


func test_unconfigured_unknown_and_legacy_queries_never_backfill() -> void:
	var empty: ProgressLedger = ProgressLedger.new()
	assert_eq(empty.snapshot(), {})
	assert_eq(empty.complete(1), {})
	assert_eq(empty.location_status(&"a"), {})
	assert_eq(empty.unlocked_regions(), PackedStringArray())
	var source: Dictionary = ProgressSnapshot.new().snapshot()
	source["current_slot"] = 3
	var ledger: ProgressLedger = _ledger(source)
	assert_eq(ledger.location_status(&"unknown"), {})
	assert_eq(ledger.location_status(&"a"), {"stars": 0, "pieces": 0, "complete": true})
	assert_eq(ledger.snapshot()["stars"], 0)
	assert_eq(ledger.snapshot()["location_pieces"], {})
