extends GutTest


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
		"economy.grant.onboarding_hints": 5,
		"bonus.chest.words_required": 5
	}


func _state(coins: int = 100, bonus: int = 0) -> Dictionary:
	return {"coins": coins, "items": {"hint": 3, "reveal": 2}, "bonus_counter": bonus}


func test_factory_roundtrip_inputs_and_snapshot_isolation() -> void:
	var source: Dictionary = JSON.parse_string(JSON.stringify(_state(100, 7)))
	var config: Dictionary = _config()
	source["journal"] = [{"owner": "service"}]
	var ledger: EconomyLedger = EconomyLedger.from_dict(source, config)
	assert_not_null(ledger)
	assert_eq_deep(ledger.snapshot(), _state(100, 7))
	source["items"]["hint"] = 999
	source["bonus_counter"] = 999
	config["bonus.chest.words_required"] = 999
	config["economy.price.hint"] = 999
	var snapshot: Dictionary = ledger.snapshot()
	snapshot["items"]["hint"] = 777
	assert_eq_deep(ledger.snapshot(), _state(100, 7))
	assert_eq_deep(ledger.price(&"hint"), {"coins": 17})
	assert_eq(ledger.redeem_bonus_chests()["chests"], 1)
	assert_eq_deep(source["journal"], [{"owner": "service"}])


func test_reasoned_grants_spends_atomicity_and_affordability() -> void:
	var ledger: EconomyLedger = EconomyLedger.from_dict(_state(), _config())
	assert_eq(ledger.grant(&"earned", {"coins": 40, "hint": 2}), OK)
	assert_eq_deep(
		ledger.snapshot(), {"coins": 140, "items": {"hint": 5, "reveal": 2}, "bonus_counter": 0}
	)
	var before: Dictionary = ledger.snapshot()
	for reason: StringName in [&"", &" ", &" invalid"]:
		assert_eq(ledger.grant(reason, {"coins": 1}), ERR_INVALID_PARAMETER)
		assert_false(ledger.spend(reason, {"coins": 1}))
	for amounts: Dictionary in [{}, {"coins": -1}, {"hint": true}, {"stars": 1}]:
		assert_eq(ledger.grant(&"earned", amounts), ERR_INVALID_PARAMETER)
		assert_false(ledger.spend(&"hint", amounts))
	assert_false(ledger.spend(&"mixed", {"coins": 1, "reveal": 3}))
	assert_eq_deep(ledger.snapshot(), before)
	assert_true(ledger.can_afford({"coins": 140, "hint": 5, "reveal": 2}))
	assert_true(ledger.spend(&"all", {"coins": 140, "hint": 5, "reveal": 2}))
	assert_eq_deep(
		ledger.snapshot(), {"coins": 0, "items": {"hint": 0, "reveal": 0}, "bonus_counter": 0}
	)
	assert_false(ledger.can_afford({"coins": 1}))


func test_rewards_and_prices_are_injected_and_double_is_level_only() -> void:
	var ledger: EconomyLedger = EconomyLedger.from_dict(_state(), _config())
	assert_eq(ledger.grant_reward(&"level_complete", true), OK)
	assert_eq(ledger.snapshot()["coins"], 127)
	assert_eq(ledger.grant_reward(&"bonus_chest", true), ERR_INVALID_PARAMETER)
	assert_eq(ledger.grant_reward(&"unknown"), ERR_INVALID_PARAMETER)
	assert_eq(ledger.snapshot()["coins"], 127)
	assert_eq(ledger.grant_reward(&"rewarded_hint"), OK)
	assert_eq(ledger.snapshot()["items"]["hint"], 5)
	assert_true(ledger.spend(&"hint_price", ledger.price(&"hint")))
	assert_eq(ledger.snapshot()["coins"], 110)
	assert_eq(ledger.price(&"unknown"), {})


func test_bonus_before_unlock_no_midlevel_reward_multichest_and_carryover_reload() -> void:
	var ledger: EconomyLedger = EconomyLedger.from_dict(_state(), _config())
	assert_eq(ledger.add_bonus(13, false), OK)
	assert_eq(ledger.snapshot()["bonus_counter"], 0)
	assert_eq(ledger.add_bonus(13), OK)
	assert_eq(ledger.snapshot()["coins"], 100, "Credits never pay mid-level")
	assert_eq_deep(ledger.redeem_bonus_chests(), {"chests": 2, "reward": {"coins": 62}})
	assert_eq_deep(ledger.snapshot(), _state(162, 3))
	assert_eq_deep(ledger.redeem_bonus_chests(), {"chests": 0, "reward": {}})
	var restored: EconomyLedger = EconomyLedger.from_dict(
		JSON.parse_string(JSON.stringify(ledger.snapshot())), _config()
	)
	assert_eq(restored.add_bonus(2), OK)
	assert_eq_deep(restored.redeem_bonus_chests(), {"chests": 1, "reward": {"coins": 31}})
	assert_eq_deep(restored.snapshot(), _state(193, 0))


func test_overflow_failure_retains_counter_wallet_and_credit_for_retry() -> void:
	var ledger: EconomyLedger = EconomyLedger.from_dict(
		_state(WalletSnapshot.MAX_SAFE_COUNT - 20, 5), _config()
	)
	var before: Dictionary = ledger.snapshot()
	assert_eq(ledger.redeem_bonus_chests(), {})
	assert_eq_deep(ledger.snapshot(), before)
	assert_eq(ledger.grant(&"overflow", {"coins": 21, "hint": 1}), ERR_INVALID_DATA)
	assert_eq_deep(ledger.snapshot(), before)
	assert_true(ledger.spend(&"make_room", {"coins": 40}))
	assert_eq_deep(ledger.redeem_bonus_chests(), {"chests": 1, "reward": {"coins": 31}})
	assert_eq_deep(ledger.snapshot(), _state(WalletSnapshot.MAX_SAFE_COUNT - 29, 0))
	var config: Dictionary = _config()
	config["economy.reward.bonus_chest"] = WalletSnapshot.MAX_SAFE_COUNT
	ledger = EconomyLedger.from_dict(_state(0, 10), config)
	before = ledger.snapshot()
	assert_eq(ledger.redeem_bonus_chests(), {})
	assert_eq_deep(ledger.snapshot(), before)
	ledger = EconomyLedger.from_dict(_state(0, WalletSnapshot.MAX_SAFE_COUNT), _config())
	before = ledger.snapshot()
	assert_eq(ledger.add_bonus(1), ERR_INVALID_DATA)
	assert_eq(ledger.add_bonus(0), ERR_INVALID_PARAMETER)
	assert_eq(ledger.add_bonus(-1), ERR_INVALID_PARAMETER)
	assert_eq_deep(ledger.snapshot(), before)


func test_large_exact_integer_division_and_zero_configured_rewards() -> void:
	var config: Dictionary = _config()
	config["bonus.chest.words_required"] = 3
	config["economy.reward.bonus_chest"] = 0
	config["economy.reward.level_complete"] = 0
	var ledger: EconomyLedger = EconomyLedger.from_dict(
		_state(100, WalletSnapshot.MAX_SAFE_COUNT), config
	)
	assert_eq(ledger.grant_reward(&"level_complete"), OK)
	assert_eq_deep(
		ledger.redeem_bonus_chests(), {"chests": 3002399751580330, "reward": {"coins": 0}}
	)
	assert_eq_deep(ledger.snapshot(), _state(100, 1))
	assert_eq_deep(ledger.redeem_bonus_chests(), {"chests": 0, "reward": {}})


func test_invalid_factory_configuration_and_unconfigured_ledger_are_safe() -> void:
	for value: Variant in [-1, true, 0.5, "7", NAN, WalletSnapshot.MAX_SAFE_COUNT + 1]:
		var state: Dictionary = _state()
		state["bonus_counter"] = value
		assert_null(EconomyLedger.from_dict(state, _config()))
	for value: Variant in [null, 0, -1, true, 1.0, WalletSnapshot.MAX_SAFE_COUNT + 1]:
		var config: Dictionary = _config()
		config["bonus.chest.words_required"] = value
		assert_null(EconomyLedger.from_dict(_state(), config))
	var state: Dictionary = _state()
	state["items"]["future_item"] = 4
	assert_null(
		EconomyLedger.from_dict(state, _config()), "Never silently discard an unknown earned item"
	)
	var config: Dictionary = _config()
	config.erase("economy.price.hint")
	assert_null(EconomyLedger.from_dict(_state(), config))
	var empty: EconomyLedger = EconomyLedger.new()
	assert_eq(empty.snapshot(), {})
	assert_false(empty.can_afford({"coins": 1}))
	assert_eq(empty.grant(&"test", {"coins": 1}), ERR_UNCONFIGURED)
	assert_false(empty.spend(&"test", {"coins": 1}))
	assert_eq(empty.grant_reward(&"level_complete"), ERR_UNCONFIGURED)
	assert_eq(empty.add_bonus(1), ERR_UNCONFIGURED)
	assert_eq(empty.redeem_bonus_chests(), {})
