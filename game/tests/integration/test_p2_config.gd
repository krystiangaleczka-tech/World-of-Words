extends GutTest

const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const EXPECTED: Dictionary = {
	"consent.ump_after_slot": 1,
	"consent.att_after_slot": 6,
	"ads.interstitial.first_slot": 16,
	"ads.interstitial.min_levels_between": 4,
	"ads.interstitial.min_seconds_between": 180,
	"ads.interstitial.session_grace_seconds": 120,
	"ads.interstitial.purchase_grace_levels": 10,
	"ads.rewarded.hint.enabled": true,
	"ads.rewarded.double.enabled": true,
	"ads.rewarded.shop_coins.daily_cap": 3,
	"economy.reward.level_complete": 25,
	"economy.reward.double_multiplier": 2,
	"economy.reward.bonus_chest": 100,
	"economy.reward.rewarded_hint": 1,
	"economy.reward.rewarded_coins": 100,
	"economy.reward.daily": 100,
	"economy.grant.onboarding_hints": 3,
	"economy.price.hint": 100,
	"economy.price.reveal": 250,
	"economy.journal.max_entries": 200,
	"bonus.chest.words_required": 10,
	"meta.stars.per_level": 1,
	"meta.postcard.pieces": 4,
	"meta.postcard.piece_star_cost": 12,
	"onboarding.max_prompts_per_session": 1,
	"iap.coins_s.amount": 1000,
	"config.remote.timeout_ms": 3000
}


func test_shipped_defaults_types_and_reward_table() -> void:
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	add_child_autofree(config)
	assert_eq(config.load(), OK)
	var values: Dictionary = {}
	for key: String in EXPECTED:
		assert_true(config.has_key(StringName(key)), key)
		if EXPECTED[key] is bool:
			assert_eq(config.get_bool(StringName(key)), EXPECTED[key], key)
		else:
			values[key] = config.get_int(StringName(key))
			assert_eq(values[key], EXPECTED[key], key)
	var rewards: RewardTable = RewardTable.from_config(values)
	assert_not_null(rewards)
	assert_eq_deep(rewards.price(&"hint"), {"coins": 100})
	assert_eq_deep(rewards.reward(&"level_complete", true), {"coins": 50})
	assert_eq(config.get_int(&"hint.offer_idle_seconds"), 45)
	assert_eq(config.get_int(&"hint.offer_invalid_streak"), 5)
	var unlocks: Dictionary = {
		"shuffle": 2,
		"bonus_meter": 5,
		"hint": 7,
		"journey": 10,
		"reveal": 12,
		"double_reward": 12,
		"daily": 15
	}
	for feature: String in unlocks:
		assert_eq(config.get_int(StringName("unlocks." + feature + "_slot")), unlocks[feature])
	assert_lt(config.get_int(&"consent.ump_after_slot"), config.get_int(&"consent.att_after_slot"))
	assert_lt(config.get_int(&"consent.att_after_slot"), config.get_int(&"unlocks.hint_slot"))
	assert_lt(
		config.get_int(&"consent.att_after_slot"), config.get_int(&"ads.interstitial.first_slot")
	)


func test_added_metadata_and_bounds_are_validated() -> void:
	var registry: ConfigRegistry = ConfigRegistry.new()
	for prefix: String in [
		"economy", "bonus", "ads", "consent", "meta", "onboarding", "iap", "config"
	]:
		var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/config/" + prefix + ".json")
		)
		assert_eq(registry.append_document(prefix, document), OK)
	for key: String in EXPECTED:
		var definition: Dictionary = registry.definition(StringName(key))
		assert_eq(
			definition["remote"],
			(
				key
				in [
					"ads.interstitial.min_levels_between",
					"ads.interstitial.min_seconds_between",
					"ads.interstitial.session_grace_seconds",
					"ads.interstitial.purchase_grace_levels"
				]
			)
		)
		assert_eq(definition["default"], EXPECTED[key])
		if not EXPECTED[key] is bool:
			assert_between(EXPECTED[key], definition["range"][0], definition["range"][1])
