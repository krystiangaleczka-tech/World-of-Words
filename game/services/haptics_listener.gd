class_name HapticsListener
extends Node
## Relays side-effect events to the current platform adapter while respecting the live Save setting.

const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const PLATFORM_SCRIPT: Script = preload("res://platform/platform.gd")

var _events: EVENTS_SCRIPT
var _save: SAVE_SCRIPT
var _platform: PLATFORM_SCRIPT


## @api Supply services before mounting, or replace them safely in tests.
func configure(events: EVENTS_SCRIPT, save: SAVE_SCRIPT, platform: PLATFORM_SCRIPT) -> void:
	_disconnect_events()
	_events = events
	_save = save
	_platform = platform
	_connect_events()


func _enter_tree() -> void:
	_connect_events()


func _exit_tree() -> void:
	_disconnect_events()


func _connect_events() -> void:
	if _events == null or not is_inside_tree():
		return
	if not _events.tile_touched.is_connected(_on_tile_touched):
		_events.tile_touched.connect(_on_tile_touched)
		_events.word_found.connect(_on_word_found)
		_events.bonus_found.connect(_on_bonus_found)
		_events.already_found.connect(_on_already_found)
		_events.invalid_word.connect(_on_invalid_word)
		_events.level_completed.connect(_on_level_completed)
		_events.hint_used.connect(_on_hint_used)


func _disconnect_events() -> void:
	if _events == null:
		return
	if _events.tile_touched.is_connected(_on_tile_touched):
		_events.tile_touched.disconnect(_on_tile_touched)
		_events.word_found.disconnect(_on_word_found)
		_events.bonus_found.disconnect(_on_bonus_found)
		_events.already_found.disconnect(_on_already_found)
		_events.invalid_word.disconnect(_on_invalid_word)
		_events.level_completed.disconnect(_on_level_completed)
		_events.hint_used.disconnect(_on_hint_used)


func _play(pattern: String) -> void:
	if _save == null or _platform == null or not _save.is_loaded():
		return
	if _save.get_setting(&"haptics_enabled") == true and _platform.haptics != null:
		_platform.haptics.play(pattern)


func _on_tile_touched(_index: int) -> void:
	_play("tick")


func _on_word_found(_word: String) -> void:
	_play("success")


func _on_bonus_found(_word: String) -> void:
	_play("success")


func _on_already_found(_word: String) -> void:
	_play("soft")


func _on_invalid_word(_word: String) -> void:
	_play("error")


func _on_level_completed(_slot: int) -> void:
	_play("success")


func _on_hint_used() -> void:
	_play("soft")
