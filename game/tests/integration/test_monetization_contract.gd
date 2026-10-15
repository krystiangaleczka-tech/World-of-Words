extends GutTest

const MONETIZATION_SCRIPT: Script = preload("res://services/monetization.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const ECONOMY_SCRIPT: Script = preload("res://services/economy.gd")
const PROGRESS_SCRIPT: Script = preload("res://services/progress.gd")
const PLATFORM_SCRIPT: Script = preload("res://platform/platform.gd")
const SIGNALS: Dictionary = {
	"next_level_cleared": ["slot", "steps"],
	"rewarded_finished": ["placement", "offer_id", "outcome"],
	"ad_presentation_changed": ["active"],
	"purchase_updated": ["product_id", "state"],
}


class SaveSpy:
	extends "res://services/save.gd"
	var calls: int = 0

	func get_section(_section: StringName) -> Dictionary:
		calls += 1
		return {}

	func set_section(_section: StringName, _value: Dictionary) -> Error:
		calls += 1
		return OK

	func flush() -> Error:
		calls += 1
		return OK

	func committed_view() -> Dictionary:
		calls += 1
		return {}


func _new_service() -> MONETIZATION_SCRIPT:
	var service: MONETIZATION_SCRIPT = MONETIZATION_SCRIPT.new()
	add_child_autofree(service)
	watch_signals(service)
	return service


func _assert_inert(service: MONETIZATION_SCRIPT) -> void:
	assert_false(service.is_ready())
	assert_eq(service.start_session(), ERR_UNCONFIGURED)
	assert_eq_deep(
		service.consent_state(), {"ump": &"unknown", "att": &"unknown", "ads_initialized": false}
	)
	assert_false(service.privacy_options_available())
	assert_eq(service.show_privacy_options(), ERR_UNCONFIGURED)
	for slot: int in [-1, 0, 1, 6, 16, 200]:
		assert_eq(service.before_next_level(slot), ERR_UNCONFIGURED)
	for placement: StringName in [&"hint", &"double", &"shop_coins", &"unknown", &""]:
		assert_false(service.rewarded_available(placement))
		assert_eq(service.show_rewarded(placement), 0)
	assert_false(service.has_remove_forced_ads())
	for product: StringName in [&"nc.remove_forced_ads.v1", &"c.coins_s.v1", &"unknown"]:
		assert_eq(service.purchase(product), ERR_UNCONFIGURED)
	assert_eq(service.restore_purchases(), ERR_UNCONFIGURED)
	for signal_name: String in SIGNALS:
		assert_signal_not_emitted(service, signal_name)


func test_typed_interface_fails_closed_before_initialization() -> void:
	var service: MONETIZATION_SCRIPT = _new_service()
	assert_null(service.get_clock())
	_assert_inert(service)


func test_configured_stub_stays_inert_without_dependency_calls() -> void:
	var service: MONETIZATION_SCRIPT = _new_service()
	var save: SaveSpy = SaveSpy.new()
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var bus: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	var economy: ECONOMY_SCRIPT = ECONOMY_SCRIPT.new()
	var progress: PROGRESS_SCRIPT = PROGRESS_SCRIPT.new()
	var platform: PLATFORM_SCRIPT = PLATFORM_SCRIPT.new()
	for node: Node in [save, config, bus, economy, progress, platform]:
		add_child_autofree(node)
	watch_signals(bus)
	var clock: Clock = Clock.new()
	service.initialize(clock)
	for ios: bool in [false, true]:
		service.configure(save, config, bus, economy, progress, platform, ios)
		_assert_inert(service)
	assert_same(service.get_clock(), clock)
	assert_eq(save.calls, 0)
	assert_eq((platform.ads as AdsFake).calls.entries.size(), 0)
	assert_eq((platform.consent as ConsentFake).calls.entries.size(), 0)
	assert_eq((platform.iap as IapFake).calls.entries.size(), 0)
	assert_signal_not_emitted(bus, "consent_changed")
	assert_signal_not_emitted(bus, "economy_changed")


func test_returned_consent_state_is_independent() -> void:
	var service: MONETIZATION_SCRIPT = _new_service()
	var first: Dictionary = service.consent_state()
	first["ump"] = &"obtained"
	first["ads_initialized"] = true
	assert_eq(service.consent_state()["ump"], &"unknown")
	assert_false(service.consent_state()["ads_initialized"])


func test_signals_match_the_contract() -> void:
	var service: MONETIZATION_SCRIPT = _new_service()
	var found: Dictionary = {}
	for entry: Dictionary in service.get_signal_list():
		var names: Array[String] = []
		for argument: Dictionary in entry["args"]:
			names.append(str(argument["name"]))
		found[str(entry["name"])] = names
	for signal_name: String in SIGNALS:
		assert_true(found.has(signal_name), signal_name)
		assert_eq_deep(found.get(signal_name, []), SIGNALS[signal_name])


func test_adapters_declare_contract_signals_without_emitting() -> void:
	var ads: AdsFake = AdsFake.new()
	var consent: ConsentFake = ConsentFake.new()
	assert_true(ads.has_signal("interstitial_loaded"))
	assert_true(consent.has_signal("analytics_purpose_resolved"))
	watch_signals(ads)
	watch_signals(consent)
	ads.load_interstitial()
	consent.request_info()
	assert_signal_not_emitted(ads, "interstitial_loaded")
	assert_signal_not_emitted(consent, "analytics_purpose_resolved")


func test_canonical_placements_and_products() -> void:
	assert_eq(MONETIZATION_SCRIPT.PLACEMENTS, [&"hint", &"double", &"shop_coins"])
	assert_eq(MONETIZATION_SCRIPT.PRODUCTS, [&"nc.remove_forced_ads.v1", &"c.coins_s.v1"])
