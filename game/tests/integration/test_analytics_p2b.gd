# gdlint: disable=max-public-methods
extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const CONFIG: Script = preload("res://services/config.gd")
const CONTENT: Script = preload("res://services/content.gd")
const EVENTS: Script = preload("res://services/events.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const SERVICE: Script = preload("res://services/monetization.gd")
const ANALYTICS: Script = preload("res://services/analytics.gd")
const ROOT: String = "user://t0328"
const COINS: String = "c.coins_s.v1"
const REMOVE: String = "nc.remove_forced_ads.v1"


class FixedClock:
	extends Clock
	var ticks: int = 1000000

	func monotonic_msec() -> int:
		return ticks

	func unix_time_seconds() -> int:
		return 1800000000


class P2Config:
	extends "res://tests/integration/test_paid_tool_transactions.gd".ToolConfig
	var queue_limit: int = 1000

	func get_int(key: StringName) -> int:
		if key == &"analytics.queue.max_events":
			return queue_limit
		if key == &"unlocks.double_reward_slot":
			return 2
		if key == &"hint.offer_idle_seconds":
			return 1
		return super.get_int(key)


class GateStorage:
	extends SaveStorage
	var blocked: bool = false

	func checkpoint(_step: StringName) -> Error:
		return ERR_CANT_CREATE if blocked else OK


class FakeNav:
	extends Node
	signal screen_changed(screen: int)
	var screen: int = 1
	var slot: int = 1

	func current_screen() -> int:
		return screen

	func level_slot() -> int:
		return slot


var progress: Node
var port: AtomicProgressPort
var save: SAVE
var config: P2Config
var content: CONTENT
var events: EVENTS
var economy: ECONOMY
var service: SERVICE
var analytics: ANALYTICS
var nav: FakeNav
var storage: GateStorage
var ads: AdsFake
var consent: ConsentFake
var store: IapFake
var fake: AnalyticsFake
var previous: AnalyticsAdapter
var motion: bool


func before_each() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(ROOT)
	motion = Tokens.reduced_motion
	Tokens.reduced_motion = true
	previous = Platform.analytics
	fake = AnalyticsFake.new()
	Platform.analytics = fake
	var clock: FixedClock = FixedClock.new()
	save = SAVE.new()
	progress = load("res://services/progress.gd").new()
	port = AtomicProgressPort.new()
	config = P2Config.new()
	content = CONTENT.new()
	events = EVENTS.new()
	economy = ECONOMY.new()
	service = SERVICE.new()
	analytics = ANALYTICS.new()
	nav = FakeNav.new()
	for node: Node in [save, config, content, events, economy, service, analytics, nav, progress]:
		add_child_autofree(node)
	for node: Node in [save, economy, service, progress]:
		node.initialize(clock)
	storage = GateStorage.new(ROOT + "/save.json")
	save.configure(storage, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert_eq(config.load(), OK)
	assert_eq(content.load_manifest("pl", "res://tests/fixtures/paid_tools"), OK)
	progress.configure(save, content)
	assert_eq(progress.configure_atomic(config), OK)
	economy.configure(save, config, events)
	assert_eq(port.configure(save, progress, economy), OK)
	assert_eq(save.load(), OK)
	assert_eq(progress.configure_p2(config, port, events), OK)
	assert_eq(save.configure_onboarding(events), OK)
	assert_eq(
		analytics.start_runtime(
			save, config, content, events, AnalyticsQueue.new(SaveStorage.new(ROOT + "/queue.json"))
		),
		OK
	)
	assert_eq(analytics.configure_listener(save, content, nav, clock), OK)
	ads = AdsFake.new()
	consent = ConsentFake.new()
	ads.set_outcome(&"initialize", &"ready")
	ads.set_outcome(&"load_rewarded", &"ready")
	consent.set_outcome(&"request_info", &"not_required")
	assert_eq(service.configure(save, config, events, consent, ads, true), OK)
	store = IapFake.new()
	assert_eq(
		store.set_products(
			[
				{
					"id": COINS,
					"restorable": false,
					"price": "localized",
					"price_micros": 4990000,
					"price_currency": "PLN"
				},
				{
					"id": REMOVE,
					"restorable": true,
					"price": "localized",
					"price_micros": 12990000,
					"price_currency": "PLN"
				}
			]
		),
		OK
	)
	for operation: StringName in [&"query_products", &"restore", &"fetch_unfinished"]:
		store.set_outcome(operation, &"ready")
	store.set_outcome(&"purchase", &"success")
	assert_eq(service.configure_iap(economy, store), OK)


func after_each() -> void:
	Platform.analytics = previous
	Tokens.reduced_motion = motion
	_clean()


func _clean() -> void:
	var directory: DirAccess = DirAccess.open(ROOT)
	if directory != null:
		for filename: String in directory.get_files():
			DirAccess.remove_absolute(ROOT + "/" + filename)
		DirAccess.remove_absolute(ROOT)


func _allow() -> void:
	events.consent_changed.emit(true)


func _params(name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in fake.calls.entries:
		if entry.arguments[0] == name:
			result.append(entry.arguments[1])
	return result


func _ready_ads() -> void:
	consent.set_outcome(&"request_att", &"denied")
	assert_eq(service.before_next_level(6), OK)
	assert_true(service.ads_ready())


func test_consent_requires_purpose_decision_and_deduplicates_after_allow() -> void:
	assert_eq(service.start_session(), OK)
	assert_eq(analytics.pending_count(), 0)
	var token: int = consent.operation_token()
	assert_true(consent.resolve_analytics(token, true))
	assert_eq(_params("consent_result").size(), 1)
	var params: Dictionary = _params("consent_result")[0]
	assert_true(params.analytics_allowed)
	assert_true(params.ads_allowed)
	assert_eq(params.status, "not_required")
	consent.analytics_resolved.emit(true)
	assert_eq(_params("consent_result").size(), 1)
	consent.analytics_resolved.emit(false)
	assert_eq(_params("consent_result").size(), 1)
	assert_eq(analytics.pending_count(), 0)


func test_att_accepted_callback_is_once_and_cannot_grant_analytics_consent() -> void:
	_ready_ads()
	assert_eq(_params("att_result").size(), 0)
	assert_eq(analytics.pending_count(), 1)
	consent.att_resolved.emit(ConsentAdapter.AttStatus.AUTHORIZED)
	assert_eq(analytics.pending_count(), 1)
	_allow()
	assert_eq(_params("att_result")[0].status, "denied")


func test_committed_onboarding_and_existing_settings_unlock_are_once() -> void:
	_allow()
	storage.blocked = true
	assert_ne(save.complete_tutorial(), OK)
	assert_eq(_params("onboarding_step").size(), 0)
	storage.blocked = false
	assert_eq(save.retry_onboarding(), OK)
	assert_eq(save.complete_tutorial(), OK)
	assert_eq(_params("onboarding_step").size(), 1)
	assert_eq(_params("onboarding_step")[0].step, 1)
	events.onboarding_step.emit(100)
	assert_eq(_params("onboarding_step").size(), 1)
	assert_eq(save.set_setting(&"music_volume", 0.5), OK)
	assert_eq(save.flush(), OK)
	assert_eq(_params("settings_changed").size(), 1)
	events.feature_unlocked.emit("pl", &"hint", 3)
	assert_eq(_params("feature_unlocked").size(), 1)


func test_listener_whitelist_rebind_and_teardown_do_not_duplicate_or_leak() -> void:
	_allow()
	assert_eq(analytics.configure_listener(save, content, nav, save.get_clock()), OK)
	events.p2_analytics.emit(&"app_boot", {})
	assert_eq(_params("app_boot").size(), 0)
	service.observe_shop_opened(&"level")
	assert_eq(_params("shop_opened").size(), 1)
	analytics.get_child(0).free()
	service.observe_shop_opened(&"level")
	events.onboarding_step.emit(1)
	assert_eq(_params("shop_opened").size(), 1)
	assert_eq(_params("onboarding_step").size(), 0)


func test_rewarded_open_reward_duplicates_and_failed_write_retry_are_truthful() -> void:
	_allow()
	_ready_ads()
	assert_eq(
		service.request_rewarded(&"hint", economy.grant.bind(&"rewarded_hint", {"hint": 1})), OK
	)
	assert_eq(_params("ad_offer_shown").size(), 0)
	ads.ad_opened.emit()
	ads.ad_opened.emit()
	storage.blocked = true
	ads.reward_earned.emit()
	ads.reward_earned.emit()
	ads.ad_closed.emit()
	assert_eq(_params("ad_shown").size(), 1)
	assert_eq(_params("ad_reward_earned").size(), 1)
	assert_eq(service.rewarded_state(), &"pending_reward")
	storage.blocked = false
	assert_eq(
		service.request_rewarded(&"hint", economy.grant.bind(&"rewarded_hint", {"hint": 1})), OK
	)
	assert_eq(_params("ad_reward_earned").size(), 1)
	assert_eq(economy.snapshot().items.hint, 1)


func test_ad_failure_timeout_and_early_close_never_invent_reward_or_raw_errors() -> void:
	_allow()
	_ready_ads()
	var reward: Callable = economy.grant.bind(&"rewarded_hint", {"hint": 1})
	assert_eq(service.request_rewarded(&"hint", reward), OK)
	ads.ad_failed.emit("secret token / arbitrary provider exception")
	ads.ad_failed.emit("duplicate")
	assert_eq(_params("ad_failed").size(), 1)
	assert_eq(_params("ad_failed")[0].error_code, "provider_error")
	assert_eq(service.request_rewarded(&"hint", reward), OK)
	service.expire_operation()
	assert_eq(_params("ad_failed")[1].error_code, "timeout")
	assert_eq(service.request_rewarded(&"hint", reward), OK)
	ads.ad_opened.emit()
	ads.ad_closed.emit()
	assert_eq(_params("ad_reward_earned").size(), 0)
	assert_eq(economy.snapshot().items.hint, 0)


func test_iap_started_completed_verified_price_and_duplicate_callbacks() -> void:
	_allow()
	store.set_outcome(&"purchase", &"duplicate")
	assert_eq(service.purchase(COINS), OK)
	assert_eq(_params("iap_purchase_started").size(), 1)
	assert_eq(_params("iap_purchase_completed").size(), 1)
	var params: Dictionary = _params("iap_purchase_completed")[0]
	assert_eq(params.product_id, COINS)
	assert_eq(params.price_micros, 4990000)
	assert_eq(params.price_currency, "PLN")
	assert_false(params.has("store_key"))
	assert_eq(economy.snapshot().coins, config.get_int(&"iap.coins_s.amount"))


func test_iap_missing_price_does_not_fabricate_metadata_or_block_grant() -> void:
	_allow()
	var transaction: StoreTransaction = StoreTransaction.new(
		"private-key", COINS, StoreTransaction.State.PURCHASED
	)
	store.transaction_updated.emit(transaction)
	assert_eq(_params("iap_purchase_completed").size(), 0)
	assert_eq(economy.snapshot().coins, config.get_int(&"iap.coins_s.amount"))


func test_iap_failed_write_freezes_metadata_until_existing_explicit_retry() -> void:
	_allow()
	storage.blocked = true
	var transaction: StoreTransaction = StoreTransaction.new(
		"frozen-secret", COINS, StoreTransaction.State.PURCHASED, 9000000, "EUR"
	)
	store.transaction_updated.emit(transaction)
	transaction.price_micros = 1
	transaction.price_currency = "USD"
	assert_eq(_params("iap_purchase_completed").size(), 0)
	storage.blocked = false
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(_params("iap_purchase_completed").size(), 1)
	assert_eq(_params("iap_purchase_completed")[0].price_micros, 9000000)
	assert_eq(_params("iap_purchase_completed")[0].price_currency, "EUR")


func test_iap_cancel_pending_failure_and_timeout_have_no_completed_event() -> void:
	_allow()
	for outcome: StringName in [&"cancel", &"failed", &"pending"]:
		store.set_outcome(&"purchase", outcome)
		assert_eq(service.purchase(COINS), OK)
	assert_eq(_params("iap_purchase_started").size(), 3)
	assert_eq(_params("iap_purchase_failed").size(), 2)
	assert_eq(_params("iap_purchase_completed").size(), 0)


func test_restore_uses_authoritative_terminal_batch_empty_and_deduplicated_keys() -> void:
	_allow()
	assert_eq(service.restore_purchases(), OK)
	assert_eq(_params("iap_restore_completed")[0].restored_count, 0)
	assert_eq(service.purchase(REMOVE), OK)
	assert_eq(service.purchase(COINS), OK)
	assert_eq(service.restore_purchases(), OK)
	assert_eq(_params("iap_restore_completed").size(), 2)
	assert_eq(_params("iap_restore_completed")[1].restored_count, 1)
	assert_eq(_params("iap_purchase_completed").size(), 2)
	var empty: Array[StoreTransaction] = []
	store.restore_completed.emit(empty)
	assert_eq(_params("iap_restore_completed").size(), 2)


func test_restore_waits_for_durable_proof_and_does_not_become_a_purchase() -> void:
	_allow()
	store.set_outcome(&"restore", &"manual")
	assert_eq(service.restore_purchases(), OK)
	storage.blocked = true
	var transaction: StoreTransaction = StoreTransaction.new(
		"restored-key", REMOVE, StoreTransaction.State.PURCHASED, 12990000, "PLN"
	)
	transaction.restored = true
	store.transaction_updated.emit(transaction)
	var batch: Array[StoreTransaction] = [transaction, transaction]
	store.restore_completed.emit(batch)
	assert_eq(_params("iap_restore_completed").size(), 0)
	storage.blocked = false
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(_params("iap_restore_completed").size(), 1)
	assert_eq(_params("iap_restore_completed")[0].restored_count, 1)
	assert_eq(_params("iap_purchase_completed").size(), 0)


func test_visible_shop_catalog_offers_are_once_and_alternative_is_not_shop() -> void:
	_allow()
	_ready_ads()
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1080, 1920)
	add_child_autofree(view)
	var shop: ShopSheet = ShopSheet.new()
	assert_eq(shop.configure(service, false, &"level"), OK)
	view.add_child(shop)
	assert_eq(_params("shop_opened").size(), 0)
	var alternative: VBoxContainer = VBoxContainer.new()
	assert_eq(shop.open_alternative(alternative, "level.hint.options"), OK)
	assert_eq(_params("shop_opened").size(), 0)
	assert_eq(shop.open_shop_content(), OK)
	assert_eq(_params("shop_opened").size(), 1)
	assert_eq(_params("ad_offer_shown").size(), 1)
	service.shop_changed.emit()
	assert_eq(shop.open(), OK)
	assert_eq(_params("shop_opened").size(), 1)
	assert_eq(_params("ad_offer_shown").size(), 1)
	assert_eq(_params("ad_offer_shown")[0].placement, "shop_coins")
	shop.close(true)
	alternative.free()
	await wait_process_frames(3)


func test_stuck_offer_uses_current_level_only_and_copies_payloads() -> void:
	_allow()
	nav.screen_changed.emit(1)
	var values: Dictionary = {"slot": 1, "trigger": "idle"}
	events.p2_analytics.emit(&"hint_stuck_offer_shown", values)
	values.trigger = "invalid_streak"
	assert_eq(_params("hint_stuck_offer_shown")[0].trigger, "idle")
	nav.screen = 2
	events.p2_analytics.emit(&"hint_stuck_offer_shown", values)
	assert_eq(_params("hint_stuck_offer_shown").size(), 1)


func test_denied_or_unknown_queue_does_not_block_purchase_success() -> void:
	assert_eq(service.purchase(COINS), OK)
	assert_eq(_params("iap_purchase_completed").size(), 0)
	assert_true(analytics.pending_count() > 0)
	events.consent_changed.emit(false)
	assert_eq(analytics.pending_count(), 0)
	assert_eq(service.purchase(COINS), OK)
	assert_eq(_params("iap_purchase_completed").size(), 0)
	assert_eq(economy.snapshot().coins, 2 * config.get_int(&"iap.coins_s.amount"))


func test_full_queue_never_changes_purchase_result_or_wallet() -> void:
	config.queue_limit = 2
	assert_eq(analytics.start_runtime(save, config, content, events), OK)
	assert_eq(service.purchase(COINS), OK)
	assert_eq(service.purchase(COINS), OK)
	assert_eq(analytics.pending_count(), 2)
	assert_eq(economy.snapshot().coins, 2 * config.get_int(&"iap.coins_s.amount"))


func test_interstitial_approved_offer_open_and_duplicate_callbacks() -> void:
	_allow()
	_ready_ads()
	ads.set_outcome(&"load_interstitial", &"ready")
	(save.get_clock() as FixedClock).ticks += 120000
	assert_eq(service.before_next_level(16), OK)
	assert_eq(service.before_next_level(17), OK)
	assert_eq(_params("ad_offer_shown").size(), 1)
	assert_eq(_params("ad_offer_shown")[0].ad_format, "interstitial")
	assert_eq(_params("ad_shown").size(), 0)
	ads.ad_opened.emit()
	ads.ad_opened.emit()
	ads.ad_closed.emit()
	assert_eq(_params("ad_shown").size(), 1)
	assert_eq(_params("ad_shown")[0].placement, "campaign_continue")
	assert_eq(_params("ad_reward_earned").size(), 0)


func _level() -> LevelScreen:
	var first: BoardState = BoardState.new(content.level_for_slot(1))
	assert_eq(progress.bind_board(first), OK)
	for index: int in first.get_level().word_count():
		for cell: Vector2i in first.get_level().word_cells(index):
			first.reveal_cell(cell)
	assert_eq(progress.complete_level(1), OK)
	assert_eq(save.complete_tutorial(), OK)
	for feature: StringName in [&"shuffle", &"bonus", &"hint", &"journey", &"reveal"]:
		assert_eq(save.mark_coach_seen(feature), OK)
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1080, 1920)
	add_child_autofree(view)
	var host: LevelScreen = load("res://features/level/level.tscn").instantiate()
	host.configure(save, content, 2, events)
	assert_eq(host.configure_p2(economy, config), OK)
	assert_eq(host.configure_paid_tools(progress, port, service), OK)
	assert_eq(host.configure_bonus_meter(), OK)
	assert_eq(host.configure_completion(service), OK)
	assert_eq(host.configure_offer_clock(save.get_clock()), OK)
	view.add_child(host)
	return host


func test_actual_level_stuck_and_hint_offer_emit_once_when_visible() -> void:
	_allow()
	_ready_ads()
	var host: LevelScreen = _level()
	await wait_process_frames(3)
	var listener_nav: FakeNav = nav
	listener_nav.slot = 2
	listener_nav.screen_changed.emit(1)
	(save.get_clock() as FixedClock).ticks += 1000
	host.stuck_offer.refresh()
	host.stuck_offer.refresh()
	assert_eq(_params("hint_stuck_offer_shown").size(), 1)
	assert_eq(_params("hint_stuck_offer_shown")[0].slot, 2)
	var wallet: Dictionary = save.get_section(&"economy")
	wallet.coins = 0
	wallet.items.hint = 0
	assert_eq(save.set_section(&"economy", wallet), OK)
	assert_eq(save.flush(), OK)
	host.paid_tools_ui.use_tool(&"hint")
	assert_eq(_params("ad_offer_shown").size(), 1)
	assert_eq(_params("ad_offer_shown")[0].placement, "hint")
	service.shop_changed.emit()
	assert_eq(_params("ad_offer_shown").size(), 1)
	host.paid_tools_ui.sheet.close(true)
	await wait_process_frames(3)


func test_actual_completed_level_reports_x2_offer_only_once() -> void:
	_allow()
	_ready_ads()
	var host: LevelScreen = _level()
	await wait_process_frames(3)
	var level: LevelData = host.controller.get_board().get_level()
	for index: int in level.word_count():
		var tiles: PackedInt32Array = []
		for letter: String in level.word(index):
			for tile: int in level.tile_count():
				if level.tile_letter(tile) == letter and tile not in tiles:
					tiles.append(tile)
					break
		host.controller.submit(tiles)
	await wait_process_frames(4)
	assert_true(host.completion_layer.is_visible_in_tree())
	assert_eq(_params("ad_offer_shown").size(), 1)
	assert_eq(_params("ad_offer_shown")[0].placement, "double_reward")
	service.shop_changed.emit()
	await wait_process_frames(2)
	assert_eq(_params("ad_offer_shown").size(), 1)


func test_unrelated_purchase_during_manual_restore_keeps_purchase_attribution() -> void:
	_allow()
	store.set_outcome(&"restore", &"manual")
	assert_eq(service.restore_purchases(), OK)
	assert_eq(service.purchase(COINS), OK)
	assert_eq(_params("iap_purchase_completed").size(), 1)
	assert_eq(_params("iap_restore_completed").size(), 0)


func test_invalid_verified_price_does_not_block_grant_or_leak_currency() -> void:
	_allow()
	store.transaction_updated.emit(
		StoreTransaction.new("invalid-price", COINS, StoreTransaction.State.PURCHASED, -1, "SECRET")
	)
	store.transaction_updated.emit(
		StoreTransaction.new(
			"invalid-currency", COINS, StoreTransaction.State.PURCHASED, 100, "usd"
		)
	)
	assert_eq(_params("iap_purchase_completed").size(), 0)
	assert_eq(economy.snapshot().coins, 2 * config.get_int(&"iap.coins_s.amount"))


func test_late_verified_callback_after_save_teardown_does_not_crash_or_finish() -> void:
	_allow()
	save.free()
	store.transaction_updated.emit(
		StoreTransaction.new(
			"stale-owner-key", COINS, StoreTransaction.State.PURCHASED, 1000000, "PLN"
		)
	)
	assert_eq(_params("iap_purchase_completed").size(), 0)
	for entry: Dictionary in store.calls.entries:
		assert_ne(entry.method, "finish")


func test_ad_failure_observer_cannot_recursively_repeat_expiration() -> void:
	_allow()
	_ready_ads()
	var counts: Array[int] = [0]
	var observer: Callable = func(name: StringName, _params: Dictionary) -> void:
		if name == &"ad_failed":
			counts[0] += 1
			if counts[0] < 3:
				service.expire_operation()
	events.p2_analytics.connect(observer)
	var reward: Callable = economy.grant.bind(&"rewarded_hint", {"hint": 1})
	assert_eq(service.request_rewarded(&"hint", reward), OK)
	ads.ad_failed.emit("provider text")
	assert_eq(counts[0], 1)
	assert_eq(_params("ad_failed").size(), 1)
	assert_eq(service.rewarded_state(), &"unavailable")
	counts[0] = 0
	assert_eq(service.request_rewarded(&"hint", reward), OK)
	service.expire_operation()
	assert_eq(counts[0], 1)
	assert_eq(_params("ad_failed").size(), 2)
	assert_eq(service.rewarded_state(), &"unavailable")
	events.p2_analytics.disconnect(observer)
