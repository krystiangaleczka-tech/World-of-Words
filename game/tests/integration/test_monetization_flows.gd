extends GutTest

const SERVICE: Script = preload("res://services/monetization.gd")
const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const EVENTS: Script = preload("res://services/events.gd")
const AUDIO: Script = preload("res://services/audio.gd")
const PATH: String = "user://t0263-flows.json"


class FixedClock:
	extends Clock
	var ticks: int = 1000000
	var seconds: int = 1800000000

	func monotonic_msec() -> int:
		return ticks

	func unix_time_seconds() -> int:
		return seconds

	func advance(seconds_elapsed: int) -> void:
		ticks += seconds_elapsed * 1000
		seconds += seconds_elapsed


class FlowConfig:
	extends "res://services/config.gd"
	var prompt_limit: int = 2

	func get_int(key: StringName) -> int:
		return prompt_limit if key == &"onboarding.max_prompts_per_session" else super.get_int(key)


class GateStorage:
	extends SaveStorage
	var blocked: bool = false

	func checkpoint(_step: StringName) -> Error:
		return ERR_CANT_CREATE if blocked else OK


class CalendarService:
	extends "res://services/monetization.gd"
	var day: String = "2026-10-16"

	func _local_day() -> String:
		return day


var service: SERVICE
var save: SAVE
var economy: ECONOMY
var config: FlowConfig
var events: EVENTS
var ads: AdsFake
var consent: ConsentFake
var clock: FixedClock
var storage: GateStorage


func before_each() -> void:
	_clean()
	clock = FixedClock.new()
	storage = GateStorage.new(PATH)
	save = SAVE.new()
	economy = ECONOMY.new()
	config = FlowConfig.new()
	events = EVENTS.new()
	service = CalendarService.new()
	for node: Node in [save, economy, config, events, service]:
		add_child_autofree(node)
	save.initialize(clock)
	economy.initialize(clock)
	service.initialize(clock)
	save.configure(storage, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert_eq(save.load(), OK)
	assert_eq(config.load(), OK)
	economy.configure(save, config, events)
	ads = AdsFake.new()
	consent = ConsentFake.new()
	ads.set_outcome(&"initialize", &"ready")
	ads.set_outcome(&"load_rewarded", &"ready")
	ads.set_outcome(&"load_interstitial", &"ready")
	consent.set_outcome(&"request_info", &"not_required")
	consent.set_outcome(&"request_att", &"denied")
	assert_eq(service.configure(save, config, events, consent, ads, false), OK)
	watch_signals(service)
	watch_signals(events)


func after_each() -> void:
	_clean()


func _clean() -> void:
	for path: String in [PATH, PATH + ".other"]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


func _ready_ads() -> void:
	assert_eq(service.before_next_level(6), OK)
	assert_true(service.ads_ready())


func _count(method: String) -> int:
	var count: int = 0
	for entry: Dictionary in ads.calls.entries:
		if entry.method == method:
			count += 1
	return count


func _reward(amount: int = 1) -> Callable:
	return economy.grant.bind(&"rewarded_hint", {"hint": amount})


func _timeout(presentation: bool) -> void:
	var owner: Node = service
	if presentation:
		for child: Node in service.get_children():
			if child is AdPresentation:
				owner = child
	for child: Node in owner.get_children():
		if child is Timer:
			assert_true(child.one_shot)
			assert_true(child.ignore_time_scale)
			assert_gt(child.wait_time, 0.0)
			assert_lt(child.wait_time, INF)
			child.timeout.emit()
			return
	fail_test("Missing finite watchdog")


func test_only_opened_eligible_interstitial_updates_cooldowns_and_prompt_cap() -> void:
	_ready_ads()
	ads.set_outcome(&"show_interstitial", &"shown")
	clock.advance(120)
	assert_eq(service.before_next_level(16), OK)
	assert_eq(_count("show_interstitial"), 0, "Unloaded ad skips, then preloads")
	assert_false(service.can_offer_interstitial({"context": "daily", "completed_slot": 17}))
	assert_eq(service.before_next_level(17), OK)
	assert_eq(_count("show_interstitial"), 1)
	assert_eq(save.get_section(&"monetization")["last_interstitial_time"], clock.seconds)
	assert_eq(service.before_next_level(17), OK)
	assert_eq(_count("show_interstitial"), 1, "Repeat Continue never shows twice")
	assert_eq(service.before_next_level(18), OK)
	assert_eq(_count("show_interstitial"), 1)
	clock.advance(180)
	assert_eq(service.before_next_level(21), OK)
	assert_eq(_count("show_interstitial"), 2)
	clock.advance(180)
	assert_eq(service.before_next_level(25), OK)
	assert_eq(_count("show_interstitial"), 2, "Shared session prompt cap")


func test_no_fill_failure_and_purchase_grace_do_not_claim_display() -> void:
	_ready_ads()
	clock.advance(120)
	ads.set_outcome(&"load_interstitial", &"no_fill")
	assert_eq(service.before_next_level(16), OK)
	assert_null(save.get_section(&"monetization")["last_interstitial_time"])
	ads.set_outcome(&"load_interstitial", &"ready")
	assert_eq(service.before_next_level(17), OK)
	ads.set_outcome(&"show_interstitial", &"error")
	assert_eq(service.before_next_level(18), OK)
	assert_null(save.get_section(&"monetization")["last_interstitial_time"])
	assert_signal_not_emitted(service, "audio_pause_requested")
	var section: Dictionary = save.get_section(&"monetization")
	section["last_purchase_slot"] = 18
	assert_eq(save.set_section(&"monetization", section), OK)
	assert_eq(save.flush(), OK)
	ads.set_outcome(&"show_interstitial", &"shown")
	assert_eq(service.before_next_level(19), OK)
	assert_eq(service.before_next_level(27), OK)
	assert_null(save.get_section(&"monetization")["last_interstitial_time"])
	assert_eq(service.before_next_level(28), OK)
	assert_not_null(save.get_section(&"monetization")["last_interstitial_time"])


func test_remove_forced_ads_does_not_remove_explicit_rewarded() -> void:
	_ready_ads()
	var section: Dictionary = save.get_section(&"monetization")
	section["remove_forced_ads"] = true
	assert_eq(save.set_section(&"monetization", section), OK)
	assert_eq(save.flush(), OK)
	clock.advance(120)
	ads.set_outcome(&"show_interstitial", &"shown")
	service.before_next_level(16)
	service.before_next_level(17)
	assert_eq(_count("show_interstitial"), 0)
	ads.set_outcome(&"show_rewarded", &"reward")
	assert_eq(service.request_rewarded(&"hint", _reward()), OK)
	assert_eq(economy.snapshot().items.hint, 1)
	ads.reward_earned.emit()
	assert_eq(economy.snapshot().items.hint, 1)


func test_reward_no_fill_early_close_invalid_callback_and_snapshot_amounts() -> void:
	_ready_ads()
	assert_eq(
		service.request_rewarded(&"hint", economy.grant.bind(&" ", {"hint": 1})),
		ERR_INVALID_PARAMETER
	)
	assert_eq(_count("show_rewarded"), 0)
	assert_eq(
		service.request_rewarded(&"hint", func() -> void: fail_test("Arbitrary callback")),
		ERR_INVALID_PARAMETER
	)
	assert_eq(service.request_rewarded(&"not-a-placement", _reward()), ERR_INVALID_PARAMETER)
	ads.set_outcome(&"load_rewarded", &"no_fill")
	assert_eq(service.request_rewarded(&"hint", _reward()), OK)
	assert_eq(service.rewarded_state(), &"unavailable")
	assert_eq(economy.snapshot().items.hint, 0)
	ads.set_outcome(&"load_rewarded", &"ready")
	ads.set_outcome(&"show_rewarded", &"early_close")
	assert_eq(service.request_rewarded(&"hint", _reward()), OK)
	assert_eq(economy.snapshot().items.hint, 0)
	ads.set_outcome(&"load_rewarded", &"ready", false)
	ads.set_outcome(&"show_rewarded", &"reward")
	var amounts: Dictionary = {"hint": 1}
	assert_eq(service.request_rewarded(&"hint", economy.grant.bind(&"rewarded_hint", amounts)), OK)
	amounts["hint"] = 50
	assert_true(ads.settle(ads.operation_token()))
	assert_eq(economy.snapshot().items.hint, 1, "Accepted reward copied before presentation")


func test_interrupted_reward_grant_retries_without_another_ad_or_duplicate_award() -> void:
	_ready_ads()
	ads.set_outcome(&"show_rewarded", &"reward")
	storage.blocked = true
	assert_eq(service.request_rewarded(&"hint", _reward()), OK)
	assert_eq(service.rewarded_state(), &"pending_reward")
	assert_eq(economy.snapshot().items.hint, 0)
	assert_eq(service.before_next_level(7), ERR_BUSY)
	assert_eq(service.configure(save, config, events, consent, ads, false), ERR_BUSY)
	ads.reward_earned.emit()
	assert_eq(service.request_rewarded(&"hint", _reward(2)), ERR_BUSY)
	storage.blocked = false
	assert_eq(service.request_rewarded(&"hint", _reward()), OK)
	assert_eq(_count("show_rewarded"), 1)
	assert_eq(economy.snapshot().items.hint, 1)
	assert_eq(economy.journal().size(), 1)


func test_finite_watchdogs_release_once_ignore_late_consent_and_reward_callbacks() -> void:
	consent.set_outcome(&"request_info", &"not_required", false)
	assert_eq(service.before_next_level(1), OK)
	var obsolete: int = consent.operation_token()
	_timeout(false)
	assert_signal_emit_count(service, "continuation_ready", 1)
	consent.resolve_analytics(obsolete, true)
	assert_signal_not_emitted(events, "consent_changed")
	assert_eq(service.before_next_level(2), OK)
	assert_false(consent.settle(obsolete))
	assert_true(consent.settle(consent.operation_token()))
	assert_signal_emit_count(service, "continuation_ready", 2)
	ads.set_outcome(&"load_rewarded", &"ready", false)
	assert_eq(service.request_rewarded(&"hint", _reward()), OK)
	var reward_token: int = ads.operation_token()
	_timeout(true)
	ads.settle(reward_token)
	ads.reward_earned.emit()
	assert_eq(_count("show_rewarded"), 0)
	assert_eq(economy.snapshot().items.hint, 0)


func test_audio_is_paused_only_after_open_and_background_remains_muted_after_close() -> void:
	_ready_ads()
	var audio: AUDIO = AUDIO.new()
	add_child_autofree(audio)
	var played: Array[StringName] = []
	audio.configure(
		save, func(cue: StringName, _gain: float, _pitch: float) -> void: played.append(cue)
	)
	audio.bind_monetization(service)
	assert_eq(audio.load_cues(), OK)
	assert_true(audio.play(&"word_valid"))
	assert_eq(service.request_rewarded(&"hint", _reward()), OK)
	assert_true(audio.play(&"word_valid"), "Loading is not an opened ad")
	ads.ad_opened.emit()
	assert_false(audio.play(&"word_valid"))
	audio.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	ads.ad_closed.emit()
	assert_false(audio.play(&"word_valid"))
	audio.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_true(audio.play(&"word_valid"))
	assert_eq(save.get_setting(&"sfx_volume"), 1.0)
	assert_eq(played.size(), 3)
	assert_eq(save.set_setting(&"sfx_volume", 0.0), OK)
	audio.set_ad_paused(true)
	audio.set_ad_paused(false)
	assert_false(audio.play(&"word_valid"), "Ad pause never overrides persistent mute")


func test_reentrant_expiry_on_audio_pause_keeps_display_accounting_and_one_continue() -> void:
	_ready_ads()
	clock.advance(120)
	ads.set_outcome(&"show_interstitial", &"shown")
	service.before_next_level(16)
	var ended: Array[int] = []
	service.continuation_ready.connect(func(slot: int) -> void: ended.append(slot))
	service.audio_pause_requested.connect(
		func(paused: bool) -> void:
			if paused:
				service.expire_operation()
	)
	assert_eq(service.before_next_level(17), OK)
	assert_eq(ended, [17])
	assert_eq(save.get_section(&"monetization")["last_interstitial_time"], clock.seconds)
	clock.advance(180)
	service.before_next_level(18)
	service.before_next_level(20)
	assert_eq(
		_count("show_interstitial"), 1, "Opened ad consumed its cooldown despite cancellation"
	)


func test_ios_unresolved_att_cannot_load_or_show_ads_and_denial_still_allows_rewarded() -> void:
	assert_eq(service.configure(save, config, events, consent, ads, true), OK)
	consent.set_outcome(&"request_att", &"unknown")
	assert_eq(service.before_next_level(6), OK)
	assert_false(service.ads_ready())
	assert_eq(_count("load_rewarded"), 0)
	assert_eq(_count("load_interstitial"), 0)
	assert_eq(service.request_rewarded(&"hint", _reward()), ERR_UNAVAILABLE)
	consent.set_outcome(&"request_att", &"denied")
	ads.set_outcome(&"show_rewarded", &"reward")
	assert_eq(service.before_next_level(7), OK)
	assert_eq(service.request_rewarded(&"hint", _reward()), OK)
	assert_eq(economy.snapshot().items.hint, 1)
	assert_signal_not_emitted(events, "consent_changed")


func test_shop_rewards_enforce_configured_local_day_cap_and_reserve_retry_once() -> void:
	_ready_ads()
	ads.set_outcome(&"show_rewarded", &"reward")
	var payout: int = config.get_int(&"economy.reward.rewarded_coins")
	var callback: Callable = economy.grant.bind(&"rewarded_coins", {"coins": payout})
	storage.blocked = true
	assert_eq(service.request_rewarded(&"shop_coins", callback), OK)
	assert_eq(service.rewarded_state(), &"pending_reward")
	assert_eq(economy.snapshot().coins, 0)
	storage.blocked = false
	assert_eq(service.request_rewarded(&"shop_coins", callback), OK)
	assert_eq(save.get_section(&"monetization")["shop_coins_ads"]["count"], 1)
	var limit: int = config.get_int(&"ads.rewarded.shop_coins.daily_cap")
	for index: int in range(limit - 1):
		assert_eq(service.request_rewarded(&"shop_coins", callback), OK)
	assert_eq(economy.snapshot().coins, payout * limit)
	assert_eq(service.request_rewarded(&"shop_coins", callback), ERR_UNAVAILABLE)
	assert_eq(_count("show_rewarded"), limit)
	service.set("day", "2026-10-17")
	assert_eq(service.request_rewarded(&"shop_coins", callback), OK)
	assert_eq(save.get_section(&"monetization")["shop_coins_ads"]["count"], 1)
	service.set("day", "2026-10-16")
	assert_eq(service.request_rewarded(&"shop_coins", callback), ERR_UNAVAILABLE)


func test_reward_rejects_economy_bound_to_another_save_before_presentation() -> void:
	_ready_ads()
	var other_save: SAVE = SAVE.new()
	var other_economy: ECONOMY = ECONOMY.new()
	add_child_autofree(other_save)
	add_child_autofree(other_economy)
	other_save.initialize(clock)
	other_economy.initialize(clock)
	other_save.configure(
		SaveStorage.new(PATH + ".other"),
		func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert_eq(other_save.load(), OK)
	other_economy.configure(other_save, config, events)
	assert_eq(
		service.request_rewarded(&"hint", other_economy.grant.bind(&"rewarded_hint", {"hint": 1})),
		ERR_INVALID_PARAMETER
	)
	assert_eq(_count("load_rewarded"), 0)


func test_reentrant_flush_failure_cannot_nest_settlement_or_leave_audio_paused() -> void:
	_ready_ads()
	ads.set_outcome(&"show_rewarded", &"reward")
	var callback: Callable = economy.grant.bind(
		&"rewarded_coins", {"coins": config.get_int(&"economy.reward.rewarded_coins")}
	)
	var retries: Array[int] = []
	var pauses: Array[bool] = []
	service.audio_pause_requested.connect(func(paused: bool) -> void: pauses.append(paused))
	save.flush_failed.connect(
		func(_error: Error) -> void:
			service.expire_operation()
			storage.blocked = false
			retries.append(service.request_rewarded(&"shop_coins", callback)),
		CONNECT_ONE_SHOT
	)
	storage.blocked = true
	assert_eq(service.request_rewarded(&"shop_coins", callback), OK)
	assert_eq(retries, [ERR_BUSY])
	assert_eq(pauses, [true, false])
	assert_eq(service.request_rewarded(&"shop_coins", callback), OK)
	assert_eq(economy.snapshot().coins, config.get_int(&"economy.reward.rewarded_coins"))
	assert_eq(economy.journal().size(), 1)
	assert_eq(_count("show_rewarded"), 1)


func test_profile_change_during_ad_defers_reward_until_original_owner_returns() -> void:
	_ready_ads()
	var other_save: SAVE = SAVE.new()
	add_child_autofree(other_save)
	other_save.initialize(clock)
	other_save.configure(
		SaveStorage.new(PATH + ".other"),
		func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	assert_eq(other_save.load(), OK)
	ads.set_outcome(&"load_rewarded", &"ready", false)
	ads.set_outcome(&"show_rewarded", &"reward")
	assert_eq(service.request_rewarded(&"hint", _reward()), OK)
	economy.configure(other_save, config, events)
	ads.settle(ads.operation_token())
	assert_eq(economy.snapshot().items.hint, 0)
	assert_eq(economy.journal().size(), 0)
	assert_eq(service.rewarded_state(), &"pending_reward")
	assert_eq(service.request_rewarded(&"hint", _reward()), ERR_UNCONFIGURED)
	economy.configure(save, config, events)
	assert_eq(service.request_rewarded(&"hint", _reward()), OK)
	assert_eq(economy.snapshot().items.hint, 1)
	assert_eq(economy.journal().size(), 1)
	assert_eq(_count("show_rewarded"), 1)
