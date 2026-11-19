class_name OfflineCampaign
extends RefCounted
## Composes the campaign with the same persistent owners for the whole launch.

const SAVE: Script = preload("res://services/save.gd")
const CONFIG: Script = preload("res://services/config.gd")
const CONTENT: Script = preload("res://services/content.gd")
const PROGRESS: Script = preload("res://services/progress.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const EVENTS: Script = preload("res://services/events.gd")

var _save: SAVE
var _config: CONFIG
var _content: CONTENT
var _progress: PROGRESS
var _economy: ECONOMY
var _events: EVENTS
var _port: AtomicProgressPort


func _init(
	save: SAVE,
	config: CONFIG,
	content: CONTENT,
	progress: PROGRESS,
	economy: ECONOMY,
	events: EVENTS
) -> void:
	_save = save
	_config = config
	_content = content
	_progress = progress
	_economy = economy
	_events = events


func matches(save: SAVE, config: CONFIG, content: CONTENT) -> bool:
	return _save == save and _config == config and _content == content


func bind_before_load() -> Error:
	if _port != null:
		return OK
	_progress.configure(_save, _content)
	_economy.configure(_save, _config, _events)
	var port: AtomicProgressPort = AtomicProgressPort.new()
	var error: Error = port.configure(_save, _progress, _economy)
	if error == OK:
		_port = port
	return error


func activate() -> Error:
	if _save.migration_state() == "needs_migration":
		return OK
	var error: Error = _progress.configure_atomic(_config)
	if error == OK:
		error = _progress.configure_p2(_config, _port, _events)
		if error == ERR_UNAVAILABLE and _progress.p2_state() == "needs_migration":
			return OK
	return error


func prepare_level(level: LevelScreen, slot: int, clock: Clock) -> Error:
	if not _progress.p2_ready() or _progress.current_slot() != slot:
		return OK
	var error: Error = level.configure_p2(_economy, _config)
	if error == OK:
		error = level.configure_offer_clock(clock)
	if error == OK:
		error = level.configure_paid_tools(_progress, _port)
	if error == OK:
		error = level.configure_bonus_meter()
	if error == OK:
		error = level.configure_completion()
	if error == OK and slot == 1:
		error = level.configure_tutorial()
	if error == OK:
		error = level.configure_coaches(_modal_blocks.bind(level))
	return error


func finish_level_mount(screen: Node, can_open_settings: bool) -> void:
	var level: LevelScreen = screen as LevelScreen
	if level != null and level.p2_hud != null:
		level.p2_hud.settings.disabled = not can_open_settings


func prepare_home(home: Node) -> void:
	if _progress.p2_ready() and home.has_method("configure_coaches"):
		home.call("configure_coaches", _events, _modal_blocks.bind(home))


func is_live_level(screen: Node) -> bool:
	var level: LevelScreen = screen as LevelScreen
	return level != null and level.p2_hud != null


func _modal_blocks(screen: Node) -> bool:
	if not is_instance_valid(screen) or not screen.is_inside_tree():
		return true
	for node: Node in screen.get_tree().get_nodes_in_group(Sheet.GROUP):
		var sheet: Sheet = node as Sheet
		if sheet != null and sheet.get_viewport() == screen.get_viewport():
			if sheet.state != &"closed":
				return true
	return false
