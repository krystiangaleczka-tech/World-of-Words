extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONFIG: Script = preload("res://services/config.gd")
const EVENTS: Script = preload("res://services/events.gd")
const SERVICE: Script = preload("res://services/monetization.gd")
const SHOP: PackedScene = preload("res://features/shop/shop.tscn")
const PATH: String = "user://t0274-shop.json"
const COINS: String = "c.coins_s.v1"
const REMOVE: String = "nc.remove_forced_ads.v1"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1800000000

	func monotonic_msec() -> int:
		return 1000000


class CalendarService:
	extends "res://services/monetization.gd"

	func _local_day() -> String:
		return "2026-10-16"


class GateStorage:
	extends SaveStorage
	var blocked: bool = false

	func checkpoint(_step: StringName) -> Error:
		return ERR_CANT_CREATE if blocked else OK


var save: SAVE
var economy: ECONOMY
var config: CONFIG
var events: EVENTS
var service: SERVICE
var store: IapFake
var ads: AdsFake
var storage: GateStorage
var _motion: bool
var _locale: String
var _pseudo: bool


func before_each() -> void:
	_clean()
	_motion = Tokens.reduced_motion
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	Tokens.reduced_motion = true
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	save = SAVE.new()
	economy = ECONOMY.new()
	config = CONFIG.new()
	events = EVENTS.new()
	service = CalendarService.new()
	for node: Node in [save, economy, config, events, service]:
		add_child_autofree(node)
	var clock: FixedClock = FixedClock.new()
	save.initialize(clock)
	economy.initialize(clock)
	service.initialize(clock)
	storage = GateStorage.new(PATH)
	save.configure(storage, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert_eq(save.load(), OK)
	assert_eq(config.load(), OK)
	economy.configure(save, config, events)
	store = IapFake.new()
	store.set_products(
		[
			{"id": REMOVE, "restorable": true, "price": "12,99 zł"},
			{"id": COINS, "restorable": false, "price": "4,99 zł", "coins": 99999999}
		]
	)
	store.set_outcome(&"query_products", &"ready")
	store.set_outcome(&"purchase", &"success")
	store.set_outcome(&"restore", &"ready")
	store.set_outcome(&"fetch_unfinished", &"ready")
	ads = AdsFake.new()
	ads.set_outcome(&"initialize", &"ready")
	ads.set_outcome(&"load_rewarded", &"ready")
	ads.set_outcome(&"show_rewarded", &"reward")
	var consent: ConsentFake = ConsentFake.new()
	consent.set_outcome(&"request_info", &"not_required")
	assert_eq(service.configure(save, config, events, consent, ads, false), OK)
	assert_eq(service.configure_iap(economy, store), OK)


func after_each() -> void:
	Tokens.reduced_motion = _motion
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _view(size: Vector2i = Vector2i(1080, 1920)) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = size
	add_child_autofree(view)
	return view


func _shop(view: SubViewport, ios: bool = true) -> ShopSheet:
	var shop: ShopSheet = SHOP.instantiate()
	assert_eq(shop.configure(service, ios), OK)
	view.add_child(shop)
	return shop


func _count(method: String) -> int:
	var count: int = 0
	for call: Dictionary in store.calls.entries:
		if call.method == method:
			count += 1
	return count


func _activate(view: SubViewport, action: ActionButton) -> void:
	action.grab_focus()
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = pressed
		view.push_input(event)


func _ready_ads() -> void:
	assert_eq(service.before_next_level(6), OK)
	assert_true(service.ads_ready())


func test_binding_is_inactive_and_open_queries_copied_store_prices() -> void:
	var shop: ShopSheet = _shop(_view())
	assert_true(store.calls.entries.is_empty())
	assert_true(ads.calls.entries.is_empty())
	assert_eq(shop.open(), OK)
	assert_eq(_count("query_products"), 1)
	assert_eq(shop.remove_card.action_button().text, "12,99 zł")
	assert_eq(shop.coins_card.action_button().text, "4,99 zł")
	assert_eq(shop.remove_card.action_variant, &"primary")
	assert_eq(shop.coins_card.action_variant, &"secondary")
	var copied: Dictionary = service.shop_snapshot()
	copied.products[COINS].price = "tampered"
	assert_eq(service.shop_snapshot().products[COINS].price, "4,99 zł")
	assert_false(shop.busy)
	assert_eq(shop.balance.text, "0")


func test_native_coin_purchase_uses_config_amount_and_releases_async_busy_state() -> void:
	var view: SubViewport = _view()
	var shop: ShopSheet = _shop(view)
	shop.open()
	await get_tree().process_frame
	_activate(view, shop.coins_card.action_button())
	assert_eq(_count("purchase"), 1)
	assert_eq(economy.snapshot().coins, config.get_int(&"iap.coins_s.amount"))
	assert_eq(shop.balance.value, economy.snapshot().coins)
	assert_eq(shop.reward_burst.state, &"static")
	assert_eq(shop.toast.text_key, "shop.coins.added")
	store.set_outcome(&"purchase", &"success", false)
	shop.coins_card.action_button().pressed.emit()
	assert_true(shop.busy)
	assert_false(shop.close())
	assert_true(store.settle(store.operation_token()))
	assert_false(shop.busy)
	assert_true(shop.close())


func test_ownership_swaps_single_primary_and_restore_is_ios_request_only() -> void:
	var shop: ShopSheet = _shop(_view())
	shop.open()
	shop.remove_card.action_button().pressed.emit()
	assert_true(service.shop_snapshot().owned)
	assert_eq(shop.remove_card.action_variant, &"none")
	assert_eq(shop.coins_card.action_variant, &"primary")
	assert_true(shop.restore_button.visible)
	shop.restore_button.pressed.emit()
	assert_eq(_count("restore"), 1)
	assert_eq(shop.status_label.text, shop.tr("shop.restore.requested"))
	assert_eq(save.committed_view().sections.monetization.processed_transactions.size(), 1)
	shop.close()
	assert_eq(shop.configure(service, false), OK)
	shop.open()
	assert_false(shop.restore_button.visible)


func test_pending_cancel_and_failed_states_never_grant_before_purchased() -> void:
	var shop: ShopSheet = _shop(_view())
	shop.open()
	for outcome: StringName in [&"cancel", &"failed"]:
		store.set_outcome(&"purchase", outcome)
		shop.coins_card.action_button().pressed.emit()
		assert_eq(economy.snapshot().coins, 0)
		assert_false(shop.busy)
	store.set_outcome(&"purchase", &"deferred")
	shop.coins_card.action_button().pressed.emit()
	assert_eq(shop.coins_card.action_button().text, shop.tr("shop.action.retry"))
	assert_eq(economy.snapshot().coins, 0)
	assert_eq(store.set_transaction_state("fake_iap_3", StoreTransaction.State.PURCHASED), OK)
	shop.coins_card.action_button().pressed.emit()
	assert_eq(_count("purchase"), 3, "Pending CTA recovers rather than starts a second purchase")
	assert_eq(economy.snapshot().coins, config.get_int(&"iap.coins_s.amount"))


func test_missing_or_offline_prices_disable_purchase_and_watchdog_is_finite() -> void:
	store.set_outcome(&"query_products", &"ready", false)
	var shop: ShopSheet = _shop(_view())
	shop.open()
	assert_true(shop.coins_card.loading)
	assert_true(shop.coins_card.disabled)
	assert_eq(service.purchase(COINS), ERR_BUSY)
	var catalog_token: int = store.operation_token()
	var expired: bool = false
	for flow: Node in service.get_children():
		if flow is IapFlow:
			for timer: Timer in flow.get_children():
				assert_true(timer.one_shot and timer.ignore_time_scale and timer.wait_time > 0)
				timer.timeout.emit()
				expired = true
	assert_true(expired)
	assert_false(shop.coins_card.loading)
	assert_true(shop.coins_card.disabled)
	assert_true(
		store.settle(catalog_token), "Provider may deliver late, owner discards obsolete catalog"
	)
	assert_false(service.shop_snapshot().products[COINS].has("price"))
	store.set_outcome(&"query_products", &"error")
	assert_eq(service.request_products(), OK)
	assert_false(shop.coins_card.loading)
	assert_true(shop.coins_card.disabled)


func test_invalid_product_metadata_is_not_a_price_or_grant_source() -> void:
	store.set_products([{"id": COINS, "restorable": false, "price": {"coins": 99999}}])
	var shop: ShopSheet = _shop(_view())
	shop.open()
	assert_true(shop.coins_card.disabled)
	assert_false(service.shop_snapshot().products[COINS].has("price"))
	assert_eq(economy.snapshot().coins, 0)


func test_rewarded_coins_cap_and_no_fill_are_reactive_without_polling() -> void:
	_ready_ads()
	var shop: ShopSheet = _shop(_view())
	shop.open()
	ads.set_outcome(&"load_rewarded", &"no_fill")
	shop.free_card.action_button().pressed.emit()
	assert_true(shop.free_card.disabled)
	assert_eq(economy.snapshot().coins, 0)
	ads.set_outcome(&"load_rewarded", &"ready")
	# No polling or retry loop: a new visit offers another explicit attempt.
	assert_true(shop.free_card.disabled)
	assert_true(shop.close())
	assert_eq(shop.open(), OK)
	assert_false(shop.free_card.disabled)
	shop.free_card.action_button().pressed.emit()
	var cap: int = config.get_int(&"ads.rewarded.shop_coins.daily_cap")
	for index: int in range(cap - 1):
		shop.free_card.action_button().pressed.emit()
	assert_eq(economy.snapshot().coins, cap * config.get_int(&"economy.reward.rewarded_coins"))
	assert_true(shop.free_card.disabled)
	assert_eq(shop.free_card.sublabel_key, "shop.free_coins.capped")


func test_reward_write_retry_reuses_earned_callback_and_no_second_ad() -> void:
	_ready_ads()
	var shop: ShopSheet = _shop(_view())
	shop.open()
	storage.blocked = true
	shop.free_card.action_button().pressed.emit()
	assert_eq(service.shop_snapshot().reward_state, &"pending_reward")
	assert_eq(service.configure_iap(economy, IapFake.new()), ERR_BUSY)
	assert_false(shop.free_card.disabled)
	assert_eq(shop.free_card.action_button().text, shop.tr("shop.action.retry"))
	storage.blocked = false
	shop.free_card.action_button().pressed.emit()
	assert_eq(economy.snapshot().coins, config.get_int(&"economy.reward.rewarded_coins"))
	assert_eq(service.shop_snapshot().reward_state, &"ready")
	assert_false(shop.free_card.loading)
	var shows: int = 0
	for call: Dictionary in ads.calls.entries:
		if call.method == "show_rewarded":
			shows += 1
	assert_eq(shows, 1)


func test_exit_reentry_retains_current_state_without_duplicate_actions() -> void:
	var view: SubViewport = _view()
	var shop: ShopSheet = _shop(view)
	shop.open()
	view.remove_child(shop)
	view.add_child(shop)
	shop.open()
	shop.coins_card.action_button().pressed.emit()
	assert_eq(_count("purchase"), 1)
	assert_eq(economy.snapshot().coins, config.get_int(&"iap.coins_s.amount"))
	assert_eq(shop.balance.value, economy.snapshot().coins)


func test_layout_matrix_scrolls_and_keeps_all_purchase_buttons_in_sheet() -> void:
	assert_eq(economy.grant(&"test_shop_layout", {"coins": 1234567890}), OK)
	for size: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				TranslationServer.pseudolocalization_enabled = pseudo
				var view: SubViewport = _view(size)
				var shop: ShopSheet = SHOP.instantiate()
				shop.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				assert_eq(shop.configure(service, true), OK)
				view.add_child(shop)
				assert_eq(shop.open(), OK)
				await get_tree().process_frame
				await get_tree().process_frame
				var scroll: ScrollContainer = (
					shop.find_children("*", "ScrollContainer", true, false)[0]
				)
				for card: Card in [shop.remove_card, shop.coins_card, shop.free_card]:
					assert_lte(card.size.x, scroll.size.x)
					assert_gte(card.action_button().size.y, Tokens.Touch.MIN_TARGET)
				assert_lte(shop.balance.size.x, scroll.size.x)
				assert_true(shop.restore_button.visible)
				shop.free()


func test_reentrant_iap_listeners_cannot_replace_flow_during_dispatch_or_notification() -> void:
	var replacement: IapFake = IapFake.new()
	var attempts: Array[Error] = []
	var on_shop: Callable = func() -> void:
		attempts.append(service.configure_iap(economy, replacement))
	service.shop_changed.connect(on_shop, CONNECT_ONE_SHOT)
	assert_eq(service.process_unfinished_transactions(), OK)
	assert_eq(attempts, [ERR_BUSY])
	assert_eq(_count("fetch_unfinished"), 1)
	store.set_outcome(&"purchase", &"error", false)
	assert_eq(service.purchase(COINS), OK)
	var on_state: Callable = func(_id: String, _state: StringName, _error: Error) -> void:
		attempts.append(service.configure_iap(economy, replacement))
	service.purchase_state_changed.connect(on_state, CONNECT_ONE_SHOT)
	assert_true(store.settle(store.operation_token()))
	assert_eq(attempts, [ERR_BUSY, ERR_BUSY])
	assert_eq(service.purchase_state(), &"failed")
	assert_eq(service.configure_iap(economy, replacement), OK)


func test_external_ad_start_and_foreign_pending_reward_do_not_offer_shop_retry() -> void:
	_ready_ads()
	var shop: ShopSheet = _shop(_view())
	shop.open()
	ads.set_outcome(&"show_rewarded", &"reward", false)
	var reward: Callable = economy.grant.bind(&"rewarded_hint", {"hint": 1})
	assert_eq(service.request_rewarded(&"hint", reward), OK)
	assert_true(shop.busy)
	assert_true(shop.free_card.disabled)
	assert_false(shop.close())
	storage.blocked = true
	assert_true(ads.settle(ads.operation_token()))
	assert_eq(service.rewarded_state(), &"pending_reward")
	assert_eq(service.shop_snapshot().reward_state, &"unavailable")
	assert_false(shop.busy)
	assert_true(shop.coins_card.disabled)
	assert_true(shop.close())
	assert_eq(shop.open(), OK)
	assert_true(shop.free_card.disabled)
	storage.blocked = false
	assert_eq(service.request_rewarded(&"hint", reward), OK)
	assert_false(shop.busy)
	assert_false(shop.free_card.disabled)
	assert_eq(economy.snapshot().items.hint, 1)


func test_restore_failures_replace_request_caption_and_offline_panel_retries_prices() -> void:
	var shop: ShopSheet = _shop(_view())
	shop.open()
	store.set_outcome(&"restore", &"error")
	shop.restore_button.pressed.emit()
	assert_eq(shop.status_label.text, tr("shop.state.failed"))
	store.set_outcome(&"restore", &"ready")
	shop.restore_button.pressed.emit()
	assert_eq(shop.status_label.text, tr("shop.restore.requested"))
	store.set_outcome(&"restore", &"error", false)
	shop.restore_button.pressed.emit()
	assert_eq(shop.status_label.text, tr("shop.restore.requested"))
	assert_true(store.settle(store.operation_token()))
	assert_eq(shop.status_label.text, tr("shop.state.failed"))
	store.set_outcome(&"query_products", &"error")
	assert_eq(service.request_products(), OK)
	assert_true(shop.offline_panel.visible)
	assert_false(shop.coins_card.visible)
	store.set_outcome(&"query_products", &"ready")
	shop.offline_panel.action_requested.emit()
	assert_false(shop.offline_panel.visible)
	assert_true(shop.coins_card.visible)


func test_duplicate_product_ids_fail_closed_without_grants() -> void:
	store.set_outcome(&"query_products", &"ready", false)
	var shop: ShopSheet = _shop(_view())
	shop.open()
	# Fake's validated setter deduplicates. Inject malformed provider callback directly.
	var products: Array[Dictionary] = [
		{"id": COINS, "restorable": false, "price": "4,99 zł"},
		{"id": COINS, "restorable": false, "price": "0,01 zł"}
	]
	store.products_received.emit(products)
	assert_eq(service.shop_snapshot().catalog_state, &"unavailable")
	assert_true(shop.coins_card.disabled)
	assert_eq(economy.snapshot().coins, 0)


func test_ad_start_listener_cannot_free_helper_or_dispatch_cancelled_request() -> void:
	_ready_ads()
	var attempts: Array[Error] = []
	var on_shop: Callable = func() -> void:
		service.expire_operation()
		attempts.append(
			service.configure(save, config, events, ConsentFake.new(), AdsFake.new(), false)
		)
	service.shop_changed.connect(on_shop, CONNECT_ONE_SHOT)
	assert_eq(service.request_shop_reward(), OK)
	assert_eq(attempts, [ERR_BUSY])
	var loads: int = 0
	for call: Dictionary in ads.calls.entries:
		if call.method == "load_rewarded":
			loads += 1
	assert_eq(loads, 0, "Expired start must not dispatch an obsolete provider operation")
	assert_eq(economy.snapshot().coins, 0)
