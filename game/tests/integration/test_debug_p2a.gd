extends GutTest

const FIXTURE: Script = preload("res://tests/integration/test_level_tutorial.gd")
const TOOLS: Script = preload("res://services/debug/tools.gd")
const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONFIG: Script = preload("res://services/config.gd")
const EVENTS: Script = preload("res://services/events.gd")
const PLATFORM: Script = preload("res://platform/platform.gd")
const CONTENT: Script = preload("res://services/content.gd")
const NAV: Script = preload("res://services/nav.gd")
var storage: FIXTURE.Storage
var save: SAVE
var economy: ECONOMY
var config: CONFIG
var platform: PLATFORM
var port: RefCounted
var events: EVENTS
var locale: String


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1800000000


func before_each() -> void:
	locale = TranslationServer.get_locale()
	TranslationServer.set_locale("pl")
	storage = FIXTURE.Storage.new()
	save = SAVE.new()
	economy = ECONOMY.new()
	config = CONFIG.new()
	platform = PLATFORM.new()
	events = EVENTS.new()
	for node: Node in [save, economy, config, platform, events]:
		add_child_autofree(node)
	save.initialize(FixedClock.new())
	save.configure(storage)
	assert_eq(save.load(), OK)
	assert_eq(config.load(), OK)
	economy.initialize(FixedClock.new())
	economy.configure(save, config, events)
	port = TOOLS.new()
	port.configure(save, economy, config, platform)


func after_each() -> void:
	TranslationServer.set_locale(locale)


func test_wallet_grant_remove_validation_and_reload() -> void:
	for item: String in ["coins", "hint", "reveal"]:
		assert_eq(port.modify(item, 2), OK)
		assert_eq(port.modify(item, 1, true), OK)
	assert_eq(economy.snapshot().coins, 1)
	assert_eq(economy.snapshot().items, {"hint": 1, "reveal": 1})
	assert_eq(port.modify("unknown", 1), ERR_INVALID_PARAMETER)
	assert_eq(port.modify("coins", 0), ERR_INVALID_PARAMETER)
	assert_eq(port.modify("hint", -1), ERR_INVALID_PARAMETER)
	assert_ne(port.modify("reveal", 2, true), OK)
	assert_ne(port.modify("coins", WalletSnapshot.MAX_SAFE_COUNT), OK)
	assert_eq(save.load(), OK)
	assert_eq(economy.snapshot().coins, 1)
	assert_eq(economy.journal().back().reason, "debug")


func test_failed_wallet_retry_does_not_double_grant() -> void:
	storage.fail_at = storage.writes + 1
	assert_ne(port.modify("coins", 100), OK)
	assert_eq(economy.snapshot().coins, 0)
	assert_ne(port.set_remove_forced_ads(true), OK)
	assert_ne(port.modify("hint", 1), OK)
	assert_eq(port.modify("coins", 100), OK)
	assert_eq(economy.snapshot().coins, 100)
	assert_eq(economy.journal().size(), 1)


func test_entitlement_retry_is_committed_only_and_blocks_competing_actions() -> void:
	storage.fail_at = storage.writes + 1
	assert_ne(port.set_remove_forced_ads(true), OK)
	assert_false(port.snapshot().remove_forced_ads)
	assert_false(save.get_section(&"monetization").remove_forced_ads)
	assert_eq(port.set_remove_forced_ads(false), ERR_BUSY)
	assert_eq(port.modify("coins", 1), ERR_BUSY)
	assert_eq(port.set_remove_forced_ads(true), OK)
	assert_true(port.snapshot().remove_forced_ads)
	assert_eq(port.set_remove_forced_ads(false), OK)
	assert_false(port.snapshot().remove_forced_ads)
	assert_eq(save.load(), OK)
	assert_false(port.snapshot().remove_forced_ads)
	assert_true(economy.journal().is_empty())


func test_disabled_cross_owner_and_dirty_sections_are_rejected() -> void:
	port.configure(save, economy, config, platform, false)
	assert_eq(port.modify("coins", 1), ERR_UNAVAILABLE)
	assert_eq(port.set_remove_forced_ads(true), ERR_UNAVAILABLE)
	assert_eq(port.ad_outcome(&"fill"), ERR_UNAVAILABLE)
	assert_eq(port.iap_outcome(&"success"), ERR_UNAVAILABLE)
	assert_true(port.snapshot().is_empty())
	var other: SAVE = SAVE.new()
	add_child_autofree(other)
	port.configure(other, economy, config, platform)
	assert_false(port.matches_save(other))
	assert_eq(port.modify("coins", 1), ERR_UNAVAILABLE)
	port.configure(save, economy, config, platform)
	var section: Dictionary = save.get_section(&"monetization")
	section.remove_forced_ads = true
	assert_eq(save.set_section(&"monetization", section), OK)
	assert_eq(port.set_remove_forced_ads(false), ERR_BUSY)
	var unready: ECONOMY = ECONOMY.new()
	add_child_autofree(unready)
	unready.configure(save, config, events)
	port.configure(save, unready, config, platform)
	assert_false(port.matches_save(save))
	assert_true(port.snapshot().is_empty())


func test_fake_controls_never_call_providers_or_grant_and_real_adapters_are_refused() -> void:
	var ads: AdsFake = platform.ads
	var iap: IapFake = platform.iap
	assert_eq(iap.set_products([{"id": "c.coins_s.v1", "restorable": false}]), OK)
	watch_signals(ads)
	watch_signals(iap)
	var writes: int = storage.writes
	for outcome: StringName in [&"fill", &"no_fill"]:
		assert_eq(port.ad_outcome(outcome), OK)
		assert_true(ads.calls.entries.is_empty())
		ads.load_rewarded()
		ads.calls.entries.clear()
	assert_signal_emit_count(ads, "rewarded_loaded", 1)
	assert_signal_emit_count(ads, "ad_failed", 1)
	for outcome: StringName in [&"success", &"cancel", &"pending", &"crash_before_finish"]:
		assert_eq(port.iap_outcome(outcome), OK)
		assert_true(iap.calls.entries.is_empty())
		iap.purchase("c.coins_s.v1")
		var transaction: StoreTransaction = get_signal_parameters(iap, "transaction_updated")[0]
		var expected: StoreTransaction.State = StoreTransaction.State.PURCHASED
		if outcome == &"cancel":
			expected = StoreTransaction.State.CANCELLED
		elif outcome == &"pending":
			expected = StoreTransaction.State.PENDING
		assert_eq(transaction.state, expected)
		if outcome == &"crash_before_finish":
			iap.finish(transaction)
			assert_eq(iap.set_outcome(&"fetch_unfinished", &"ready"), OK)
			iap.fetch_unfinished()
			assert_eq(
				get_signal_parameters(iap, "transaction_updated")[0].store_key,
				transaction.store_key
			)
		iap.calls.entries.clear()
	assert_signal_emit_count(iap, "transaction_updated", 7)
	assert_eq(storage.writes, writes)
	assert_eq(economy.snapshot().coins, 0)
	platform.ads = AdsAdapter.new()
	platform.iap = IapAdapter.new()
	assert_eq(port.ad_outcome(&"fill"), ERR_UNAVAILABLE)
	assert_eq(port.iap_outcome(&"success"), ERR_UNAVAILABLE)


func test_nav_injects_actual_scrollable_panel_and_ui_actions() -> void:
	var content: CONTENT = CONTENT.new()
	var nav: NAV = NAV.new()
	var host: Control = Control.new()
	for node: Node in [content, nav, host]:
		add_child_autofree(node)
	nav.configure(save, config, content, port)
	assert_eq(nav.start(host), OK)
	assert_eq(nav.go_debug(), OK)
	var screen: Node = nav.mounted_screen()
	var scroll: ScrollContainer = screen.find_child("DebugScroll", true, false)
	var panel: Node = screen.find_child("P2Tools", true, false)
	assert_not_null(scroll)
	assert_not_null(panel)
	(panel.get_node("coinsGrant") as TextButton).pressed.emit()
	assert_eq(economy.snapshot().coins, config.get_int(&"economy.price.hint"))
	(panel.get_node("hintGrant") as TextButton).pressed.emit()
	assert_eq(economy.snapshot().items.hint, 1)
	(panel.get_node("Entitlement") as TextButton).pressed.emit()
	assert_true(port.snapshot().remove_forced_ads)
	assert_true((panel.get_node("Wallet") as Label).text.contains("Brak reklam wymuszonych: Tak"))
	for action: String in [
		"fill", "no_fill", "success", "cancel", "pending", "crash_before_finish"
	]:
		(panel.get_node(action) as TextButton).pressed.emit()
		assert_ne((panel.get_node(action) as TextButton).text, "debug.p2." + action)

	TranslationServer.set_locale("en")
	await wait_process_frames(2)
	assert_true((panel.get_node("Wallet") as Label).text.contains("Remove Forced Ads: Yes"))
	assert_false((panel.get_node("Wallet") as Label).text.contains("remove_forced_ads"))
