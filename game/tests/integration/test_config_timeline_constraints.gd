extends GutTest

const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const UNLOCK_KEYS: Array[StringName] = [
	&"unlocks.shuffle_slot",
	&"unlocks.bonus_meter_slot",
	&"unlocks.hint_slot",
	&"unlocks.journey_slot",
	&"unlocks.reveal_slot",
	&"unlocks.double_reward_slot",
	&"unlocks.daily_slot"
]
const OFFER_KEYS: Array[StringName] = [
	&"unlocks.hint_slot",
	&"unlocks.double_reward_slot",
	&"ads.interstitial.first_slot"
]
const CONSENT_KEYS: Array[StringName] = [
	&"consent.ump_after_slot",
	&"consent.att_after_slot"
]


func _shipped() -> Dictionary:
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	add_child_autofree(config)
	assert_eq(config.load(), OK)
	var values: Dictionary = {}
	for key: StringName in CONSENT_KEYS:
		assert_true(config.has_key(key), str(key))
		values[str(key)] = config.get_int(key)
	for key: StringName in UNLOCK_KEYS:
		assert_true(config.has_key(key), str(key))
		values[str(key)] = config.get_int(key)
	assert_true(config.has_key(&"ads.interstitial.first_slot"))
	values["ads.interstitial.first_slot"] = config.get_int(&"ads.interstitial.first_slot")
	return values


func _consent_before_ad_offers(values: Dictionary) -> bool:
	var first_offer: int = int(values[str(OFFER_KEYS[0])])
	for key: StringName in OFFER_KEYS:
		first_offer = mini(first_offer, int(values[str(key)]))
	var ump: int = int(values["consent.ump_after_slot"])
	var att: int = int(values["consent.att_after_slot"])
	return ump <= att and att < first_offer


func _unlocks_monotonic(values: Dictionary) -> bool:
	for index: int in range(UNLOCK_KEYS.size() - 1):
		var previous: int = int(values[str(UNLOCK_KEYS[index])])
		var following: int = int(values[str(UNLOCK_KEYS[index + 1])])
		if previous > following:
			return false
	return int(values["unlocks.daily_slot"]) < int(values["ads.interstitial.first_slot"])


func test_shipped_config_obeys_consent_and_onboarding_constraints() -> void:
	var values: Dictionary = _shipped()
	assert_true(_consent_before_ad_offers(values))
	assert_true(_unlocks_monotonic(values))
	assert_eq(values["consent.ump_after_slot"], 1)
	assert_eq(values["consent.att_after_slot"], 6)
	assert_eq(values["unlocks.shuffle_slot"], 2)
	assert_eq(values["unlocks.bonus_meter_slot"], 5)
	assert_eq(values["unlocks.hint_slot"], 7)
	assert_eq(values["unlocks.journey_slot"], 10)
	assert_eq(values["unlocks.reveal_slot"], 12)
	assert_eq(values["unlocks.double_reward_slot"], 12)
	assert_eq(values["unlocks.daily_slot"], 15)
	assert_eq(values["ads.interstitial.first_slot"], 16)


func test_consent_equal_slots_are_allowed_but_reversed_order_is_not() -> void:
	var values: Dictionary = _shipped()
	values["consent.ump_after_slot"] = values["consent.att_after_slot"]
	assert_true(_consent_before_ad_offers(values))
	values["consent.ump_after_slot"] = int(values["consent.att_after_slot"]) + 1
	assert_false(_consent_before_ad_offers(values))


func test_att_must_precede_each_of_the_three_ad_offer_thresholds() -> void:
	var values: Dictionary = _shipped()
	for key: StringName in OFFER_KEYS:
		var broken: Dictionary = values.duplicate(true)
		broken[str(key)] = broken["consent.att_after_slot"]
		assert_false(_consent_before_ad_offers(broken), str(key))


func test_every_unlock_edge_rejects_reversal_and_accepts_ties() -> void:
	var values: Dictionary = _shipped()
	for index: int in range(UNLOCK_KEYS.size() - 1):
		var previous: StringName = UNLOCK_KEYS[index]
		var following: StringName = UNLOCK_KEYS[index + 1]
		var same: Dictionary = values.duplicate(true)
		same[str(following)] = same[str(previous)]
		assert_true(_unlocks_monotonic(same), str(following))
		var reversed: Dictionary = values.duplicate(true)
		reversed[str(following)] = int(values[str(previous)]) - 1
		assert_false(_unlocks_monotonic(reversed), str(following))
	var too_early: Dictionary = values.duplicate(true)
	too_early["ads.interstitial.first_slot"] = too_early["unlocks.daily_slot"]
	assert_false(_unlocks_monotonic(too_early))


func test_remote_config_rejects_all_consent_unlock_and_first_ad_slot_keys() -> void:
	var registry: ConfigRegistry = ConfigRegistry.new()
	for prefix: String in ["consent", "unlocks", "ads"]:
		var path: String = "res://data/config/" + prefix + ".json"
		var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_true(document is Dictionary, path)
		assert_eq(registry.append_document(prefix, document as Dictionary), OK)
	var protected: Array[StringName] = CONSENT_KEYS.duplicate()
	protected.append_array(UNLOCK_KEYS)
	protected.append(&"ads.interstitial.first_slot")
	var proposed: Dictionary = {}
	for key: StringName in protected:
		var definition: Dictionary = registry.definition(key)
		assert_eq(definition["type"], "int", str(key))
		assert_false(definition["remote"], str(key))
		proposed[str(key)] = definition["default"]
	var remote: Dictionary = {"version": 1, "values": proposed, "experiments": []}
	var checked: Dictionary = RemoteConfigContract.validate(remote, registry, "install-t0256")
	assert_eq(checked["overrides"], {})
	assert_eq(checked["rejected"].size(), protected.size())
	for key: StringName in protected:
		assert_true(checked["rejected"].has(str(key)), str(key))
