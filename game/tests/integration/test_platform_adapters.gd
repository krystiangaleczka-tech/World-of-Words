extends GutTest

const PLATFORM_SCRIPT: Script = preload("res://platform/platform.gd")


func _container() -> ServiceStub:
	var container: ServiceStub = PLATFORM_SCRIPT.new() as ServiceStub
	add_child_autofree(container)
	return container


func test_headless_boot_has_eight_fakes_without_calls() -> void:
	Platform.initialize(Clock.new())
	assert_is(Platform.ads, AdsFake)
	assert_is(Platform.iap, IapFake)
	assert_is(Platform.analytics, AnalyticsFake)
	assert_is(Platform.crash, CrashFake)
	assert_is(Platform.consent, ConsentFake)
	assert_is(Platform.haptics, HapticsFake)
	assert_is(Platform.review, ReviewFake)
	assert_is(Platform.notifications, NotificationsFake)
	var fake: AdsFake = Platform.ads as AdsFake
	assert_eq(fake.calls.entries.size(), 0)


func test_editor_headless_desktop_and_cli_never_invoke_sdk_factory() -> void:
	var container: PLATFORM_SCRIPT = _container() as PLATFORM_SCRIPT
	var sdk: AdsAdapter = AdsAdapter.new()
	var factory: Callable = func() -> AdsAdapter:
		fail_test("SDK factory must not run in forced Fake contexts")
		return sdk
	assert_true(container.register_sdk(&"ads", &"TestAds", factory))
	for facts: Array in [
		["Android", true, false, []],
		["iOS", false, true, []],
		["Linux", false, false, []],
		["Android", false, false, ["--fakes"]]
	]:
		container.select_adapters(
			facts[0],
			facts[1],
			facts[2],
			PackedStringArray(facts[3]),
			PackedStringArray(["TestAds"])
		)
		assert_is(container.ads, AdsFake)


func test_device_requires_plugin_and_valid_adapter() -> void:
	var container: PLATFORM_SCRIPT = _container() as PLATFORM_SCRIPT
	var sdk: AdsAdapter = AdsAdapter.new()
	assert_true(container.register_sdk(&"ads", &"TestAds", func() -> AdsAdapter: return sdk))
	container.select_adapters("Android", false, false, [], [])
	assert_is(container.ads, AdsFake)
	container.select_adapters("Android", false, false, [], ["TestAds"])
	assert_same(container.ads, sdk)
	assert_is(container.iap, IapFake)
	container.select_adapters("iOS", false, false, [], ["TestAds"])
	assert_same(container.ads, sdk)
	assert_true(
		container.register_sdk(&"ads", &"TestAds", func() -> RefCounted: return RefCounted.new())
	)
	container.select_adapters("Android", false, false, [], ["TestAds"])
	assert_is(container.ads, AdsFake)
	assert_false(container.register_sdk(&"unknown", &"TestAds", Callable()))


func test_per_service_fake_override_preserves_other_adapter() -> void:
	var container: PLATFORM_SCRIPT = _container() as PLATFORM_SCRIPT
	var sdk: AdsAdapter = AdsAdapter.new()
	container.register_sdk(&"ads", &"TestAds", func() -> AdsAdapter: return sdk)
	container.select_adapters("Android", false, false, [], ["TestAds"])
	var previous: IapAdapter = container.iap
	assert_true(container.force_fake(&"ads"))
	assert_is(container.ads, AdsFake)
	assert_same(container.iap, previous)
	container.select_adapters("Android", false, false, [], ["TestAds"])
	assert_is(container.ads, AdsFake)
	assert_false(container.force_fake(&"unknown"))


func test_all_fake_operations_record_calls_without_signalling_success() -> void:
	var ads: AdsFake = AdsFake.new()
	watch_signals(ads)
	ads.initialize(ConsentAdapter.State.UNKNOWN)
	ads.load_rewarded()
	ads.show_rewarded()
	ads.load_interstitial()
	ads.show_interstitial()
	assert_eq(ads.calls.entries.size(), 5)
	assert_signal_not_emitted(ads, "reward_earned")
	var iap: IapFake = IapFake.new()
	watch_signals(iap)
	iap.query_products(["product"])
	iap.purchase("product")
	iap.finish(StoreTransaction.new("token", "product", StoreTransaction.State.PURCHASED))
	iap.fetch_unfinished()
	iap.restore()
	assert_eq(iap.calls.entries.size(), 5)
	assert_signal_not_emitted(iap, "transaction_updated")
	var consent: ConsentFake = ConsentFake.new()
	consent.request_info()
	consent.show_form_if_required()
	consent.request_att()
	consent.show_privacy_options()
	assert_eq(consent.calls.entries.size(), 4)
	var analytics: AnalyticsFake = AnalyticsFake.new()
	analytics.log_event("fixture", {"n": 1})
	analytics.set_user_property("fixture", "value")
	assert_eq(analytics.calls.entries.size(), 2)
	var crash: CrashFake = CrashFake.new()
	crash.record("fixture")
	crash.set_key("fixture", "value")
	assert_eq(crash.calls.entries.size(), 2)
	var haptics: HapticsFake = HapticsFake.new()
	haptics.play("tick")
	assert_eq(haptics.calls.entries.size(), 1)
	var review: ReviewFake = ReviewFake.new()
	review.request_review()
	assert_eq(review.calls.entries.size(), 1)


func test_fake_outcomes_are_scriptable_without_real_time_or_grants() -> void:
	var ads: AdsFake = AdsFake.new()
	watch_signals(ads)
	ads.ad_failed.emit("no_fill")
	ads.ad_closed.emit()
	ads.reward_earned.emit()
	assert_signal_emitted_with_parameters(ads, "ad_failed", ["no_fill"])
	assert_signal_emit_count(ads, "reward_earned", 1)
	var iap: IapFake = IapFake.new()
	watch_signals(iap)
	var transaction: StoreTransaction = StoreTransaction.new("durable-key", "product")
	iap.transaction_updated.emit(transaction)
	assert_signal_emitted_with_parameters(iap, "transaction_updated", [transaction])
	assert_eq(transaction.state, StoreTransaction.State.PENDING)
	iap.purchase_failed.emit("cancel")
	assert_signal_emitted_with_parameters(iap, "purchase_failed", ["cancel"])
	var consent: ConsentFake = ConsentFake.new()
	watch_signals(consent)
	consent.consent_resolved.emit(ConsentAdapter.State.OBTAINED)
	assert_signal_emitted_with_parameters(
		consent, "consent_resolved", [ConsentAdapter.State.OBTAINED]
	)


func test_recorded_arguments_are_snapshots() -> void:
	var analytics: AnalyticsFake = AnalyticsFake.new()
	var params: Dictionary = {"nested": {"n": 1}}
	analytics.log_event("fixture", params)
	params["nested"]["n"] = 2
	assert_eq(analytics.calls.entries[0]["arguments"][1]["nested"]["n"], 1)
	var iap: IapFake = IapFake.new()
	var transaction: StoreTransaction = StoreTransaction.new("original", "product")
	iap.finish(transaction)
	transaction.store_key = "changed"
	assert_eq(iap.calls.entries[0]["arguments"][0]["store_key"], "original")
