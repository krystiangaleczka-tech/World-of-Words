extends ServiceStub
## @api Screen state machine and boot sequence (ARCHITECTURE.md#boot-and-navigation).
## P1: boot goes straight to Level for the saved slot; Home exists empty, reachable from Debug.

## @api Emitted after a screen is entered and its scene (if any) is mounted.
signal screen_changed(screen: Screen)
## @api Boot stopped before the first screen; Nav stays on BOOT.
signal boot_failed(error: Error)

enum Screen { BOOT, LEVEL, HOME, JOURNEY, POSTCARD, SETTINGS, DAILY, COLLECTION, DEBUG }

const SAVE_SCRIPT = preload("res://services/save.gd")
const CONFIG_SCRIPT = preload("res://services/config.gd")
const CONTENT_SCRIPT = preload("res://services/content.gd")
## Screens without a scene file yet are entered as empty states (Level arrives in T-0116).
const SCENES: Dictionary = {
	Screen.LEVEL: "res://features/level/level.tscn",
	Screen.HOME: "res://features/home/home.tscn",
	Screen.DEBUG: "res://features/debug/debug.tscn",
}
const AUTOLOADS: PackedStringArray = [
	"Config",
	"Save",
	"Progress",
	"Economy",
	"Daily",
	"Content",
	"Monetization",
	"Analytics",
	"Audio",
	"Nav",
	"Events",
	"Platform",
]

var _screen: Screen = Screen.BOOT
var _level_slot: int = 0
var _host: Node = null
var _mounted: Node = null
var _save: SAVE_SCRIPT = null
var _config: CONFIG_SCRIPT = null
var _content: CONTENT_SCRIPT = null
var _debug_enabled: bool = true
var _screen_factory: Callable = Callable()


## @api Explicitly inject one Clock into the closed autoload list. No domain work.
func boot(clock: Clock) -> void:
	for service_name: String in AUTOLOADS:
		var service: ServiceStub = get_node("/root/" + service_name) as ServiceStub
		assert(service != null, "Missing autoload: " + service_name)
		service.initialize(clock)


## @api Replace the services start() uses (tests/tools only). Defaults are the autoloads.
func configure(save: SAVE_SCRIPT, config: CONFIG_SCRIPT, content: CONTENT_SCRIPT) -> void:
	_save = save
	_config = config
	_content = content


## @api Boot sequence: Save, Config, Content manifest, then Level for the saved slot.
## Screens mount under host. Any failure emits boot_failed and leaves Nav on BOOT.
func start(host: Node, content_root: String = "res://content") -> Error:
	_discard_mounted()
	_screen = Screen.BOOT
	_level_slot = 0
	_host = host
	if _save == null:
		configure(Save, Config, Content)
	var error: Error = _save.load()
	if error == OK:
		error = _config.load()
	var language: String = ""
	if error == OK:
		language = str(_save.get_setting(&"language"))
		error = _content.load_manifest(language, content_root)
	if error == OK:
		error = go_to_level(clampi(_saved_slot(language), 1, _content.slot_count()))
	if error != OK:
		boot_failed.emit(error)
	return error


## @api Current screen.
func current_screen() -> Screen:
	return _screen


## @api Slot of the Level screen; 0 before the first level.
func level_slot() -> int:
	return _level_slot


## @api Screen node mounted under the host, or null for screens without a scene yet.
func mounted_screen() -> Node:
	return _mounted if is_instance_valid(_mounted) else null


## @api Enter Level for a slot that Content can load.
func go_to_level(slot: int) -> Error:
	if _content == null or _content.level_for_slot(slot) == null:
		return ERR_INVALID_PARAMETER
	_level_slot = slot
	_enter(Screen.LEVEL)
	return OK


## @api Enter Home (empty in P1). Only after boot reached a screen.
func go_home() -> Error:
	if _screen == Screen.BOOT:
		return ERR_UNCONFIGURED
	_enter(Screen.HOME)
	return OK


## @api Tests/tools may disable debug routing; release gating cannot be bypassed.
func configure_debug(enabled: bool) -> void:
	_debug_enabled = enabled


## @api Tests/tools may inject a screen factory taking Screen and returning Node/null.
func configure_screens(factory: Callable) -> void:
	_screen_factory = factory


## @api Debug-only diagnostic route, including a boot stopped on missing content.
func go_debug() -> Error:
	if not OS.is_debug_build() or not _debug_enabled:
		return ERR_UNAVAILABLE
	if not is_instance_valid(_host) or _save == null or not _save.is_loaded():
		return ERR_UNCONFIGURED
	_enter(Screen.DEBUG)
	return OK


# Read-only view of the saved slot until Progress owns it (T-0111).
func _saved_slot(language: String) -> int:
	var progress: Dictionary = _save.get_section(&"progress")
	var by_language: Dictionary = progress.get("by_lang", {})
	var state: Dictionary = by_language.get(language, {})
	return int(state.get("current_slot", 1))


func _discard_mounted() -> void:
	if is_instance_valid(_mounted):
		var parent: Node = _mounted.get_parent()
		if parent != null:
			parent.remove_child(_mounted)
		_mounted.queue_free()
	_mounted = null


func _enter(screen: Screen) -> void:
	_discard_mounted()
	var path: String = SCENES.get(screen, "")
	if is_instance_valid(_host):
		if _screen_factory.is_valid():
			_mounted = _screen_factory.call(screen) as Node
		elif not path.is_empty() and ResourceLoader.exists(path):
			_mounted = (load(path) as PackedScene).instantiate()
		if _mounted != null:
			if screen == Screen.LEVEL and _mounted.has_method("configure"):
				_mounted.call("configure", _save, _content, _level_slot)
				if _mounted.has_method("configure_navigation"):
					_mounted.call("configure_navigation", self)
			elif screen == Screen.DEBUG and _mounted.has_method("configure"):
				_mounted.call("configure", _save, _content, self)
			_host.add_child(_mounted)
	_screen = screen
	screen_changed.emit(screen)
