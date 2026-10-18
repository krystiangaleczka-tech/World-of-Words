extends GutTest

const SERVICE: Script = preload("res://services/monetization.gd")
const SAVE: Script = preload("res://services/save.gd")
const CONFIG: Script = preload("res://services/config.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const EVENTS: Script = preload("res://services/events.gd")
const FIXTURE: Script = preload("res://tests/integration/test_iap_settlement.gd")
const PATH: String = "user://t0344-privacy-operation.json"
const REQUIRED: int = ConsentAdapter.PrivacyRequirement.REQUIRED

var service: SERVICE
var save: SAVE
var config: CONFIG
var economy: ECONOMY
var events: EVENTS
var consent: ConsentFake
var ads: AdsFake
var store: IapFake
var storage: FIXTURE.InterruptedStorage


func before_each() -> void:
	_clean()
	service = SERVICE.new()
	save = SAVE.new()
	config = CONFIG.new()
	economy = ECONOMY.new()
	events = EVENTS.new()
	for node: Node in [save, config, economy, events, service]:
		add_child(node)
	var clock: Clock = FIXTURE.FixedClock.new()
	save.initialize(clock)
	economy.initialize(clock)
	service.initialize(clock)
	storage = FIXTURE.InterruptedStorage.new(PATH)
	save.configure(storage, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert_eq(save.load(), OK)
	assert_eq(config.load(), OK)
	economy.configure(save, config, events)
	consent = ConsentFake.new()
	ads = AdsFake.new()
	store = IapFake.new()
	assert_eq(service.configure(save, config, events, consent, ads, false), OK)
	watch_signals(service)
	watch_signals(events)


func after_each() -> void:
	for node: Node in [service, economy, save, events, config]:
		if is_instance_valid(node):
			node.free()
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _required() -> void:
	assert_eq(consent.set_privacy_options_requirement(REQUIRED), OK)


func _iap() -> void:
	assert_eq(service.configure_iap(economy, store), OK)


func _all_blocked() -> void:
	var snapshot: Dictionary = service.privacy_snapshot()
	assert_eq(service.request_privacy_options(), ERR_BUSY)
	assert_eq(
		service.configure(save, config, events, ConsentFake.new(), AdsFake.new(), false), ERR_BUSY
	)
	assert_eq(service.configure_iap(economy, IapFake.new()), ERR_BUSY)
	assert_eq(service.start_session(), ERR_BUSY)
	assert_eq(service.before_next_level(6), ERR_BUSY)
	assert_eq(service.request_products(), ERR_BUSY)
	assert_eq(service.purchase(FIXTURE.REMOVE), ERR_BUSY)
	assert_eq(service.restore_purchases(), ERR_BUSY)
	assert_eq(service.process_unfinished_transactions(), ERR_BUSY)
	assert_eq(service.retry_restore_settlement(), ERR_BUSY)
	assert_eq(
		service.request_rewarded(&"hint", economy.grant.bind(&"rewarded_hint", {"hint": 1})),
		ERR_BUSY
	)
	assert_eq(service.request_shop_reward(), ERR_BUSY)
	assert_eq(service.privacy_snapshot(), snapshot, "rejected commands retain result")


func test_defaults_exact_owner_and_requirement_observation_without_dispatch() -> void:
	var fresh: SERVICE = SERVICE.new()
	add_child(fresh)
	assert_eq(fresh.request_privacy_options(), ERR_UNCONFIGURED)
	assert_eq(fresh.privacy_snapshot().state, &"unavailable")
	assert_false(fresh.privacy_owner_matches(save))
	fresh.free()
	assert_true(service.privacy_owner_matches(save), "IAP binding is not required")
	assert_false(service.privacy_owner_matches(config))
	assert_false(service.privacy_owner_matches(null))
	assert_eq(service.privacy_snapshot().requirement, &"unknown")
	assert_false(service.privacy_snapshot().available)
	assert_eq(service.request_privacy_options(), ERR_UNAVAILABLE)
	var revision: int = service.privacy_snapshot().revision
	assert_eq(
		consent.set_privacy_options_requirement(ConsentAdapter.PrivacyRequirement.NOT_REQUIRED), OK
	)
	assert_eq(service.privacy_snapshot().requirement, &"not_required")
	assert_eq(service.request_privacy_options(), ERR_UNAVAILABLE)
	_required()
	assert_gt(service.privacy_snapshot().revision, revision)
	assert_true(service.privacy_snapshot().available)
	var copied: Dictionary = service.privacy_snapshot()
	copied.state = &"completed"
	copied.available = false
	assert_eq(service.privacy_snapshot().state, &"idle")
	assert_true(service.privacy_snapshot().available)
	assert_eq(consent.calls.entries.size(), 0)
	assert_eq(ads.calls.entries.size(), 0)


func test_acceptance_is_not_completion_and_only_first_dedicated_terminal_wins() -> void:
	_required()
	var document: Dictionary = save.committed_view()
	assert_eq(service.request_privacy_options(), OK)
	assert_eq(service.privacy_snapshot().state, &"requested")
	assert_eq(consent.calls.entries.size(), 1)
	assert_eq(consent.calls.entries[0].method, "show_privacy_options")
	_all_blocked()
	for state: ConsentAdapter.State in ConsentAdapter.State.values():
		consent.consent_resolved.emit(state)
		assert_eq(service.privacy_snapshot().state, &"requested")
	consent.operation_failed.emit()
	assert_eq(
		service.privacy_snapshot().state, &"requested", "legacy signal is not privacy terminal"
	)
	consent.privacy_options_completed.emit(OK)
	assert_eq(service.privacy_snapshot().state, &"completed")
	var completed: Dictionary = service.privacy_snapshot()
	consent.privacy_options_completed.emit(FAILED)
	service.expire_privacy_options()
	assert_eq(service.privacy_snapshot(), completed)
	assert_eq(save.committed_view(), document)
	assert_signal_not_emitted(events, "consent_changed")
	assert_signal_not_emitted(service, "continuation_ready")
	assert_eq(ads.calls.entries.size(), 0)
	assert_eq(store.calls.entries.size(), 0)


func test_synchronous_fake_success_error_and_unknown_are_explicit_terminal_results() -> void:
	_required()
	for outcome: StringName in [&"obtained", &"required", &"not_required", &"error", &"unknown"]:
		assert_eq(consent.set_outcome(&"show_privacy_options", outcome), OK)
		var seen: Array[StringName] = []
		var observe: Callable = func() -> void: seen.append(service.privacy_snapshot().state)
		service.privacy_changed.connect(observe)
		assert_eq(service.request_privacy_options(), OK)
		service.privacy_changed.disconnect(observe)
		var error: Error = FAILED if outcome == &"error" else OK
		if outcome == &"unknown":
			error = ERR_INVALID_DATA
		assert_eq(service.privacy_snapshot().error, error)
		assert_eq(seen, [&"requested", &"completed" if error == OK else &"failed"])
		assert_false(consent.settle(consent.operation_token()))
	assert_signal_not_emitted(events, "consent_changed")
	assert_eq(ads.calls.entries.size(), 0)


func test_timeout_stops_wait_and_old_results_cannot_complete_explicit_retry() -> void:
	_required()
	assert_eq(consent.set_outcome(&"show_privacy_options", &"obtained", false), OK)
	assert_eq(service.request_privacy_options(), OK)
	var old_token: int = consent.operation_token()
	var timer: Timer
	for child: Node in service.get_children():
		if child is Timer:
			timer = child
	assert_not_null(timer)
	assert_true(timer.one_shot)
	assert_true(timer.ignore_time_scale)
	assert_eq(timer.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(timer.wait_time, AdPresentation.OPERATION_TIMEOUT_SECONDS)
	assert_false(timer.is_stopped())
	timer.timeout.emit()
	assert_true(timer.is_stopped())
	assert_eq(service.privacy_snapshot().state, &"unknown")
	assert_eq(service.privacy_snapshot().error, ERR_TIMEOUT)
	consent.privacy_options_completed.emit(OK)
	assert_eq(service.privacy_snapshot().state, &"unknown")
	assert_eq(service.request_privacy_options(), OK)
	assert_false(consent.settle(old_token))
	assert_true(consent.settle(consent.operation_token()))
	assert_eq(service.privacy_snapshot().state, &"completed")
	assert_eq(consent.calls.entries.size(), 2)


func test_requirement_changes_neither_settle_nor_cancel_a_pending_form() -> void:
	_required()
	assert_eq(service.request_privacy_options(), OK)
	assert_eq(
		consent.set_privacy_options_requirement(ConsentAdapter.PrivacyRequirement.NOT_REQUIRED), OK
	)
	assert_false(service.privacy_snapshot().available)
	assert_eq(service.privacy_snapshot().state, &"requested")
	assert_eq(service.request_privacy_options(), ERR_BUSY)
	consent.privacy_options_completed.emit(OK)
	assert_eq(service.privacy_snapshot().state, &"completed")
	assert_eq(service.request_privacy_options(), ERR_UNAVAILABLE)
	assert_eq(consent.calls.entries.size(), 1)


func test_only_explicit_analytics_decisions_relay_including_before_session_start() -> void:
	_required()
	assert_eq(service.request_privacy_options(), OK)
	consent.consent_resolved.emit(ConsentAdapter.State.OBTAINED)
	assert_signal_not_emitted(events, "consent_changed")
	assert_true(consent.resolve_analytics(consent.operation_token(), false))
	assert_signal_emitted_with_parameters(events, "consent_changed", [false])
	consent.privacy_options_completed.emit(OK)
	assert_signal_emit_count(events, "consent_changed", 1)
	assert_eq(service.request_privacy_options(), OK)
	consent.privacy_options_completed.emit(OK)
	assert_true(consent.resolve_analytics(consent.operation_token(), true))
	assert_signal_emitted_with_parameters(events, "consent_changed", [true])
	assert_eq(service.request_privacy_options(), OK)
	service.expire_operation()
	assert_true(consent.resolve_analytics(consent.operation_token(), false))
	assert_signal_emit_count(events, "consent_changed", 2, "late decision after timeout ignored")
	assert_eq(service.request_privacy_options(), OK)
	consent.privacy_options_completed.emit(FAILED)
	assert_true(consent.resolve_analytics(consent.operation_token(), false))
	assert_signal_emit_count(events, "consent_changed", 2, "late decision after error ignored")


func test_requested_notification_can_expire_before_provider_dispatch() -> void:
	_required()
	var expire: Callable = func() -> void:
		if service.privacy_snapshot().state == &"requested":
			service.expire_privacy_options()
	service.privacy_changed.connect(expire)
	assert_eq(service.request_privacy_options(), OK)
	service.privacy_changed.disconnect(expire)
	assert_eq(service.privacy_snapshot().state, &"unknown")
	assert_eq(consent.calls.entries.size(), 0)


func test_requested_terminal_and_dispatch_reentry_keep_owner_and_block_commands() -> void:
	_required()
	_iap()
	var observe: Callable = func() -> void: _all_blocked()
	service.privacy_changed.connect(observe)
	assert_eq(consent.set_outcome(&"show_privacy_options", &"obtained"), OK)
	var during_dispatch: Callable = func(_state: ConsentAdapter.State) -> void: _all_blocked()
	consent.consent_resolved.connect(during_dispatch)
	assert_eq(service.request_privacy_options(), OK)
	consent.consent_resolved.disconnect(during_dispatch)
	service.privacy_changed.disconnect(observe)
	assert_eq(service.privacy_snapshot().state, &"completed")
	assert_eq(consent.calls.entries.size(), 1)
	assert_eq(store.calls.entries.size(), 0)
	assert_eq(ads.calls.entries.size(), 0)


func test_fake_suppresses_privacy_terminal_after_legacy_callback_supersedes_it() -> void:
	for error: bool in [false, true]:
		var fake: ConsentFake = ConsentFake.new()
		watch_signals(fake)
		assert_eq(fake.set_outcome(&"show_privacy_options", &"error" if error else &"obtained"), OK)
		var supersede: Callable = func(_state: ConsentAdapter.State) -> void: fake.request_info()
		if error:
			fake.operation_failed.connect(fake.reset)
		else:
			fake.consent_resolved.connect(supersede)
		fake.show_privacy_options()
		assert_signal_not_emitted(fake, "privacy_options_completed")
		if error:
			fake.operation_failed.disconnect(fake.reset)
		else:
			fake.consent_resolved.disconnect(supersede)


func test_existing_legal_continue_and_iap_operations_block_privacy_without_dispatch() -> void:
	_required()
	assert_eq(service.start_session(), OK)
	assert_eq(service.request_privacy_options(), ERR_BUSY)
	service.expire_operation()
	assert_eq(service.before_next_level(6), OK)
	assert_eq(service.request_privacy_options(), ERR_BUSY)
	service.expire_operation()
	_iap()
	assert_eq(service.request_products(), OK)
	assert_eq(service.request_privacy_options(), ERR_BUSY)
	store.purchase_failed.emit("test")
	assert_eq(service.purchase(FIXTURE.REMOVE), OK)
	assert_eq(service.request_privacy_options(), ERR_BUSY)
	store.purchase_failed.emit("test")
	assert_eq(service.restore_purchases(), OK)
	assert_eq(service.request_privacy_options(), ERR_BUSY)
	service.expire_restore()
	assert_eq(service.request_privacy_options(), OK)
	assert_eq(consent.calls.entries.back().method, "show_privacy_options")


func test_durable_restore_settlement_blocks_privacy_until_committed() -> void:
	_required()
	_iap()
	var transaction: StoreTransaction = StoreTransaction.new()
	transaction.store_key = "privacy-pending-remove"
	transaction.product_id = FIXTURE.REMOVE
	transaction.state = StoreTransaction.State.PURCHASED
	storage.stop = &"temp_opened"
	assert_eq(service.restore_purchases(), OK)
	store.transaction_updated.emit(transaction)
	var batch: Array[StoreTransaction] = [transaction]
	store.restore_completed.emit(batch)
	assert_eq(service.restore_snapshot().state, &"settling")
	assert_eq(service.request_privacy_options(), ERR_BUSY)
	storage.stop = &""
	assert_eq(service.retry_restore_settlement(), OK)
	assert_eq(service.restore_snapshot().state, &"completed")
	assert_eq(service.request_privacy_options(), OK)


func test_ad_presentation_and_earned_failed_grant_block_privacy() -> void:
	_required()
	assert_eq(consent.set_outcome(&"request_info", &"not_required"), OK)
	assert_eq(ads.set_outcome(&"initialize", &"ready"), OK)
	assert_eq(ads.set_outcome(&"load_rewarded", &"ready"), OK)
	assert_eq(service.before_next_level(6), OK)
	assert_true(service.ads_ready())
	var reward: Callable = economy.grant.bind(&"rewarded_hint", {"hint": 1})
	assert_eq(service.request_rewarded(&"hint", reward), OK)
	assert_eq(service.request_privacy_options(), ERR_BUSY)
	ads.ad_opened.emit()
	storage.stop = &"temp_opened"
	ads.reward_earned.emit()
	ads.ad_closed.emit()
	assert_eq(service.rewarded_state(), &"pending_reward")
	assert_eq(service.request_privacy_options(), ERR_BUSY)
	storage.stop = &""
	assert_eq(service.request_rewarded(&"hint", reward), OK)
	assert_eq(service.request_privacy_options(), OK)
	assert_false(service.ads_ready(), "privacy change requires future normal consent gating")
	var calls: Array = ads.calls.entries.duplicate(true)
	consent.privacy_options_completed.emit(OK)
	assert_eq(ads.calls.entries, calls, "completion cannot implicitly initialize ads")


func test_reconfigure_disconnects_old_provider_and_retained_exit_requires_rebinding() -> void:
	_required()
	assert_eq(service.request_privacy_options(), OK)
	service.expire_privacy_options()
	var old: ConsentFake = consent
	consent = ConsentFake.new()
	assert_eq(service.configure(save, config, events, consent, ads, false), OK)
	var snapshot: Dictionary = service.privacy_snapshot()
	old.set_privacy_options_requirement(ConsentAdapter.PrivacyRequirement.NOT_REQUIRED)
	old.privacy_options_completed.emit(OK)
	old.consent_resolved.emit(ConsentAdapter.State.OBTAINED)
	assert_eq(service.privacy_snapshot(), snapshot)
	_required()
	assert_eq(service.request_privacy_options(), OK)
	remove_child(service)
	assert_eq(service.privacy_snapshot().state, &"unavailable")
	assert_false(service.privacy_owner_matches(save))
	consent.privacy_options_completed.emit(OK)
	add_child(service)
	assert_false(service.privacy_owner_matches(save))
	assert_eq(service.request_privacy_options(), ERR_UNCONFIGURED)
	assert_eq(service.configure(save, config, events, consent, ads, false), OK)
	assert_true(service.privacy_owner_matches(save))
	assert_eq(service.privacy_snapshot().state, &"idle")
	var before: int = service.privacy_snapshot().revision
	consent.set_privacy_options_requirement(ConsentAdapter.PrivacyRequirement.NOT_REQUIRED)
	assert_eq(service.privacy_snapshot().revision, before + 1, "one reconnected listener")


func test_configure_reads_existing_requirement_and_never_dispatches_or_grants_consent() -> void:
	consent.set_privacy_options_requirement(REQUIRED)
	var before: int = service.privacy_snapshot().revision
	assert_eq(service.configure(save, config, events, consent, ads, true), OK)
	assert_eq(service.privacy_snapshot().requirement, &"required")
	assert_true(service.privacy_snapshot().available)
	assert_eq(service.privacy_snapshot().state, &"idle")
	assert_gt(service.privacy_snapshot().revision, before)
	assert_eq(consent.calls.entries.size(), 0)
	assert_eq(ads.calls.entries.size(), 0)
	assert_signal_not_emitted(events, "consent_changed")
