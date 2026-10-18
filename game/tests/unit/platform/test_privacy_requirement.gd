extends GutTest


func _requirements(fake: ConsentFake) -> Array[int]:
	var observed: Array[int] = []
	fake.privacy_options_requirement_changed.connect(
		func(requirement: ConsentAdapter.PrivacyRequirement) -> void:
			assert_eq(fake.privacy_options_requirement(), requirement)
			observed.append(requirement)
	)
	return observed


func test_default_is_unknown_without_provider_work_or_signals() -> void:
	var adapter: ConsentAdapter = ConsentAdapter.new()
	var fake: ConsentFake = ConsentFake.new()
	watch_signals(fake)
	assert_eq(adapter.privacy_options_requirement(), ConsentAdapter.PrivacyRequirement.UNKNOWN)
	assert_eq(fake.privacy_options_requirement(), ConsentAdapter.PrivacyRequirement.UNKNOWN)
	assert_eq(fake.calls.entries.size(), 0)
	assert_eq(fake.operation_token(), 0)
	assert_signal_not_emitted(fake, "privacy_options_requirement_changed")
	assert_signal_not_emitted(fake, "consent_resolved")
	assert_signal_not_emitted(fake, "analytics_resolved")


func test_all_requirement_transitions_notify_after_update_and_duplicates_are_silent() -> void:
	var fake: ConsentFake = ConsentFake.new()
	var observed: Array[int] = _requirements(fake)
	for requirement: int in [
		ConsentAdapter.PrivacyRequirement.NOT_REQUIRED,
		ConsentAdapter.PrivacyRequirement.REQUIRED,
		ConsentAdapter.PrivacyRequirement.UNKNOWN,
		ConsentAdapter.PrivacyRequirement.REQUIRED,
		ConsentAdapter.PrivacyRequirement.NOT_REQUIRED,
		ConsentAdapter.PrivacyRequirement.UNKNOWN
	]:
		var count: int = observed.size()
		assert_eq(fake.set_privacy_options_requirement(requirement), OK)
		assert_eq(observed.size(), count + 1)
		assert_eq(observed.back(), requirement)
		assert_eq(fake.set_privacy_options_requirement(requirement), OK)
		assert_eq(observed.size(), count + 1)
	assert_eq(fake.calls.entries.size(), 0)
	assert_eq(fake.operation_token(), 0)


func test_invalid_requirement_preserves_pending_outcome_token_log_and_notifications() -> void:
	var fake: ConsentFake = ConsentFake.new()
	var observed: Array[int] = _requirements(fake)
	assert_eq(fake.set_privacy_options_requirement(ConsentAdapter.PrivacyRequirement.REQUIRED), OK)
	assert_eq(fake.set_outcome(&"show_privacy_options", &"obtained", false), OK)
	fake.show_privacy_options()
	var token: int = fake.operation_token()
	var calls: Array = fake.calls.entries.duplicate(true)
	for invalid: int in [-1, 3, 1000000]:
		assert_eq(fake.set_privacy_options_requirement(invalid), ERR_INVALID_PARAMETER)
		assert_eq(fake.privacy_options_requirement(), ConsentAdapter.PrivacyRequirement.REQUIRED)
		assert_eq(fake.operation_token(), token)
		assert_eq(fake.calls.entries, calls)
		assert_eq(observed.size(), 1)
	watch_signals(fake)
	assert_true(fake.settle(token))
	assert_signal_emitted_with_parameters(fake, "consent_resolved", [ConsentAdapter.State.OBTAINED])
	assert_false(fake.settle(token))
	assert_eq(fake.privacy_options_requirement(), ConsentAdapter.PrivacyRequirement.REQUIRED)


func test_ump_and_att_outcomes_never_infer_privacy_requirement() -> void:
	for requirement: int in ConsentAdapter.PrivacyRequirement.values():
		var fake: ConsentFake = ConsentFake.new()
		assert_eq(fake.set_privacy_options_requirement(requirement), OK)
		var observed: Array[int] = _requirements(fake)
		for operation: StringName in [
			&"request_info", &"show_form_if_required", &"show_privacy_options"
		]:
			for outcome: StringName in [
				&"unknown", &"required", &"not_required", &"obtained", &"error"
			]:
				assert_eq(fake.set_outcome(operation, outcome), OK)
				fake.call(operation)
				assert_eq(fake.privacy_options_requirement(), requirement)
		for outcome: StringName in [
			&"unknown", &"not_determined", &"restricted", &"denied", &"authorized", &"error"
		]:
			assert_eq(fake.set_outcome(&"request_att", outcome), OK)
			fake.request_att()
			assert_eq(fake.privacy_options_requirement(), requirement)
		assert_eq(observed.size(), 0)


func test_requirement_updates_do_not_resolve_or_cancel_operations_or_grant_analytics() -> void:
	var fake: ConsentFake = ConsentFake.new()
	assert_eq(fake.set_outcome(&"show_privacy_options", &"obtained", false), OK)
	fake.show_privacy_options()
	var token: int = fake.operation_token()
	watch_signals(fake)
	for requirement: int in ConsentAdapter.PrivacyRequirement.values():
		assert_eq(fake.set_privacy_options_requirement(requirement), OK)
		assert_eq(fake.operation_token(), token)
	assert_eq(fake.calls.entries.size(), 1)
	assert_signal_not_emitted(fake, "consent_resolved")
	assert_signal_not_emitted(fake, "att_resolved")
	assert_signal_not_emitted(fake, "operation_failed")
	assert_signal_not_emitted(fake, "analytics_resolved")
	assert_true(fake.resolve_analytics(token, false))
	assert_signal_emitted_with_parameters(fake, "analytics_resolved", [false])
	assert_true(fake.settle(token))
	assert_signal_emitted_with_parameters(fake, "consent_resolved", [ConsentAdapter.State.OBTAINED])
	assert_false(fake.resolve_analytics(token, true))
	assert_eq(fake.privacy_options_requirement(), ConsentAdapter.PrivacyRequirement.REQUIRED)


func test_explicit_analytics_decision_does_not_change_requirement() -> void:
	for allowed: bool in [false, true]:
		var fake: ConsentFake = ConsentFake.new()
		assert_eq(
			fake.set_privacy_options_requirement(ConsentAdapter.PrivacyRequirement.NOT_REQUIRED), OK
		)
		var observed: Array[int] = _requirements(fake)
		fake.request_info()
		assert_true(fake.resolve_analytics(fake.operation_token(), allowed))
		assert_eq(
			fake.privacy_options_requirement(), ConsentAdapter.PrivacyRequirement.NOT_REQUIRED
		)
		assert_eq(observed.size(), 0)


func test_reset_invalidates_pending_work_and_returns_unknown_once() -> void:
	var fake: ConsentFake = ConsentFake.new()
	assert_eq(fake.set_privacy_options_requirement(ConsentAdapter.PrivacyRequirement.REQUIRED), OK)
	assert_eq(fake.set_outcome(&"show_privacy_options", &"obtained", false), OK)
	fake.show_privacy_options()
	var token: int = fake.operation_token()
	var observed: Array[int] = _requirements(fake)
	watch_signals(fake)
	fake.reset()
	assert_eq(fake.privacy_options_requirement(), ConsentAdapter.PrivacyRequirement.UNKNOWN)
	assert_eq(observed, [ConsentAdapter.PrivacyRequirement.UNKNOWN])
	assert_eq(fake.operation_token(), 0)
	assert_eq(fake.calls.entries.size(), 0)
	assert_false(fake.settle(token))
	assert_false(fake.resolve_analytics(token, true))
	fake.reset()
	assert_eq(observed.size(), 1)
	fake.show_privacy_options()
	assert_false(fake.settle(fake.operation_token()), "reset clears controlled outcome to manual")
	assert_signal_not_emitted(fake, "consent_resolved")
	assert_signal_not_emitted(fake, "analytics_resolved")
	assert_signal_not_emitted(fake, "att_resolved")
	assert_signal_not_emitted(fake, "operation_failed")


func test_requirement_is_instance_local_and_command_acceptance_does_not_change_it() -> void:
	var first: ConsentFake = ConsentFake.new()
	var second: ConsentFake = ConsentFake.new()
	assert_eq(first.set_privacy_options_requirement(ConsentAdapter.PrivacyRequirement.REQUIRED), OK)
	second.show_privacy_options()
	assert_eq(second.calls.entries.size(), 1)
	assert_eq(second.privacy_options_requirement(), ConsentAdapter.PrivacyRequirement.UNKNOWN)
	second.reset()
	assert_eq(first.privacy_options_requirement(), ConsentAdapter.PrivacyRequirement.REQUIRED)
	first.show_privacy_options()
	assert_eq(first.privacy_options_requirement(), ConsentAdapter.PrivacyRequirement.REQUIRED)
