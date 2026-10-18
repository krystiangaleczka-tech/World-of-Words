extends GutTest

const SERVICE: Script = preload("res://services/settings_policy.gd")
const SAVE: Script = preload("res://services/save.gd")
const MEMORY: Script = preload("res://tests/integration/test_level_hud.gd")
const FIXTURE: Script = preload("res://tests/integration/test_iap_settlement.gd")


class Browser:
	extends Node
	var calls: Array[String] = []
	var result: Variant = OK
	var hook: Callable

	func open(language: String) -> Variant:
		calls.append(language)
		if hook.is_valid():
			hook.call()
		return result


var service: SERVICE
var save: SAVE
var browser: Browser
var locale: String


func before_each() -> void:
	locale = TranslationServer.get_locale()
	service = SERVICE.new()
	save = SAVE.new()
	browser = Browser.new()
	for node: Node in [save, browser, service]:
		add_child(node)
	save.initialize(FIXTURE.FixedClock.new())
	save.configure(MEMORY.MemoryStorage.new())
	assert_eq(save.load(), OK)
	assert_eq(service.configure(save, browser.open), OK)


func after_each() -> void:
	for node: Node in [service, browser, save]:
		if is_instance_valid(node):
			node.free()
	TranslationServer.set_locale(locale)


func test_default_live_owner_and_invalid_bindings_preserve_configuration() -> void:
	var fresh: SERVICE = SERVICE.new()
	assert_eq(fresh.request_policy(), ERR_UNCONFIGURED)
	assert_eq(fresh.snapshot().state, &"unavailable")
	assert_false(fresh.owner_matches(save))
	fresh.free()
	assert_true(service.owner_matches(save))
	assert_false(service.owner_matches(null))
	assert_false(service.owner_matches(browser))
	var before: Dictionary = service.snapshot()
	assert_eq(service.configure(null, browser.open), ERR_UNCONFIGURED)
	assert_eq(service.configure(browser, browser.open), ERR_UNCONFIGURED)
	assert_eq(service.configure(save, Callable()), ERR_UNCONFIGURED)
	assert_eq(service.configure(save, func() -> Error: return OK), ERR_INVALID_PARAMETER)
	var unloaded: SAVE = SAVE.new()
	assert_eq(service.configure(unloaded, browser.open), ERR_UNCONFIGURED)
	unloaded.free()
	assert_eq(service.snapshot(), before)
	assert_eq(browser.calls.size(), 0)


func test_snapshot_is_fresh_and_reads_locale_changes_never_open_browser() -> void:
	var snapshot: Dictionary = service.snapshot()
	snapshot.state = &"handed_off"
	TranslationServer.set_locale("en")
	assert_eq(service.snapshot().state, &"idle")
	assert_true(service.snapshot().available)
	assert_eq(browser.calls.size(), 0)


func test_handoff_receives_only_committed_content_language_and_never_mutates_save() -> void:
	var before: Dictionary = save.committed_view()
	TranslationServer.set_locale("en")
	assert_eq(service.request_policy(), OK)
	assert_eq(browser.calls, ["pl"])
	assert_eq(service.snapshot().state, &"handed_off")
	assert_eq(service.snapshot().error, OK)
	assert_eq(save.committed_view(), before)


func test_valid_errors_invalid_return_and_explicit_retry_are_distinct_from_page_load() -> void:
	var states: Array[StringName] = []
	var observe: Callable = func() -> void: states.append(service.snapshot().state)
	service.changed.connect(observe)
	for result: Variant in [ERR_UNAVAILABLE, FAILED, "invalid", true, null, -1, 1000000, OK]:
		browser.result = result
		var expected: Error = ERR_INVALID_DATA
		if result is int and result >= OK and result <= ERR_PRINTER_ON_FIRE:
			expected = result as Error
		var count: int = browser.calls.size()
		assert_eq(service.request_policy(), expected)
		assert_eq(browser.calls.size(), count + 1)
		assert_eq(service.snapshot().state, &"handed_off" if expected == OK else &"failed")
		assert_eq(service.snapshot().error, expected)
		assert_eq(states[-2], &"requested")
	service.changed.disconnect(observe)


func _blocked() -> void:
	var before: Dictionary = service.snapshot()
	assert_eq(service.request_policy(), ERR_BUSY)
	assert_eq(service.configure(save, browser.open), ERR_BUSY)
	assert_eq(service.snapshot(), before)


func test_requested_terminal_and_dispatch_callbacks_reject_reentry() -> void:
	service.changed.connect(_blocked)
	browser.hook = _blocked
	assert_eq(service.request_policy(), OK)
	service.changed.disconnect(_blocked)
	browser.hook = Callable()
	assert_eq(browser.calls.size(), 1)


func test_lost_save_before_dispatch_is_safe_and_suppresses_handoff() -> void:
	var lose: Callable = func() -> void:
		if service.snapshot().state == &"requested":
			save.free()
	service.changed.connect(lose)
	assert_eq(service.request_policy(), ERR_UNCONFIGURED)
	service.changed.disconnect(lose)
	assert_eq(browser.calls.size(), 0)
	assert_eq(service.snapshot().state, &"unavailable")
	assert_false(service.owner_matches(null))


func test_lost_browser_before_dispatch_suppresses_call() -> void:
	var lose: Callable = func() -> void:
		if service.snapshot().state == &"requested":
			browser.free()
	service.changed.connect(lose)
	assert_eq(service.request_policy(), ERR_UNCONFIGURED)
	service.changed.disconnect(lose)
	assert_false(service.snapshot().available)


func test_lost_owner_during_dispatch_cannot_claim_handoff_and_reentry_needs_reconfigure() -> void:
	browser.hook = func() -> void: remove_child(service)
	assert_eq(service.request_policy(), ERR_UNCONFIGURED)
	assert_eq(browser.calls.size(), 1)
	assert_eq(service.snapshot().state, &"unavailable")
	browser.hook = Callable()
	add_child(service)
	assert_eq(service.request_policy(), ERR_UNCONFIGURED)
	assert_eq(service.configure(save, browser.open), OK)
	assert_eq(service.snapshot().state, &"idle")
	assert_eq(service.request_policy(), OK)
