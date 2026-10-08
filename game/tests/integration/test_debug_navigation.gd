extends GutTest

const NAV_SCRIPT = preload("res://services/nav.gd")
const SAVE_SCRIPT = preload("res://services/save.gd")
const CONFIG_SCRIPT = preload("res://services/config.gd")
const CONTENT_SCRIPT = preload("res://services/content.gd")
const PATH: String = "user://t0057-debug-nav.json"
const FIXTURE: String = "res://tests/fixtures/content"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1_790_000_000


class DebugProbe:
	extends Node
	var save: SAVE_SCRIPT
	var content: CONTENT_SCRIPT
	var nav: NAV_SCRIPT
	var injected_at_ready: bool = false

	func configure(s: SAVE_SCRIPT, c: CONTENT_SCRIPT, n: NAV_SCRIPT) -> void:
		save = s
		content = c
		nav = n

	func _ready() -> void:
		injected_at_ready = save != null and save.is_loaded() and content != null and nav != null


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func _bundle() -> Dictionary:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var content: CONTENT_SCRIPT = CONTENT_SCRIPT.new()
	var nav: NAV_SCRIPT = NAV_SCRIPT.new()
	var host: Node = Node.new()
	for service: ServiceStub in [save, config, content, nav]:
		add_child_autofree(service)
		service.initialize(FixedClock.new())
	add_child_autofree(host)
	save.configure(
		SaveStorage.new(PATH), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	nav.configure(save, config, content)
	return {"save": save, "content": content, "nav": nav, "host": host}


func test_debug_disabled_preserves_screen() -> void:
	var bundle: Dictionary = _bundle()
	var nav: NAV_SCRIPT = bundle["nav"]
	assert_eq(nav.start(bundle["host"], FIXTURE), OK)
	nav.configure_debug(false)
	watch_signals(nav)
	assert_eq(nav.go_debug(), ERR_UNAVAILABLE)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.LEVEL)
	assert_eq(nav.level_slot(), 1)
	assert_true(nav.mounted_screen() is LevelScreen)
	assert_signal_not_emitted(nav, "screen_changed")


func test_debug_requires_loaded_save_and_host() -> void:
	var bundle: Dictionary = _bundle()
	var nav: NAV_SCRIPT = bundle["nav"]
	assert_eq(nav.go_debug(), ERR_UNCONFIGURED)
	assert_eq((bundle["save"] as SAVE_SCRIPT).load(), OK)
	assert_eq(nav.go_debug(), ERR_UNCONFIGURED)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.BOOT)


func test_debug_route_after_boot_and_home() -> void:
	var bundle: Dictionary = _bundle()
	var nav: NAV_SCRIPT = bundle["nav"]
	assert_eq(nav.start(bundle["host"], FIXTURE), OK)
	watch_signals(nav)
	assert_eq(nav.go_debug(), OK)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.DEBUG)
	assert_signal_emitted_with_parameters(nav, "screen_changed", [NAV_SCRIPT.Screen.DEBUG])
	assert_eq(nav.go_home(), OK)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.HOME)
	assert_eq(nav.go_to_level(1), OK)


func test_debug_diagnostics_after_missing_content() -> void:
	var bundle: Dictionary = _bundle()
	var nav: NAV_SCRIPT = bundle["nav"]
	assert_eq(nav.start(bundle["host"], "res://tests/fixtures/missing"), ERR_FILE_NOT_FOUND)
	assert_eq(nav.go_debug(), OK)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.DEBUG)


func test_freed_host_is_rejected() -> void:
	var bundle: Dictionary = _bundle()
	var nav: NAV_SCRIPT = bundle["nav"]
	var host: Node = bundle["host"]
	assert_eq(nav.start(host, FIXTURE), OK)
	host.free()
	assert_eq(nav.go_debug(), ERR_UNCONFIGURED)
	assert_eq(nav.current_screen(), NAV_SCRIPT.Screen.LEVEL)


func test_debug_services_are_injected_before_mount() -> void:
	var bundle: Dictionary = _bundle()
	var nav: NAV_SCRIPT = bundle["nav"]
	var host: Node = bundle["host"]
	nav.configure_screens(
		func(screen: int) -> Node:
			return DebugProbe.new() if screen == NAV_SCRIPT.Screen.DEBUG else null
	)
	assert_eq(nav.start(host, FIXTURE), OK)
	assert_eq(nav.go_debug(), OK)
	var probe: DebugProbe = nav.mounted_screen() as DebugProbe
	assert_not_null(probe)
	assert_true(probe.injected_at_ready)
	assert_same(probe.save, bundle["save"])
	assert_same(probe.content, bundle["content"])
	assert_same(probe.nav, nav)
	assert_eq(nav.go_home(), OK)
	assert_eq(host.get_child_count(), 0, "old scene must detach before its queued deletion")
	assert_null(nav.mounted_screen())
