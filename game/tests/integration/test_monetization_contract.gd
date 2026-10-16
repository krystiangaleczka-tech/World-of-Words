extends GutTest

const SERVICE: Script = preload("res://services/monetization.gd")
const SAVE: Script = preload("res://services/save.gd")
const CONFIG: Script = preload("res://services/config.gd")
const EVENTS: Script = preload("res://services/events.gd")
const PATH: String = "user://t0261-contract.json"
const ID: String = "12345678-1234-4234-8234-123456789abc"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790000000

	func monotonic_msec() -> int:
		return 180000


class TestConfig:
	extends "res://services/config.gd"
	var ump_slot: int = 1

	func get_int(key: StringName) -> int:
		return ump_slot if key == &"consent.ump_after_slot" else super.get_int(key)


class SynchronousConsent:
	extends ConsentFake

	func request_info() -> void:
		super.request_info()
		consent_resolved.emit(State.REQUIRED)

	func show_form_if_required() -> void:
		super.show_form_if_required()
		consent_resolved.emit(State.OBTAINED)

	func request_att() -> void:
		super.request_att()
		att_resolved.emit(AttStatus.DENIED)


class SynchronousAds:
	extends AdsFake

	func initialize(state: ConsentAdapter.State) -> void:
		super.initialize(state)
		initialized.emit()


var service: SERVICE
var save: SAVE
var config: TestConfig
var events: EVENTS
var consent: ConsentFake
var ads: AdsFake


func before_each() -> void:
	_clean()
	save = SAVE.new()
	config = TestConfig.new()
	events = EVENTS.new()
	service = SERVICE.new()
	for node: Node in [save, config, events, service]:
		add_child_autofree(node)
	var clock: Clock = FixedClock.new()
	save.initialize(clock)
	service.initialize(clock)
	save.configure(SaveStorage.new(PATH), func() -> String: return ID)
	assert_eq(save.load(), OK)
	assert_eq(config.load(), OK)
	consent = ConsentFake.new()
	ads = AdsFake.new()
	assert_eq(service.configure(save, config, events, consent, ads, false), OK)
	watch_signals(service)
	watch_signals(events)


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _consent_methods() -> Array[String]:
	var methods: Array[String] = []
	for entry: Dictionary in consent.calls.entries:
		methods.append(entry.method)
	return methods


func test_silent_refresh_defers_form_and_android_initialization_until_continue() -> void:
	assert_eq(consent.calls.entries.size(), 0)
	assert_eq(ads.calls.entries.size(), 0)
	assert_eq(service.start_session(), OK)
	assert_eq(service.start_session(), ERR_ALREADY_IN_USE)
	consent.consent_resolved.emit(ConsentAdapter.State.REQUIRED)
	assert_eq(_consent_methods(), ["request_info"])
	assert_eq(ads.calls.entries.size(), 0)
	assert_eq(service.before_next_level(1), OK)
	assert_eq(_consent_methods(), ["request_info", "show_form_if_required"])
	assert_eq(service.before_next_level(2), ERR_BUSY)
	consent.consent_resolved.emit(ConsentAdapter.State.OBTAINED)
	assert_eq(ads.calls.entries[0].method, "initialize")
	assert_false(service.ads_ready())
	assert_signal_not_emitted(service, "continuation_ready")
	ads.initialized.emit()
	assert_true(service.ads_ready())
	assert_signal_emitted_with_parameters(service, "continuation_ready", [1])
	ads.initialized.emit()
	consent.consent_resolved.emit(ConsentAdapter.State.OBTAINED)
	assert_signal_emit_count(service, "continuation_ready", 1)
	assert_eq(ads.calls.entries.size(), 1)
	assert_signal_not_emitted(events, "consent_changed")


func test_ios_waits_for_due_att_and_accepts_all_terminal_outcomes() -> void:
	for status: ConsentAdapter.AttStatus in [
		ConsentAdapter.AttStatus.DENIED,
		ConsentAdapter.AttStatus.RESTRICTED,
		ConsentAdapter.AttStatus.AUTHORIZED
	]:
		consent = ConsentFake.new()
		ads = AdsFake.new()
		assert_eq(service.configure(save, config, events, consent, ads, true), OK)
		assert_eq(service.before_next_level(1), OK)
		consent.consent_resolved.emit(ConsentAdapter.State.NOT_REQUIRED)
		assert_eq(ads.calls.entries.size(), 0)
		assert_eq(_consent_methods(), ["request_info"])
		assert_eq(service.before_next_level(6), OK)
		assert_eq(_consent_methods(), ["request_info", "request_att"])
		assert_eq(ads.calls.entries.size(), 0)
		consent.att_resolved.emit(status)
		assert_eq(ads.calls.entries.size(), 1)
		ads.initialized.emit()
		assert_true(service.ads_ready())
	assert_signal_not_emitted(events, "consent_changed")


func test_unresolved_info_form_att_and_expiry_retry_without_duplicate_continue() -> void:
	assert_eq(service.before_next_level(1), OK)
	consent.consent_resolved.emit(ConsentAdapter.State.UNKNOWN)
	assert_signal_emit_count(service, "continuation_ready", 1)
	assert_eq(service.before_next_level(2), OK)
	consent.consent_resolved.emit(ConsentAdapter.State.REQUIRED)
	consent.operation_failed.emit()
	assert_signal_emit_count(service, "continuation_ready", 2)
	assert_eq(service.before_next_level(3), OK)
	consent.consent_resolved.emit(ConsentAdapter.State.REQUIRED)
	assert_signal_emit_count(service, "continuation_ready", 3)
	assert_eq(ads.calls.entries.size(), 0)
	assert_eq(service.configure(save, config, events, consent, ads, true), OK)
	assert_eq(service.before_next_level(6), OK)
	consent.consent_resolved.emit(ConsentAdapter.State.NOT_REQUIRED)
	consent.att_resolved.emit(ConsentAdapter.AttStatus.NOT_DETERMINED)
	assert_false(service.ads_ready())
	assert_eq(service.before_next_level(7), OK)
	service.expire_operation()
	consent.att_resolved.emit(ConsentAdapter.AttStatus.AUTHORIZED)
	assert_eq(ads.calls.entries.size(), 0)
	assert_eq(service.before_next_level(8), OK)
	consent.att_resolved.emit(ConsentAdapter.AttStatus.DENIED)
	ads.ad_failed.emit("initialize failed")
	assert_false(service.ads_ready())
	assert_eq(service.before_next_level(9), OK)
	ads.initialized.emit()
	assert_true(service.ads_ready())


func test_only_explicit_analytics_purpose_result_is_relayed_and_old_adapters_disconnect() -> void:
	assert_eq(service.start_session(), OK)
	consent.consent_resolved.emit(ConsentAdapter.State.NOT_REQUIRED)
	assert_signal_not_emitted(events, "consent_changed")
	consent.analytics_resolved.emit(true)
	assert_signal_emitted_with_parameters(events, "consent_changed", [true])
	consent.analytics_resolved.emit(false)
	assert_signal_emit_count(events, "consent_changed", 2)
	var old: ConsentFake = consent
	assert_eq(service.configure(save, config, events, ConsentFake.new(), AdsFake.new(), false), OK)
	old.analytics_resolved.emit(true)
	assert_signal_emit_count(events, "consent_changed", 2)


func test_future_flow_apis_never_reward_write_or_call_providers() -> void:
	var original: String = FileAccess.get_file_as_string(PATH)
	assert_eq(service.before_next_level(0), ERR_INVALID_PARAMETER)
	assert_false(service.can_offer_interstitial({"sdk_ready": true, "ad_loaded": true}))
	assert_eq(service.rewarded_state(), &"unavailable")
	assert_eq(
		service.request_rewarded(&"hint", func() -> void: fail_test("No reward")), ERR_UNAVAILABLE
	)
	assert_eq(service.purchase("not-a-product"), ERR_UNAVAILABLE)
	assert_eq(service.restore_purchases(), ERR_UNAVAILABLE)
	assert_eq(service.process_unfinished_transactions(), ERR_UNAVAILABLE)
	ads.reward_earned.emit()
	ads.ad_opened.emit()
	ads.ad_closed.emit()
	assert_signal_not_emitted(service, "audio_pause_requested")
	assert_eq(FileAccess.get_file_as_string(PATH), original)
	assert_eq(ads.calls.entries.size(), 0)
	assert_eq(consent.calls.entries.size(), 0)


func test_unconfigured_and_busy_reconfiguration_fail_without_operations() -> void:
	var fresh: SERVICE = SERVICE.new()
	add_child_autofree(fresh)
	assert_eq(fresh.start_session(), ERR_UNCONFIGURED)
	assert_eq(fresh.before_next_level(1), ERR_UNCONFIGURED)
	assert_eq(service.before_next_level(1), OK)
	assert_eq(service.configure(save, config, events, consent, ads, false), ERR_BUSY)
	service.expire_operation()
	service.expire_operation()
	assert_signal_emit_count(service, "continuation_ready", 1)
	assert_eq(service.configure(save, config, events, consent, ads, false), OK)


func test_ump_uses_configured_completed_slot_and_synchronous_callbacks_are_safe() -> void:
	config.ump_slot = 4
	assert_eq(service.start_session(), OK)
	consent.consent_resolved.emit(ConsentAdapter.State.REQUIRED)
	assert_eq(service.before_next_level(3), OK)
	assert_eq(_consent_methods(), ["request_info"])
	assert_eq(service.before_next_level(4), OK)
	assert_eq(_consent_methods(), ["request_info", "show_form_if_required"])
	service.expire_operation()
	var sync_consent: SynchronousConsent = SynchronousConsent.new()
	var sync_ads: SynchronousAds = SynchronousAds.new()
	assert_eq(service.configure(save, config, events, sync_consent, sync_ads, true), OK)
	service.continuation_ready.connect(
		func(slot: int) -> void:
			if slot == 6:
				assert_eq(service.before_next_level(7), OK)
	)
	assert_eq(service.before_next_level(6), OK)
	assert_true(service.ads_ready())
	assert_eq(sync_ads.calls.entries.size(), 1)
	assert_eq(sync_consent.calls.entries[0].method, "request_info")
	assert_eq(sync_consent.calls.entries[1].method, "show_form_if_required")
	assert_eq(sync_consent.calls.entries[2].method, "request_att")
	assert_signal_emitted_with_parameters(service, "continuation_ready", [7])
