extends GutTest


func _ads_log(fake: AdsFake) -> Array[String]:
	var log: Array[String] = []
	fake.initialized.connect(func() -> void: log.append("initialized"))
	fake.rewarded_loaded.connect(func() -> void: log.append("rewarded_loaded"))
	fake.interstitial_loaded.connect(func() -> void: log.append("interstitial_loaded"))
	fake.ad_opened.connect(func() -> void: log.append("opened"))
	fake.reward_earned.connect(func() -> void: log.append("reward"))
	fake.ad_closed.connect(func() -> void: log.append("closed"))
	fake.ad_failed.connect(func(reason: String) -> void: log.append("failed:" + reason))
	return log


func _consent_log(fake: ConsentFake) -> Array[String]:
	var log: Array[String] = []
	fake.consent_resolved.connect(
		func(state: ConsentAdapter.State) -> void: log.append("ump:%d" % state)
	)
	fake.att_resolved.connect(
		func(status: ConsentAdapter.AttStatus) -> void: log.append("att:%d" % status)
	)
	fake.operation_failed.connect(func() -> void: log.append("error"))
	fake.analytics_resolved.connect(
		func(allowed: bool) -> void: log.append("analytics:%s" % allowed)
	)
	return log


func test_default_manual_preserves_call_arguments_and_direct_signal_delivery() -> void:
	var ads: AdsFake = AdsFake.new()
	var consent: ConsentFake = ConsentFake.new()
	var ad_log: Array[String] = _ads_log(ads)
	var consent_log: Array[String] = _consent_log(consent)
	ads.initialize(ConsentAdapter.State.NOT_REQUIRED)
	ads.load_rewarded()
	ads.show_rewarded()
	ads.load_interstitial()
	ads.show_interstitial()
	consent.request_info()
	consent.show_form_if_required()
	consent.request_att()
	consent.show_privacy_options()
	assert_eq(ad_log.size(), 0)
	assert_eq(consent_log.size(), 0)
	assert_eq(ads.calls.entries.size(), 5)
	assert_eq(ads.calls.entries[0].arguments, [ConsentAdapter.State.NOT_REQUIRED])
	assert_eq(consent.calls.entries.size(), 4)
	assert_false(ads.settle(ads.operation_token()))
	assert_false(consent.settle(consent.operation_token()))
	ads.reward_earned.emit()
	consent.att_resolved.emit(ConsentAdapter.AttStatus.DENIED)
	assert_eq(ad_log, ["reward"])
	assert_eq(consent_log, ["att:3"])


func test_every_ads_control_emits_exact_order_and_no_reward_on_early_close() -> void:
	var cases: Dictionary = {
		&"initialize": {&"ready": ["initialized"], &"error": ["failed:error"]},
		&"load_rewarded":
		{&"ready": ["rewarded_loaded"], &"no_fill": ["failed:no_fill"], &"error": ["failed:error"]},
		&"load_interstitial":
		{
			&"ready": ["interstitial_loaded"],
			&"no_fill": ["failed:no_fill"],
			&"error": ["failed:error"]
		},
		&"show_rewarded":
		{
			&"reward": ["opened", "reward", "closed"],
			&"early_close": ["opened", "closed"],
			&"no_fill": ["failed:no_fill"],
			&"error": ["failed:error"]
		},
		&"show_interstitial":
		{&"shown": ["opened", "closed"], &"no_fill": ["failed:no_fill"], &"error": ["failed:error"]}
	}
	for operation: StringName in cases:
		for outcome: StringName in cases[operation]:
			var fake: AdsFake = AdsFake.new()
			var log: Array[String] = _ads_log(fake)
			assert_eq(fake.set_outcome(operation, outcome), OK)
			if operation == &"initialize":
				fake.initialize(ConsentAdapter.State.OBTAINED)
			else:
				fake.call(operation)
			assert_eq(log, cases[operation][outcome], "%s/%s" % [operation, outcome])
			assert_false(fake.settle(fake.operation_token()))
			assert_eq(fake.calls.entries.size(), 1)
			assert_eq(fake.calls.entries[0].method, str(operation))


func test_every_consent_and_att_control_has_typed_result_and_no_implicit_analytics() -> void:
	var states: Dictionary = {
		&"unknown": 0, &"required": 1, &"not_required": 2, &"obtained": 3, &"error": -1
	}
	for operation: StringName in [
		&"request_info", &"show_form_if_required", &"show_privacy_options"
	]:
		for outcome: StringName in states:
			var fake: ConsentFake = ConsentFake.new()
			var log: Array[String] = _consent_log(fake)
			assert_eq(fake.set_outcome(operation, outcome), OK)
			fake.call(operation)
			assert_eq(log, ["error" if outcome == &"error" else "ump:%d" % states[outcome]])
			assert_false(fake.settle(fake.operation_token()))
			assert_eq(fake.calls.entries[0].method, str(operation))
	var statuses: Dictionary = {
		&"unknown": 0,
		&"not_determined": 1,
		&"restricted": 2,
		&"denied": 3,
		&"authorized": 4,
		&"error": -1
	}
	for outcome: StringName in statuses:
		var fake: ConsentFake = ConsentFake.new()
		var log: Array[String] = _consent_log(fake)
		assert_eq(fake.set_outcome(&"request_att", outcome), OK)
		fake.request_att()
		assert_eq(log, ["error" if outcome == &"error" else "att:%d" % statuses[outcome]])


func test_deferred_settlement_rejects_duplicates_superseded_and_invalid_controls_atomically(
) -> void:
	for fake: RefCounted in [AdsFake.new(), ConsentFake.new()]:
		var ads: bool = fake is AdsFake
		var operation: StringName = &"load_rewarded" if ads else &"request_info"
		var outcome: StringName = &"ready" if ads else &"obtained"
		assert_eq(fake.set_outcome(operation, outcome, false), OK)
		fake.call(operation)
		var first: int = fake.operation_token()
		assert_eq(fake.set_outcome(operation, &"not_an_outcome"), ERR_INVALID_PARAMETER)
		assert_eq(fake.set_outcome(&"not_an_operation", &"manual"), ERR_INVALID_PARAMETER)
		assert_eq(fake.operation_token(), first)
		assert_true(fake.settle(first))
		assert_false(fake.settle(first))
		fake.call(operation)
		var superseded: int = fake.operation_token()
		fake.call(operation)
		assert_false(fake.settle(superseded))
		assert_true(fake.settle(fake.operation_token()))
		fake.call(operation)
		var reset_token: int = fake.operation_token()
		fake.reset()
		assert_eq(fake.operation_token(), 0)
		assert_false(fake.settle(reset_token))
		fake.call(operation)
		assert_false(fake.settle(fake.operation_token()), "Reset restored manual mode")
		assert_eq(fake.calls.entries.size(), 1)


func test_reconfiguration_cancels_pending_output_without_erasing_log() -> void:
	var ads: AdsFake = AdsFake.new()
	var consent: ConsentFake = ConsentFake.new()
	assert_eq(ads.set_outcome(&"show_rewarded", &"reward", false), OK)
	ads.show_rewarded()
	var ad_token: int = ads.operation_token()
	assert_eq(ads.set_outcome(&"show_rewarded", &"early_close"), OK)
	assert_false(ads.settle(ad_token))
	assert_eq(ads.calls.entries.size(), 1)
	assert_eq(consent.set_outcome(&"request_info", &"obtained", false), OK)
	consent.request_info()
	var info_token: int = consent.operation_token()
	assert_eq(consent.set_outcome(&"request_info", &"required"), OK)
	assert_false(consent.settle(info_token))
	assert_false(consent.resolve_analytics(info_token, true))
	assert_eq(consent.calls.entries.size(), 1)


func test_reentrant_reset_after_open_and_new_operation_after_reward_cancel_remaining_callbacks(
) -> void:
	var fake: AdsFake = AdsFake.new()
	var log: Array[String] = _ads_log(fake)
	assert_eq(fake.set_outcome(&"show_rewarded", &"reward"), OK)
	fake.ad_opened.connect(fake.reset, CONNECT_ONE_SHOT)
	fake.show_rewarded()
	assert_eq(log, ["opened"])
	assert_eq(fake.set_outcome(&"show_rewarded", &"reward"), OK)
	assert_eq(fake.set_outcome(&"load_interstitial", &"ready"), OK)
	fake.reward_earned.connect(fake.load_interstitial, CONNECT_ONE_SHOT)
	log.clear()
	fake.show_rewarded()
	assert_eq(log, ["opened", "reward", "interstitial_loaded"])


func test_explicit_analytics_decision_is_once_per_current_ump_operation_and_can_be_revoked(
) -> void:
	var fake: ConsentFake = ConsentFake.new()
	var log: Array[String] = _consent_log(fake)
	assert_false(fake.resolve_analytics(0, true))
	assert_eq(fake.set_outcome(&"request_info", &"obtained"), OK)
	fake.request_info()
	assert_eq(log, ["ump:3"])
	var token: int = fake.operation_token()
	assert_true(fake.resolve_analytics(token, true))
	assert_false(fake.resolve_analytics(token, false))
	fake.show_privacy_options()
	assert_true(fake.resolve_analytics(fake.operation_token(), false))
	assert_eq(log, ["ump:3", "analytics:true", "analytics:false"])
	fake.request_att()
	assert_false(fake.resolve_analytics(fake.operation_token(), true))
	assert_false(fake.resolve_analytics(token, true))
