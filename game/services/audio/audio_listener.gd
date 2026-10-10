extends Node
## Audio is a side-effect subscriber; it never decides gameplay or persistence.

const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const AUDIO_SCRIPT: Script = preload("res://services/audio.gd")

var _events: EVENTS_SCRIPT
var _audio: AUDIO_SCRIPT


func configure(events: EVENTS_SCRIPT, audio: AUDIO_SCRIPT) -> void:
	_disconnect_events()
	_events = events
	_audio = audio
	_connect_events()


func _enter_tree() -> void:
	_connect_events()


func _exit_tree() -> void:
	_disconnect_events()


func _connect_events() -> void:
	if not is_inside_tree() or not is_instance_valid(_events):
		return
	if _events.tile_touched.is_connected(_on_tile):
		return
	_events.tile_touched.connect(_on_tile)
	_events.word_found.connect(_on_word)
	_events.bonus_found.connect(_on_bonus)
	_events.already_found.connect(_on_already)
	_events.invalid_word.connect(_on_invalid)
	_events.level_completed.connect(_on_complete)


func _disconnect_events() -> void:
	if not is_instance_valid(_events) or not _events.tile_touched.is_connected(_on_tile):
		return
	_events.tile_touched.disconnect(_on_tile)
	_events.word_found.disconnect(_on_word)
	_events.bonus_found.disconnect(_on_bonus)
	_events.already_found.disconnect(_on_already)
	_events.invalid_word.disconnect(_on_invalid)
	_events.level_completed.disconnect(_on_complete)


func _on_tile(_index: int) -> void:
	if is_instance_valid(_audio):
		_audio.play(&"tile_touch")


func _on_word(_word: String) -> void:
	if is_instance_valid(_audio):
		_audio.play(&"word_valid")


func _on_bonus(_word: String) -> void:
	if is_instance_valid(_audio):
		_audio.play(&"word_bonus")


func _on_already(_word: String) -> void:
	if is_instance_valid(_audio):
		_audio.play(&"word_already")


func _on_invalid(_word: String) -> void:
	if is_instance_valid(_audio):
		_audio.play(&"word_invalid")


func _on_complete(_slot: int) -> void:
	if is_instance_valid(_audio):
		_audio.play(&"level_complete")
