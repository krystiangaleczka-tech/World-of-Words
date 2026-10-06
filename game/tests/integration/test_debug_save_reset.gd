extends GutTest

const SAVE_SCRIPT = preload("res://services/save.gd")
const PATH: String = "user://t0056-debug-reset.json"
const ID: String = "12345678-1234-4234-8234-123456789abc"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1_790_000_000


class InterruptedStorage:
	extends SaveStorage
	var stop_at: StringName = &""

	func checkpoint(step: StringName) -> Error:
		return ERR_BUSY if step == stop_at else OK


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func _save(storage: SaveStorage = null) -> SAVE_SCRIPT:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(FixedClock.new())
	save.configure(
		storage if storage != null else SaveStorage.new(PATH), func() -> String: return ID
	)
	return save


func _seed(save: SAVE_SCRIPT) -> void:
	assert_eq(save.load(), OK)
	assert_eq(save.set_setting(&"haptics_enabled", false), OK)
	var progress: Dictionary = save.get_section(&"progress")
	progress["by_lang"]["pl"]["current_slot"] = 3
	progress["by_lang"]["pl"]["completed_slot"] = 2
	assert_eq(save.set_section(&"progress", progress), OK)
	var economy: Dictionary = save.get_section(&"economy")
	economy["coins"] = 42
	assert_eq(save.set_section(&"economy", economy), OK)
	var daily: Dictionary = save.get_section(&"daily")
	daily["streak"] = 3
	assert_eq(save.set_section(&"daily", daily), OK)
	var monetization: Dictionary = save.get_section(&"monetization")
	monetization["remove_forced_ads"] = true
	monetization["processed_transactions"] = ["preserved-purchase"]
	assert_eq(save.set_section(&"monetization", monetization), OK)
	assert_eq(save.flush(), OK)


func _assert_fresh_gameplay(save: SAVE_SCRIPT) -> void:
	for section: StringName in [&"progress", &"economy", &"daily"]:
		assert_eq_deep(save.get_section(section), SaveSchema.TEMPLATE[str(section)])


func test_reset_preserves_identity_settings_and_transactions() -> void:
	var save: SAVE_SCRIPT = _save()
	assert_false(save.is_loaded())
	_seed(save)
	assert_true(save.is_loaded())
	var preserved: Dictionary = {}
	for section: StringName in [&"meta", &"settings", &"monetization"]:
		preserved[section] = save.get_section(section)
	assert_eq(save.debug_reset(), OK)
	_assert_fresh_gameplay(save)
	for section: StringName in preserved:
		assert_eq_deep(save.get_section(section), preserved[section])
	assert_true(save.is_loaded())


func test_reset_is_durable_after_reload() -> void:
	var save: SAVE_SCRIPT = _save()
	_seed(save)
	assert_eq(save.debug_reset(), OK)
	var restored: SAVE_SCRIPT = _save()
	assert_eq(restored.load(), OK)
	_assert_fresh_gameplay(restored)
	assert_eq(restored.get_section(&"meta")["install_id"], ID)
	assert_false(restored.get_setting(&"haptics_enabled"))
	assert_eq(
		restored.get_section(&"monetization")["processed_transactions"], ["preserved-purchase"]
	)


func test_failed_reset_keeps_memory_and_can_retry() -> void:
	for checkpoint: StringName in [
		&"temp_written", &"temp_flushed", &"backup_rotated", &"primary_promoted"
	]:
		_clean()
		var storage: InterruptedStorage = InterruptedStorage.new(PATH)
		var save: SAVE_SCRIPT = _save(storage)
		_seed(save)
		var pending: Dictionary = save.get_section(&"economy")
		pending["coins"] = 55
		assert_eq(save.set_section(&"economy", pending), OK)
		var prior: Dictionary = {}
		for section: StringName in SaveSchema.SECTIONS:
			prior[section] = save.get_section(section)
		watch_signals(save)
		storage.stop_at = checkpoint
		assert_eq(save.debug_reset(), ERR_BUSY, str(checkpoint))
		assert_signal_emitted_with_parameters(save, "flush_failed", [ERR_BUSY])
		for section: StringName in prior:
			assert_eq_deep(save.get_section(section), prior[section])
		storage.stop_at = &""
		assert_eq(save.flush(), OK, "failed reset must retain the old pending dirty state")
		assert_eq(storage.read_document()["economy"]["coins"], 55)
		assert_eq(save.debug_reset(), OK)
		_assert_fresh_gameplay(save)
		var restored: SAVE_SCRIPT = _save()
		assert_eq(restored.load(), OK)
		_assert_fresh_gameplay(restored)


func test_reset_before_load_is_rejected() -> void:
	var save: SAVE_SCRIPT = _save()
	assert_eq(save.debug_reset(), ERR_UNCONFIGURED)
	assert_false(save.is_loaded())
	assert_false(FileAccess.file_exists(PATH))
