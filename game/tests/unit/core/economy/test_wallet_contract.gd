extends GutTest


func _wallet() -> WalletSnapshot:
	return WalletSnapshot.from_dict({"coins": 100, "items": {"hint": 3, "reveal": 2}})


func _config() -> Dictionary:
	return {
		"economy.price.hint": 17,
		"economy.price.reveal": 43,
		"economy.reward.level_complete": 9,
		"economy.reward.double_multiplier": 3,
		"economy.reward.bonus_chest": 31,
		"economy.reward.rewarded_hint": 2,
		"economy.reward.rewarded_coins": 19,
		"economy.reward.daily": 29,
		"economy.grant.onboarding_hints": 5
	}


func test_wallet_roundtrip_deep_isolation_and_integral_json_boundary() -> void:
	var source: Dictionary = {"coins": 100, "items": {"hint": 3, "reveal": 2}}
	var wallet: WalletSnapshot = WalletSnapshot.from_dict(JSON.parse_string(JSON.stringify(source)))
	assert_not_null(wallet)
	assert_eq_deep(wallet.snapshot(), source)
	source["items"]["hint"] = 999
	var snapshot: Dictionary = wallet.snapshot()
	snapshot["items"]["reveal"] = 999
	assert_eq(wallet.snapshot()["items"]["hint"], 3)
	assert_eq(wallet.snapshot()["items"]["reveal"], 2)
	assert_typeof(wallet.snapshot()["coins"], TYPE_INT)
	for bad: Dictionary in [
		{},
		{"coins": 0},
		{"coins": 0, "items": {}},
		{"coins": 0, "items": {"hint": 0, "reveal": 0, "stars": 1}}
	]:
		assert_null(WalletSnapshot.from_dict(bad))
	for value: Variant in [-1, 0.5, true, "1", NAN, INF, WalletSnapshot.MAX_SAFE_COUNT + 1]:
		source = {"coins": value, "items": {"hint": 0, "reveal": 0}}
		assert_null(WalletSnapshot.from_dict(source))
		source = {"coins": 0, "items": {"hint": value, "reveal": 0}}
		assert_null(WalletSnapshot.from_dict(source))


func test_grant_spend_and_affordability_are_atomic_immutable_values() -> void:
	var original: WalletSnapshot = _wallet()
	var request: Dictionary = {"coins": 40, "hint": 2, "reveal": 1}
	var granted: WalletSnapshot = original.granted(request)
	assert_eq_deep(granted.snapshot(), {"coins": 140, "items": {"hint": 5, "reveal": 3}})
	assert_eq_deep(granted.spent(request).snapshot(), original.snapshot())
	assert_eq_deep(request, {"coins": 40, "hint": 2, "reveal": 1})
	assert_true(original.can_afford({"coins": 100, "hint": 3, "reveal": 2}))
	assert_eq_deep(
		original.spent({"coins": 100, "hint": 3, "reveal": 2}).snapshot(),
		{"coins": 0, "items": {"hint": 0, "reveal": 0}}
	)
	for request_bad: Dictionary in [{"coins": 101}, {"coins": 1, "hint": 4}, {"reveal": 3}]:
		assert_false(original.can_afford(request_bad))
		assert_null(original.spent(request_bad))
	assert_eq_deep(original.snapshot(), _wallet().snapshot())


func test_invalid_payloads_and_safe_integer_overflow_never_change_state() -> void:
	var wallet: WalletSnapshot = _wallet()
	for request: Dictionary in [
		{},
		{"coins": 0},
		{"hint": 0, "reveal": 0},
		{"stars": 1},
		{"coins": -1},
		{"hint": 0.5},
		{"coins": true},
		{"coins": 1.0},
		{"coins": WalletSnapshot.MAX_SAFE_COUNT + 1}
	]:
		assert_false(WalletSnapshot.valid_amounts(request))
		assert_false(wallet.can_afford(request))
		assert_null(wallet.granted(request))
		assert_null(wallet.spent(request))
	assert_true(WalletSnapshot.valid_amounts({"coins": 0, "hint": 1}))
	var maximum: WalletSnapshot = WalletSnapshot.from_dict(
		{
			"coins": WalletSnapshot.MAX_SAFE_COUNT,
			"items": {"hint": 0, "reveal": WalletSnapshot.MAX_SAFE_COUNT}
		}
	)
	assert_null(maximum.granted({"coins": 1, "hint": 1}))
	assert_null(maximum.granted({"reveal": 1}))
	assert_eq(maximum.snapshot()["items"]["hint"], 0)
	assert_eq(maximum.spent({"coins": 1}).snapshot()["coins"], WalletSnapshot.MAX_SAFE_COUNT - 1)


func test_all_prices_and_rewards_use_injected_nondefault_values() -> void:
	var config: Dictionary = _config()
	config["unrelated"] = true
	var table: RewardTable = RewardTable.from_config(config)
	assert_not_null(table)
	assert_eq_deep(table.price(&"hint"), {"coins": 17})
	assert_eq_deep(table.price(&"reveal"), {"coins": 43})
	assert_eq_deep(table.reward(&"level_complete"), {"coins": 9})
	assert_eq_deep(table.reward(&"level_complete", true), {"coins": 27})
	assert_eq_deep(table.reward(&"bonus_chest"), {"coins": 31})
	assert_eq_deep(table.reward(&"rewarded_hint"), {"hint": 2})
	assert_eq_deep(table.reward(&"rewarded_coins"), {"coins": 19})
	assert_eq_deep(table.reward(&"daily"), {"coins": 29})
	assert_eq_deep(table.reward(&"onboarding_hints"), {"hint": 5})
	config["economy.price.hint"] = 999
	var result: Dictionary = table.reward(&"bonus_chest")
	result["coins"] = 999
	assert_eq_deep(table.price(&"hint"), {"coins": 17})
	assert_eq_deep(table.reward(&"bonus_chest"), {"coins": 31})
	assert_eq(table.reward(&"bonus_chest", true), {})
	assert_eq(table.reward(&"unknown"), {})
	assert_eq(table.price(&"unknown"), {})


func test_reward_configuration_rejection_and_multiplier_overflow() -> void:
	for key: String in RewardTable.KEYS:
		var config: Dictionary = _config()
		config.erase(key)
		assert_null(RewardTable.from_config(config))
		for invalid: Variant in [-1, 1.0, true, "2", WalletSnapshot.MAX_SAFE_COUNT + 1]:
			config = _config()
			config[key] = invalid
			assert_null(RewardTable.from_config(config))
	for key: String in [
		"economy.price.hint", "economy.price.reveal", "economy.reward.double_multiplier"
	]:
		var config: Dictionary = _config()
		config[key] = 0
		assert_null(RewardTable.from_config(config))
	var config: Dictionary = _config()
	config["economy.reward.level_complete"] = WalletSnapshot.MAX_SAFE_COUNT
	var table: RewardTable = RewardTable.from_config(config)
	assert_eq(table.reward(&"level_complete", true), {})
	assert_eq_deep(table.reward(&"level_complete"), {"coins": WalletSnapshot.MAX_SAFE_COUNT})
	assert_eq(RewardTable.new().reward(&"level_complete"), {})
