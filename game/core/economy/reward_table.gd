class_name RewardTable
extends RefCounted
## @api Pure configured prices/rewards; inject validated config values, never read an autoload.

const KEYS: Array[String] = [
	"economy.price.hint",
	"economy.price.reveal",
	"economy.reward.level_complete",
	"economy.reward.double_multiplier",
	"economy.reward.bonus_chest",
	"economy.reward.rewarded_hint",
	"economy.reward.rewarded_coins",
	"economy.reward.daily",
	"economy.grant.onboarding_hints"
]
const COIN_SOURCES: Array[StringName] = [
	&"level_complete", &"bonus_chest", &"rewarded_coins", &"daily"
]
var _values: Dictionary = {}


## @api Atomic construction, extra unrelated config keys ignored.
static func from_config(values: Dictionary) -> RewardTable:
	for key: String in KEYS:
		var value: Variant = values.get(key)
		if not value is int or value < 0 or value > WalletSnapshot.MAX_SAFE_COUNT:
			return null
		if (key.begins_with("economy.price.") or key.ends_with("double_multiplier")) and value == 0:
			return null
	var table: RewardTable = RewardTable.new()
	for key: String in KEYS:
		table._values[key] = values[key]
	return table


## @api Return flat price amounts; unknown/unconfigured tool returns {}.
func price(tool: StringName) -> Dictionary:
	if _values.is_empty() or tool not in [&"hint", &"reveal"]:
		return {}
	return {"coins": _values["economy.price." + str(tool)]}


## @api Double only the base level reward; unsupported source/flag or overflow returns {}.
func reward(source: StringName, double_level: bool = false) -> Dictionary:
	if _values.is_empty() or (double_level and source != &"level_complete"):
		return {}
	if source in COIN_SOURCES:
		var coins: int = _values["economy.reward." + str(source)]
		var multiplier: int = _values["economy.reward.double_multiplier"] if double_level else 1
		@warning_ignore("integer_division")
		if coins > WalletSnapshot.MAX_SAFE_COUNT / multiplier:
			return {}
		return {"coins": coins * multiplier}
	if source == &"rewarded_hint":
		return {"hint": _values["economy.reward.rewarded_hint"]}
	if source == &"onboarding_hints":
		return {"hint": _values["economy.grant.onboarding_hints"]}
	return {}
