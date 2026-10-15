extends GutTest


func _config() -> Dictionary:
	return {
		"ads.interstitial.first_slot": 16,
		"ads.interstitial.min_levels_between": 4,
		"ads.interstitial.min_seconds_between": 180,
		"ads.interstitial.session_grace_seconds": 120,
		"ads.interstitial.purchase_grace_levels": 10,
		"onboarding.max_prompts_per_session": 1
	}


func _state() -> Dictionary:
	return {
		"context": "campaign_continue",
		"sdk_ready": true,
		"ad_loaded": true,
		"remove_forced_ads": false,
		"completed_slot": 16,
		"last_interstitial_slot": -1,
		"last_interstitial_seconds": -1,
		"session_start_seconds": 0,
		"last_purchase_slot": -1,
		"prompts_used": 0
	}


func test_first_eligible_slot_and_session_grace_boundary() -> void:
	assert_false(AdPolicy.should_show_interstitial(_state(), _config(), 119))
	assert_true(AdPolicy.should_show_interstitial(_state(), _config(), 120))
	var state: Dictionary = _state()
	state["completed_slot"] = 15
	assert_false(AdPolicy.should_show_interstitial(state, _config(), 1000))


func test_sdk_load_and_entitlement_conditions() -> void:
	for key: String in ["sdk_ready", "ad_loaded"]:
		var state: Dictionary = _state()
		state[key] = false
		assert_false(AdPolicy.should_show_interstitial(state, _config(), 1000))
	var owned: Dictionary = _state()
	owned["remove_forced_ads"] = true
	assert_false(AdPolicy.should_show_interstitial(owned, _config(), 1000))


func test_never_during_level_daily_open_or_non_campaign() -> void:
	for mode: String in ["level", "daily", "app_open", "home", ""]:
		var state: Dictionary = _state()
		state["context"] = mode
		assert_false(AdPolicy.should_show_interstitial(state, _config(), 1000))


func test_min_levels_between_is_inclusive() -> void:
	var state: Dictionary = _state()
	state["last_interstitial_slot"] = 16
	state["completed_slot"] = 19
	assert_false(AdPolicy.should_show_interstitial(state, _config(), 1000))
	state["completed_slot"] = 20
	assert_true(AdPolicy.should_show_interstitial(state, _config(), 1000))


func test_min_seconds_between_is_inclusive() -> void:
	var state: Dictionary = _state()
	state["last_interstitial_seconds"] = 900
	assert_false(AdPolicy.should_show_interstitial(state, _config(), 1079))
	assert_true(AdPolicy.should_show_interstitial(state, _config(), 1080))


func test_purchase_grace_and_never_purchased_sentinel() -> void:
	var state: Dictionary = _state()
	state["completed_slot"] = 25
	state["last_purchase_slot"] = 16
	assert_false(AdPolicy.should_show_interstitial(state, _config(), 1000))
	state["completed_slot"] = 26
	assert_true(AdPolicy.should_show_interstitial(state, _config(), 1000))
	state["last_purchase_slot"] = -1
	assert_true(AdPolicy.should_show_interstitial(state, _config(), 1000))


func test_prompt_cap_and_skip_do_not_consume_budget() -> void:
	var config: Dictionary = _config()
	assert_true(AdPolicy.can_show_prompt(&"interstitial", 0, config))
	assert_false(AdPolicy.can_show_prompt(&"interstitial", 1, config))
	assert_eq(AdPolicy.next_prompt_count(&"interstitial", 1, config), 1)
	assert_eq(AdPolicy.next_prompt_count(&"offer", 0, config), 1)
	var state: Dictionary = _state()
	state["prompts_used"] = 1
	assert_false(AdPolicy.should_show_interstitial(state, config, 1000))
	config["onboarding.max_prompts_per_session"] = 0
	assert_false(AdPolicy.can_show_prompt(&"offer", 0, config))


func test_exempt_consent_att_coach_and_user_actions() -> void:
	var config: Dictionary = _config()
	config["onboarding.max_prompts_per_session"] = 0
	for kind: StringName in [&"consent", &"att", &"coach_mark", &"explicit_action"]:
		assert_true(AdPolicy.can_show_prompt(kind, 9, config))
		assert_eq(AdPolicy.next_prompt_count(kind, 9, config), 9)
	assert_false(AdPolicy.can_show_prompt(&"unknown", 0, config))


func test_missing_malformed_time_and_config_fail_closed() -> void:
	var state: Dictionary = _state()
	var config: Dictionary = _config()
	config["ads.interstitial.first_slot"] = "16"
	assert_false(AdPolicy.should_show_interstitial(state, config, 1000))
	config = _config()
	for key: String in [
		"completed_slot", "last_interstitial_slot", "last_interstitial_seconds",
		"session_start_seconds", "last_purchase_slot"
	]:
		var bad: Dictionary = state.duplicate()
		bad[key] = "bad"
		assert_false(AdPolicy.should_show_interstitial(bad, config, 1000))
	state["session_start_seconds"] = 1100
	assert_false(AdPolicy.should_show_interstitial(state, config, 1000))
