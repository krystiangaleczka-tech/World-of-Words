extends ServiceStub
## @api Screen state machine and boot sequence (ARCHITECTURE.md#boot-and-navigation).
## P1: boot goes straight to Level for the saved slot; Home exists empty, reachable from Debug.

## @api Emitted after a screen is entered and its scene (if any) is mounted.
signal screen_changed(screen: Screen)
## @api Boot stopped before the first screen; Nav stays on BOOT.
signal boot_failed(error: Error)
signal transition_finished

enum Screen { BOOT, LEVEL, HOME, JOURNEY, POSTCARD, SETTINGS, DAILY, COLLECTION, DEBUG }

const SAVE_SCRIPT = preload("res://services/save.gd")
const CONFIG_SCRIPT = preload("res://services/config.gd")
const CONTENT_SCRIPT = preload("res://services/content.gd")
## Screens without a scene file yet are entered as empty states (Level arrives in T-0116).
const SCENES: Dictionary = {
	Screen.LEVEL: "res://features/level/level.tscn",
	Screen.HOME: "res://features/home/home.tscn",
	Screen.JOURNEY: "res://features/journey/journey.tscn",
	Screen.POSTCARD: "res://features/journey/postcard.tscn",
	Screen.DEBUG: "res://features/debug/debug.tscn",
}
const BACK_GROUP: StringName = &"nav_back_owner"
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
# Load after asset import: UI dependencies include generated CSV translations.
var _p2: RefCounted


## @api Explicitly inject one Clock into the closed autoload list. No domain work.
func boot(clock: Clock) -> void:
	for service_name: String in AUTOLOADS:
		var service: ServiceStub = get_node("/root/" + service_name) as ServiceStub
		assert(service != null, "Missing autoload: " + service_name)
		service.initialize(clock)


## @api Replace the services start() uses (tests/tools only). Defaults are the autoloads.
func configure(save: SAVE_SCRIPT, config: CONFIG_SCRIPT, content: CONTENT_SCRIPT) -> void:
	if _p2 != null and _p2.busy:
		return
	if _save != null and (_save != save or _config != config or _content != content):
		if _p2 != null:
			_p2.close()
			_p2 = null
		remove_from_group(BACK_GROUP)
		_discard_mounted()
		_screen = Screen.BOOT
		_level_slot = 0
	if is_instance_valid(_save) and _save.backup_restored.is_connected(_on_backup_restored):
		_save.backup_restored.disconnect(_on_backup_restored)
	_save = save
	if _p2 != null and not _save.backup_restored.is_connected(_on_backup_restored):
		_save.backup_restored.connect(_on_backup_restored)
	_config = config
	_content = content


## @api Boot sequence: Save, Config, Content manifest, then Level for the saved slot.
## Screens mount under host. Any failure emits boot_failed and leaves Nav on BOOT.
func start(host: Node, content_root: String = "res://content") -> Error:
	if _p2 != null:
		if not is_instance_valid(host) or not host.is_inside_tree():
			return ERR_UNCONFIGURED
		if _p2.busy:
			return ERR_BUSY
		_p2.reset()
		add_to_group(BACK_GROUP)
	OS.low_processor_usage_mode = true
	_discard_mounted()
	_screen = Screen.BOOT
	_level_slot = 0
	if is_instance_valid(_host) and _host.tree_exiting.is_connected(_on_host_exit):
		_host.tree_exiting.disconnect(_on_host_exit)
	_host = host
	if _p2 != null and is_instance_valid(_host):
		_host.tree_exiting.connect(_on_host_exit)
	if _save == null:
		configure(Save, Config, Content)
	if _p2 != null:
		_p2.busy = true
	var error: Error = _save.load()
	if error == OK:
		error = _config.load()
	var language: String = ""
	if error == OK:
		language = str(_save.get_setting(&"language"))
		error = _content.load_manifest(language, content_root)
	if error == OK:
		# Analytics is nonessential: a damaged telemetry queue must not block offline gameplay.
		Analytics.start_runtime(_save, _config, _content)
		# Remote config is optional: cache first, HTTPS fetching only with a configured endpoint.
		_config.start_remote(str(_save.get_section(&"meta").get("install_id", "")), Analytics)
	if _p2 != null:
		_p2.busy = false
	if error == OK:
		var slot: int = clampi(_saved_slot(language), 1, _content.slot_count())
		if _content.level_for_slot(slot) == null:
			error = ERR_INVALID_PARAMETER
		else:
			TranslationServer.set_locale(language)
			if _p2 != null and home_unlocked():
				error = _p2.route(Screen.HOME, slot)
			else:
				error = go_to_level(slot)
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
	if not _valid_level(slot):
		return ERR_INVALID_PARAMETER
	if _p2 != null:
		return _p2.route(Screen.LEVEL, slot)
	_level_slot = slot
	_enter(Screen.LEVEL)
	return OK


## @api Enter Home (empty in P1). Only after boot reached a screen.
func go_home() -> Error:
	if _screen == Screen.BOOT:
		return ERR_UNCONFIGURED
	if _p2 != null:
		return ERR_UNAVAILABLE if not home_unlocked() else _p2.route(Screen.HOME, _level_slot)
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
	if _p2 != null:
		return _p2.route(Screen.DEBUG, _level_slot)
	_enter(Screen.DEBUG)
	return OK


# Read-only view of the saved slot until Progress owns it (T-0111).
func _saved_slot(language: String) -> int:
	var progress: Dictionary = (
		_save.committed_view().sections.progress if _p2 != null else _save.get_section(&"progress")
	)
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


func _enter(screen: Screen, reveal_latest: bool = false) -> void:
	OS.low_processor_usage_mode = screen != Screen.LEVEL
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
			elif screen == Screen.POSTCARD and _mounted.has_method("configure"):
				_mounted.call(
					"configure", _save, _content, _config, self, _level_slot, reveal_latest
				)
			elif screen in [Screen.HOME, Screen.JOURNEY] and _mounted.has_method("configure"):
				_mounted.call("configure", _save, _content, _config, self)
			elif screen == Screen.DEBUG and _mounted.has_method("configure"):
				_mounted.call("configure", _save, _content, self)
			_host.add_child(_mounted)
	_screen = screen
	screen_changed.emit(screen)


## @api Navigation mode only; does not configure atomic gameplay owners.
func configure_p2(background: Callable = Callable(), animate: bool = true) -> Error:
	if _p2 != null:
		return OK
	if _screen != Screen.BOOT:
		return ERR_ALREADY_IN_USE
	var navigation_script: Script = load("res://services/nav/p2_navigation.gd") as Script
	_p2 = navigation_script.new() as RefCounted
	_p2.configure(self, background, animate)
	if is_instance_valid(_save):
		_save.backup_restored.connect(_on_backup_restored)
	return OK


func home_unlocked() -> bool:
	return (
		is_instance_valid(_save)
		and _save.is_loaded()
		and is_instance_valid(_config)
		and _config.has_key(&"unlocks.journey_slot")
		and (
			_saved_slot(str(_save.get_setting(&"language")))
			>= _config.get_int(&"unlocks.journey_slot")
		)
	)


func go_to_screen(screen: Screen) -> Error:
	if _p2 == null or _screen == Screen.BOOT:
		return ERR_UNCONFIGURED
	if screen in [Screen.BOOT, Screen.LEVEL, Screen.DEBUG] or not Screen.values().has(screen):
		return ERR_INVALID_PARAMETER
	if screen == Screen.HOME:
		return go_home()
	if screen == Screen.POSTCARD:
		return go_to_postcard(_resume_slot())
	return _p2.route(screen, _level_slot)


func handle_back() -> Error:
	return _p2.back() if _p2 != null else ERR_UNAVAILABLE


func enqueue_toast(key: String, variant: StringName = &"info") -> Error:
	return _p2.enqueue(key, variant) if _p2 != null else ERR_UNAVAILABLE


func _on_backup_restored() -> void:
	enqueue_toast("nav.toast.backup_restored")


func _resume_slot() -> int:
	return clampi(_saved_slot(str(_save.get_setting(&"language"))), 1, _content.slot_count())


func _prepare_leave() -> Error:
	if _screen == Screen.BOOT:
		return OK
	if not is_instance_valid(_save) or not _save.is_loaded():
		return OK if _screen == Screen.BOOT else ERR_UNCONFIGURED
	if _save.writes_blocked():
		return ERR_BUSY
	if _screen == Screen.LEVEL and is_instance_valid(_mounted):
		if _mounted.has_method("prepare_navigation"):
			var error: Error = _mounted.call("prepare_navigation")
			if error != OK:
				return error
	return _save.flush()


func _mount_p2(screen: Screen, slot: int, reveal_latest: bool = false) -> void:
	_level_slot = slot
	_enter(screen, reveal_latest)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _p2 != null and is_in_group(BACK_GROUP):
		handle_back()


func _unhandled_input(event: InputEvent) -> void:
	if (
		_p2 != null
		and is_in_group(BACK_GROUP)
		and event.is_action_pressed(&"ui_cancel")
		and not event.is_echo()
	):
		handle_back()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _p2 != null:
		_p2.close()
	_discard_mounted()
	if is_instance_valid(_host) and _host.tree_exiting.is_connected(_on_host_exit):
		_host.tree_exiting.disconnect(_on_host_exit)
	if is_instance_valid(_save) and _save.backup_restored.is_connected(_on_backup_restored):
		_save.backup_restored.disconnect(_on_backup_restored)


func _on_host_exit() -> void:
	remove_from_group(BACK_GROUP)
	if _p2 != null:
		_p2.reset()


func _valid_level(slot: int) -> bool:
	return is_instance_valid(_content) and _content.level_for_slot(slot) != null


## @api Location selection is a route slot, never a change to campaign progress.
func go_to_postcard(slot: int, reveal_latest: bool = false) -> Error:
	if _p2 == null or _screen == Screen.BOOT:
		return ERR_UNCONFIGURED
	return _p2.route(Screen.POSTCARD, slot, true, reveal_latest)


## @api Committed location credits, including before Home unlock; no grants or live writes.
func postcard_piece_count(slot: int) -> int:
	if _p2 == null:
		return 0
	var context: Dictionary = _postcard_context(slot)
	if context.is_empty():
		return 0
	return clampi(
		int(context.progress.get("location_pieces", {}).get(context.location.id, 0)),
		0,
		maxi(_config.get_int(&"meta.postcard.pieces"), 0)
	)


## @api Continue after a durably completed board; new credits may present its postcard first.
func continue_campaign(completed_slot: int, previous_pieces: int) -> Error:
	if _p2 == null:
		return go_to_level(completed_slot + 1)
	if _p2.busy:
		return ERR_BUSY
	if _screen != Screen.LEVEL or _level_slot != completed_slot or previous_pieces < 0:
		return ERR_INVALID_PARAMETER
	_p2.busy = true
	var context: Dictionary = _postcard_context(completed_slot)
	if context.is_empty() or int(context.progress.current_slot) <= completed_slot:
		_p2.busy = false
		return ERR_UNAVAILABLE
	var show_postcard: bool = (
		home_unlocked()
		and previous_pieces < _config.get_int(&"meta.postcard.pieces")
		and postcard_piece_count(completed_slot) > previous_pieces
	)
	_p2.busy = false
	return (
		go_to_postcard(completed_slot, true)
		if show_postcard
		else go_to_level(int(context.progress.current_slot))
	)


func _postcard_context(slot: int) -> Dictionary:
	if (
		not is_instance_valid(_save)
		or not _save.is_loaded()
		or not is_instance_valid(_content)
		or not _content.is_loaded()
		or not is_instance_valid(_config)
		or not _config.has_key(&"meta.postcard.pieces")
	):
		return {}
	var view: Dictionary = _save.committed_view()
	if view.error != OK or view.sections.settings.language != _content.get_language():
		return {}
	var location: Dictionary = _content.location_for_slot(slot)
	if location.is_empty():
		return {}
	var state: Dictionary = view.sections.progress.by_lang.get(
		str(view.sections.settings.language), SaveSchema.LANGUAGE_STATE
	)
	return {"location": location, "progress": state}
