extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
const LEVEL_SCENE: PackedScene = preload("res://features/level/level.tscn")


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		document = JSON.parse_string(text)
		return OK


class NavigationOwner:
	extends Node
	var debug_calls: int = 0

	func go_debug() -> Error:
		debug_calls += 1
		return OK


var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _global_route_used: bool = false
var _locale: String


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_global_route_used = false
	_save = SAVE_SCRIPT.new()
	_content = CONTENT_SCRIPT.new()
	add_child_autofree(_save)
	add_child_autofree(_content)
	_save.initialize(FixedClock.new())
	_save.configure(MemoryStorage.new())
	assert_eq(_save.load(), OK)
	assert_eq(_content.load_manifest("pl", "res://tests/fixtures/content"), OK)


func after_each() -> void:
	if _global_route_used:
		assert_eq(Nav.go_home(), OK)
		Nav.configure_screens(Callable())
		Nav.configure_debug(true)
		Nav.configure(Save, Config, Content)
	TranslationServer.set_locale(_locale)


func _screen() -> LevelScreen:
	var screen: LevelScreen = LEVEL_SCENE.instantiate() as LevelScreen
	screen.configure(_save, _content, 1)
	add_child_autofree(screen)
	return screen


func _owner() -> NavigationOwner:
	var owner: NavigationOwner = NavigationOwner.new()
	add_child_autofree(owner)
	return owner


func _global_route() -> void:
	var config: CONFIG_SCRIPT = CONFIG_SCRIPT.new()
	var host: Node = Node.new()
	add_child_autofree(config)
	add_child_autofree(host)
	_global_route_used = true
	Nav.configure(_save, config, _content)
	Nav.configure_screens(func(_which: int) -> Node: return Node.new())
	Nav.configure_debug(true)
	assert_eq(Nav.start(host, "res://tests/fixtures/content"), OK)
	assert_eq(Nav.current_screen(), Nav.Screen.LEVEL)


func test_button_uses_current_injected_owner_once() -> void:
	var first: NavigationOwner = _owner()
	var second: NavigationOwner = _owner()
	var screen: LevelScreen = LEVEL_SCENE.instantiate() as LevelScreen
	screen.configure(_save, _content, 1)
	screen.configure_navigation(first)
	add_child_autofree(screen)
	screen.debug_button.pressed.emit()
	assert_eq(first.debug_calls, 1)
	assert_eq(second.debug_calls, 0)
	screen.configure_navigation(second)
	screen.debug_button.pressed.emit()
	assert_eq(first.debug_calls, 1)
	assert_eq(second.debug_calls, 1)


func test_destroyed_or_incapable_owner_does_not_reroute_globally() -> void:
	_global_route()
	var screen: LevelScreen = _screen()
	var owner: NavigationOwner = _owner()
	screen.configure_navigation(owner)
	owner.free()
	screen.debug_button.pressed.emit()
	assert_eq(Nav.current_screen(), Nav.Screen.LEVEL, "destroyed owner must not fall back")
	var incapable: Node = Node.new()
	add_child_autofree(incapable)
	screen.configure_navigation(incapable)
	screen.debug_button.pressed.emit()
	assert_eq(Nav.current_screen(), Nav.Screen.LEVEL, "missing route safely does nothing")
	var replacement: NavigationOwner = _owner()
	screen.configure_navigation(replacement)
	screen.debug_button.pressed.emit()
	assert_eq(replacement.debug_calls, 1)
	assert_eq(Nav.current_screen(), Nav.Screen.LEVEL)


func test_unconfigured_and_explicit_null_keep_global_fallback() -> void:
	_global_route()
	var screen: LevelScreen = _screen()
	screen.debug_button.pressed.emit()
	assert_eq(Nav.current_screen(), Nav.Screen.DEBUG)
	assert_eq(Nav.go_home(), OK)
	var owner: NavigationOwner = _owner()
	screen.configure_navigation(owner)
	screen.configure_navigation(null)
	screen.debug_button.pressed.emit()
	assert_eq(owner.debug_calls, 0)
	assert_eq(Nav.current_screen(), Nav.Screen.DEBUG)
