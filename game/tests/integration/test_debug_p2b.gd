extends GutTest

const FIXTURE: Script = preload("res://tests/integration/test_level_tutorial.gd")
const CLOCK: Script = preload("res://services/debug/clock.gd")
const MONITOR: Script = preload("res://services/debug/diagnostics.gd")
const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const ANALYTICS: Script = preload("res://services/analytics.gd")
const EVENTS: Script = preload("res://services/events.gd")
const CONTENT: Script = preload("res://services/content.gd")
const MONETIZATION: Script = preload("res://services/monetization.gd")
var clock: Clock
var save: SAVE
var economy: ECONOMY
var analytics: ANALYTICS
var config: MemoryConfig
var events: EVENTS
var content: CONTENT
var monitor: RefCounted
var storage: FIXTURE.Storage
var locale: String
var pseudo: bool


class SourceClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1799971200 + 23 * 3600 + 30 * 60

	func monotonic_msec() -> int:
		return 1234

	func monotonic_usec() -> int:
		return 1234567

	func time_zone_bias_minutes() -> int:
		return 0


class MemoryConfig:
	extends "res://services/config.gd"

	func _create_cache(_path: String) -> SaveStorage:
		return FIXTURE.Storage.new()

	func _persist_remote(_document: Dictionary) -> Error:
		return OK


class Queue:
	extends AnalyticsQueue
	var fail: bool = false
	var entries: Array[Dictionary] = []

	func restore(_capacity: int, _validator: Callable) -> Dictionary:
		return {"error": OK, "events": entries.duplicate(true)}

	func replace(candidate: Array[Dictionary]) -> Error:
		if fail:
			return ERR_FILE_CANT_WRITE
		entries = candidate.duplicate(true)
		return OK

	func clear() -> Error:
		entries.clear()
		return OK


func before_each() -> void:
	locale = TranslationServer.get_locale()
	pseudo = TranslationServer.pseudolocalization_enabled
	TranslationServer.pseudolocalization_enabled = false
	TranslationServer.set_locale("pl")
	clock = CLOCK.new(SourceClock.new())
	save = SAVE.new()
	economy = ECONOMY.new()
	analytics = ANALYTICS.new()
	config = MemoryConfig.new()
	events = EVENTS.new()
	content = CONTENT.new()
	for node: Node in [save, economy, analytics, config, events, content]:
		add_child_autofree(node)
		node.initialize(clock)
	storage = FIXTURE.Storage.new()
	save.configure(storage)
	assert_eq(save.load(), OK)
	assert_eq(config.load(), OK)
	assert_eq(content.load_manifest("pl"), OK)
	economy.configure(save, config, events)
	assert_eq(analytics.load(), OK)
	assert_eq(analytics.configure_stub(100), OK)
	monitor = MONITOR.new()
	assert_eq(monitor.configure(clock, save, economy, config, analytics, events), OK)


func after_each() -> void:
	monitor.close()
	TranslationServer.set_locale(locale)
	TranslationServer.pseudolocalization_enabled = pseudo


func test_offset_timezone_reset_and_monotonic_values() -> void:
	var original: int = clock.unix_time_seconds()
	assert_eq(monitor.adjust_days(1), OK)
	assert_eq(clock.unix_time_seconds(), original + 86400)
	assert_eq(monitor.change_zone(1), OK)
	assert_eq(clock.time_zone_bias_minutes(), 60)
	assert_eq(clock.monotonic_msec(), 1234)
	assert_eq(clock.monotonic_usec(), 1234567)
	assert_eq(monitor.reset_clock(), OK)
	assert_eq(clock.unix_time_seconds(), original)
	assert_eq(clock.time_zone_bias_minutes(), 0)


func test_bounds_and_mismatched_clock_preserve_state() -> void:
	assert_eq(monitor.adjust_days(36526), ERR_INVALID_PARAMETER)
	assert_eq(monitor.change_zone(0), ERR_INVALID_PARAMETER)
	for index: int in 14:
		assert_eq(monitor.change_zone(1), OK)
	var before: Dictionary = monitor.snapshot().clock
	assert_eq(monitor.change_zone(1), ERR_INVALID_PARAMETER)
	assert_eq(monitor.snapshot().clock, before)
	assert_eq(
		monitor.configure(Clock.new(), save, economy, config, analytics, events), ERR_UNCONFIGURED
	)
	assert_true(monitor.snapshot().is_empty())


func test_actual_shop_cap_uses_injected_local_calendar_boundary() -> void:
	var service: MONETIZATION = MONETIZATION.new()
	add_child_autofree(service)
	service.initialize(clock)
	var ads: AdsFake = AdsFake.new()
	var consent: ConsentFake = ConsentFake.new()
	assert_eq(service.configure(save, config, events, consent, ads, false), OK)
	assert_eq(service.configure_iap(economy, IapFake.new()), OK)
	var section: Dictionary = save.get_section(&"monetization")
	section.shop_coins_ads = {
		"date": Time.get_datetime_string_from_unix_time(clock.unix_time_seconds()).left(10),
		"count": config.get_int(&"ads.rewarded.shop_coins.daily_cap")
	}
	assert_eq(save.set_section(&"monetization", section), OK)
	assert_eq(save.flush(), OK)
	assert_true(service.shop_snapshot().capped)
	assert_eq(monitor.change_zone(1), OK)
	assert_false(service.shop_snapshot().capped)
	assert_eq(monitor.reset_clock(), OK)
	assert_true(service.shop_snapshot().capped)
	assert_eq(monitor.adjust_days(1), OK)
	assert_false(service.shop_snapshot().capped)


func test_active_override_and_bucket_snapshots_are_copied() -> void:
	assert_eq(config.start_remote("12345678-1234-4234-8234-123456789abc", analytics), OK)
	assert_eq(
		config.accept_remote_document(
			{
				"version": 1,
				"values": {"ads.interstitial.min_levels_between": 5},
				"experiments":
				[
					{
						"id": "ad_frequency",
						"variants":
						[{"id": "control", "weight": 50}, {"id": "variant", "weight": 50}]
					}
				]
			}
		),
		OK
	)
	var state: Dictionary = monitor.snapshot()
	assert_eq(state.config[&"ads.interstitial.min_levels_between"], 5)
	assert_true(state.buckets.has("ad_frequency"))
	state.config[&"ads.interstitial.min_levels_between"] = 99
	state.buckets.clear()
	assert_eq(config.get_int(&"ads.interstitial.min_levels_between"), 5)
	assert_true(analytics.experiment_buckets().has("ad_frequency"))
	assert_false(state.config.has("install_id"))


func test_stub_log_is_bounded_copied_and_does_not_drain() -> void:
	for index: int in 40:
		assert_eq(analytics.track(&"settings_changed", {"setting": "s%d" % index}), OK)
	var state: Dictionary = monitor.snapshot()
	assert_eq(state.events.size(), 32)
	assert_true(state.events.front().params.contains("s8"))
	state.events.clear()
	assert_eq(monitor.snapshot().events.size(), 32)
	assert_eq(analytics.pending_count(), 40)
	assert_eq(analytics.track(&"settings_changed", {"setting": "x".repeat(1000)}), OK)
	assert_eq(monitor.snapshot().events.back().params.length(), 256)
	assert_eq(analytics.track(&"missing_event"), ERR_INVALID_DATA)
	assert_push_error("missing_event")
	assert_eq(monitor.snapshot().events.size(), 32)


func test_signal_parameters_cannot_mutate_original_queued_event() -> void:
	var handler: Callable = func(_name: StringName, params: Dictionary) -> void:
		params.setting = "changed"
	analytics.event_accepted.connect(handler)
	var input: Dictionary = {"setting": "original"}
	assert_eq(analytics.track(&"settings_changed", input), OK)
	input.setting = "later"
	assert_true(monitor.snapshot().events.back().params.contains("original"))
	var previous: AnalyticsAdapter = Platform.analytics
	var fake: AnalyticsFake = AnalyticsFake.new()
	Platform.analytics = fake
	assert_eq(analytics.flush(), OK)
	Platform.analytics = previous
	assert_eq(fake.calls.entries[0].arguments[1].setting, "original")
	analytics.event_accepted.disconnect(handler)


func test_full_stub_queue_rejects_without_logging() -> void:
	assert_eq(analytics.configure_stub(1), OK)
	assert_eq(analytics.track(&"settings_changed", {"setting": "first"}), OK)
	assert_eq(analytics.track(&"settings_changed", {"setting": "second"}), ERR_OUT_OF_MEMORY)
	assert_eq(monitor.snapshot().events.size(), 1)


func test_runtime_failed_persistence_denial_and_close_have_no_local_log() -> void:
	monitor.close()
	analytics = ANALYTICS.new()
	add_child_autofree(analytics)
	analytics.initialize(clock)
	var queue: Queue = Queue.new()
	assert_eq(analytics.start_runtime(save, config, content, events, queue), OK)
	assert_eq(monitor.configure(clock, save, economy, config, analytics, events), OK)
	queue.fail = true
	assert_eq(
		analytics.track(&"settings_changed", {"setting": "music_volume"}), ERR_FILE_CANT_WRITE
	)
	assert_true(monitor.snapshot().events.is_empty())
	queue.fail = false
	assert_eq(analytics.track(&"settings_changed", {"setting": "music_volume"}), OK)
	assert_eq(monitor.snapshot().events.size(), 1)
	assert_eq(analytics.pending_count(), 1)
	events.consent_changed.emit(false)
	assert_true(monitor.snapshot().events.is_empty())
	assert_eq(analytics.track(&"settings_changed", {"setting": "haptics_enabled"}), OK)
	assert_true(monitor.snapshot().events.is_empty())
	monitor.close()
	assert_true(analytics.event_accepted.get_connections().is_empty())
	assert_true(monitor.snapshot().is_empty())


func test_actual_ui_clock_buttons_locales_and_live_log_without_writes() -> void:
	var catalog: LocaleCatalog = LocaleCatalog.new()
	assert_eq(catalog.register_all(), OK)
	var panel: VBoxContainer = load("res://features/debug/diagnostics.gd").new()
	panel.configure(monitor)
	add_child(panel)
	var writes: int = storage.writes
	(panel.get_node("DayPlus") as TextButton).pressed.emit()
	assert_eq(monitor.snapshot().clock.offset_days, 1)
	var label: Label = panel.get_node("RuntimeState")
	assert_true(label.text.contains("Aktywna konfiguracja"))
	assert_true(label.text.contains("Przesunięcie dni: 1"))
	assert_eq(analytics.track(&"settings_changed", {"setting": "music_volume"}), OK)
	assert_true(label.text.contains("settings_changed"))
	TranslationServer.set_locale("en")
	await wait_process_frames(2)
	assert_true(label.text.contains("Active configuration"))
	TranslationServer.pseudolocalization_enabled = true
	await wait_process_frames(2)
	assert_eq(label.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED)
	assert_true(label.text.contains("ads.interstitial.first_slot"))
	(panel.get_node("ResetClock") as TextButton).pressed.emit()
	assert_eq(monitor.snapshot().clock.offset_days, 0)
	assert_eq(storage.writes, writes)
	assert_eq(analytics.pending_count(), 1)
	panel.free()
	assert_true(monitor.changed.get_connections().is_empty())
	catalog.unregister()
