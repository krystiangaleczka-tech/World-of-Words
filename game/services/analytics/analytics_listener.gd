class_name AnalyticsListener
extends Node
## Side-effect observer only. All delivery, consent and durable queue state belong to Analytics.

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const SCREEN_NAMES: PackedStringArray = [
	"BOOT", "LEVEL", "HOME", "JOURNEY", "POSTCARD", "SETTINGS", "DAILY", "COLLECTION", "DEBUG"
]

var _analytics: Node
var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _navigation: Node
var _events: EVENTS_SCRIPT
var _clock: Clock
var _configured: bool = false
var _background: bool = false
var _slot: int = 0
var _level_id: String = ""
var _start_msec: int = 0
var _completed: bool = false
var _hints: int = 0
var _bonus_count: int = 0
var _stars: int = 0
var _bonuses: Dictionary = {}


func configure(
	analytics: Node,
	save: SAVE_SCRIPT,
	content: CONTENT_SCRIPT,
	navigation: Node,
	events: EVENTS_SCRIPT,
	clock: Clock
) -> Error:
	if (
		not is_instance_valid(analytics)
		or not is_instance_valid(save)
		or not is_instance_valid(content)
		or not is_instance_valid(navigation)
		or not is_instance_valid(events)
		or clock == null
	):
		return ERR_UNCONFIGURED
	if (
		_configured
		and _analytics == analytics
		and _save == save
		and _content == content
		and _navigation == navigation
		and _events == events
		and _clock == clock
	):
		return OK
	_disconnect()
	_analytics = analytics
	_save = save
	_content = content
	_navigation = navigation
	_events = events
	_clock = clock
	_reset_level()
	_navigation.connect("screen_changed", _on_screen_changed)
	_save.setting_changed.connect(_on_setting_changed)
	_events.word_found.connect(_on_word_found)
	_events.bonus_found.connect(_on_bonus_found)
	_events.already_found.connect(_on_already_found)
	_events.invalid_word.connect(_on_invalid_word)
	_events.level_completed.connect(_on_level_completed)
	_events.hint_used.connect(_on_hint_used)
	_events.shuffle_performed.connect(_on_shuffle)
	_events.economy_changed.connect(_on_economy_changed)
	_events.stars_earned.connect(_on_stars_earned)
	_events.postcard_piece_revealed.connect(_on_postcard_piece_revealed)
	_events.location_complete.connect(_on_location_complete)
	_events.feature_unlocked.connect(_on_feature_unlocked)
	_configured = true
	_track(&"app_boot")
	_track(&"content_version_loaded", {"content_version": _content.content_version()})
	var report: Dictionary = _save.last_load_report()
	if report.get("corrupted", false):
		_track(&"save_corrupted", {"schema_version": 0})
	elif int(report.get("from_version", 0)) > 0 and int(report.get("to_version", 0)) > 0:
		_track(
			&"save_migrated",
			{"from_version": int(report["from_version"]), "to_version": int(report["to_version"])}
		)
	return OK


func _track(event_name: StringName, values: Dictionary = {}) -> void:
	if _configured and is_instance_valid(_analytics):
		# Telemetry can fail (full/offline/denied); business operations must still succeed.
		_analytics.call("track", event_name, values)


func _on_screen_changed(screen: int) -> void:
	_reset_level()
	if screen < 0 or screen >= SCREEN_NAMES.size():
		return
	_track(&"nav_screen", {"screen": SCREEN_NAMES[screen]})
	if screen != 1:
		return
	var slot: int = int(_navigation.call("level_slot"))
	var level: LevelData = _content.level_for_slot(slot)
	if level == null or level.get_slot() != slot:
		return
	_slot = slot
	_level_id = level.get_id()
	_start_msec = _clock.monotonic_msec()
	_track(&"level_start", {"slot": _slot, "level_id": _level_id})


func _active() -> bool:
	return _slot > 0 and not _level_id.is_empty() and int(_navigation.call("current_screen")) == 1


func _on_word_found(word: String) -> void:
	if _active() and not _completed:
		_track(&"word_found", {"slot": _slot, "level_id": _level_id, "word": word})


func _on_bonus_found(word: String) -> void:
	if _active() and not _completed and not _bonuses.has(word):
		_bonuses[word] = true
		_bonus_count += 1
		_track(&"bonus_word_found", {"slot": _slot, "level_id": _level_id, "word": word})


func _on_already_found(word: String) -> void:
	if not _active() or _completed:
		return
	var level: LevelData = _content.level_for_slot(_slot)
	if level == null or level.get_id() != _level_id:
		return
	var kind: String = "bonus" if word in level.bonus_words() else "level"
	_track(
		&"already_found_word",
		{"slot": _slot, "level_id": _level_id, "word": word, "kind": kind}
	)


func _on_invalid_word(word: String) -> void:
	if _active() and not _completed:
		_track(
			&"invalid_word_submitted",
			{"language": _content.get_language(), "slot": _slot, "letters": word}
		)


func _on_hint_used() -> void:
	if _active() and not _completed:
		_hints += 1
		# P1 hints are free. Do not fabricate payment=item/coins/rewarded.


func _on_shuffle(slot: int) -> void:
	if _active() and not _completed and slot == _slot:
		_track(&"shuffle_used", {"slot": slot})


func _on_level_completed(slot: int) -> void:
	if not _active() or _completed or slot != _slot:
		return
	_completed = true
	_track(
		&"level_complete",
		{
			"slot": _slot,
			"level_id": _level_id,
			"duration_ms": maxi(0, _clock.monotonic_msec() - _start_msec),
			"hints_used": _hints,
			"reveals_used": 0,
			"bonus_words": _bonus_count,
			"stars": _stars,
		}
	)


func _on_economy_changed(
	operation: StringName, reason: StringName, amounts: Dictionary, _snapshot: Dictionary
) -> void:
	if operation not in [&"grant", &"spend"] or not WalletSnapshot.valid_amounts(amounts):
		return
	_track(
		&"economy_grant" if operation == &"grant" else &"economy_spend",
		{
			"reason": str(reason),
			"coins": int(amounts.get("coins", 0)),
			"hint": int(amounts.get("hint", 0)),
			"reveal": int(amounts.get("reveal", 0))
		}
	)


func _same_language(language: String) -> bool:
	return _configured and language == _content.get_language()


func _on_stars_earned(language: String, slot: int, stars: int) -> void:
	if not _same_language(language) or stars < 0:
		return
	if _active() and not _completed and slot == _slot:
		_stars += stars
	_track(&"stars_earned", {"slot": slot, "stars": stars})


func _on_postcard_piece_revealed(language: String, location_id: String, pieces: int) -> void:
	if _same_language(language):
		_track(&"postcard_piece_revealed", {"location_id": location_id, "pieces": pieces})


func _on_location_complete(language: String, location_id: String) -> void:
	if _same_language(language):
		_track(&"location_complete", {"location_id": location_id})


func _on_feature_unlocked(language: String, feature: StringName, slot: int) -> void:
	if _same_language(language):
		_track(&"feature_unlocked", {"feature": str(feature), "slot": slot})


func _on_setting_changed(setting: StringName) -> void:
	_track(&"settings_changed", {"setting": str(setting)})


func _notification(what: int) -> void:
	if not _configured:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED and not _background:
		_background = true
		_track(&"app_background")
	elif what == NOTIFICATION_APPLICATION_RESUMED and _background:
		_background = false
		_track(&"app_foreground")


func _reset_level() -> void:
	_slot = 0
	_level_id = ""
	_start_msec = 0
	_completed = false
	_hints = 0
	_bonus_count = 0
	_stars = 0
	_bonuses.clear()


func _disconnect() -> void:
	if not _configured:
		return
	if is_instance_valid(_navigation) and _navigation.is_connected(
		"screen_changed", _on_screen_changed
	):
		_navigation.disconnect("screen_changed", _on_screen_changed)
	if is_instance_valid(_save) and _save.setting_changed.is_connected(_on_setting_changed):
		_save.setting_changed.disconnect(_on_setting_changed)
	if is_instance_valid(_events):
		_disconnect_signal(_events.word_found, _on_word_found)
		_disconnect_signal(_events.bonus_found, _on_bonus_found)
		_disconnect_signal(_events.already_found, _on_already_found)
		_disconnect_signal(_events.invalid_word, _on_invalid_word)
		_disconnect_signal(_events.level_completed, _on_level_completed)
		_disconnect_signal(_events.hint_used, _on_hint_used)
		_disconnect_signal(_events.shuffle_performed, _on_shuffle)
		_disconnect_signal(_events.economy_changed, _on_economy_changed)
		_disconnect_signal(_events.stars_earned, _on_stars_earned)
		_disconnect_signal(_events.postcard_piece_revealed, _on_postcard_piece_revealed)
		_disconnect_signal(_events.location_complete, _on_location_complete)
		_disconnect_signal(_events.feature_unlocked, _on_feature_unlocked)
	_configured = false


func _disconnect_signal(source: Signal, callback: Callable) -> void:
	if source.is_connected(callback):
		source.disconnect(callback)


func _exit_tree() -> void:
	_disconnect()
