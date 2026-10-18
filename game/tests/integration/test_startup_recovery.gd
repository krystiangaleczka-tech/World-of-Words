extends GutTest

const RECOVERY: Script = preload("res://services/nav/startup_recovery.gd")
const NAV: Script = preload("res://services/nav.gd")
const SAVE: Script = preload("res://services/save.gd")
const CONTENT: Script = preload("res://services/content.gd")
const ANALYTICS: Script = preload("res://services/analytics.gd")
const EVENTS: Script = preload("res://services/events.gd")
const ROOT: String = "user://t0295-content"
const MANIFEST: String = ROOT + "/pl/manifest.json"
const PACK: String = ROOT + "/pl/packs/c-0001-0003.json"
var nav: NAV
var save: SAVE
var content: CONTENT
var config: RecoveryConfig
var analytics: ANALYTICS
var events: EVENTS
var store: RecoveryStorage
var monetization: RestorePort
var recovery: RefCounted
var host: SubViewport
var locale: String
var adapter: AnalyticsAdapter
var motion: bool


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1799971200


class RecoveryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)
	var writes: int = 0
	var fail_at: int = -1
	var mode: StringName = &"valid"

	func read_document(suffix: String = "") -> Dictionary:
		if mode in [&"lost", &"fresh"] or (mode == &"backup" and suffix != ".bak"):
			return {}
		return document.duplicate(true)

	func has_any_file() -> bool:
		return mode != &"fresh"

	func commit(text: String, _rotate: bool) -> Error:
		writes += 1
		if writes == fail_at:
			return ERR_FILE_CANT_WRITE
		document = JSON.parse_string(text)
		mode = &"valid"
		return OK


class RecoveryConfig:
	extends "res://services/config.gd"
	var fail_load: bool = false

	func load(directory: String = "res://data/config") -> Error:
		return ERR_CANT_OPEN if fail_load else super.load(directory)

	func get_int(key: StringName) -> int:
		return 2 if key == &"unlocks.journey_slot" else super.get_int(key)


class RestorePort:
	extends "res://services/monetization.gd"
	var calls: int = 0
	var result: Error = ERR_UNCONFIGURED

	func restore_purchases() -> Error:
		calls += 1
		return result


class Queue:
	extends AnalyticsQueue
	var fail: bool = false
	var fail_on_replace: int = -1
	var replaces: int = 0
	var entries: Array[Dictionary] = []

	func restore(_capacity: int, _validator: Callable) -> Dictionary:
		return {"error": OK, "events": []}

	func replace(candidate: Array[Dictionary]) -> Error:
		replaces += 1
		if fail or replaces == fail_on_replace:
			return ERR_FILE_CANT_WRITE
		entries = candidate.duplicate(true)
		return OK


func before_each() -> void:
	adapter = Platform.analytics
	locale = TranslationServer.get_locale()
	motion = Tokens.reduced_motion
	TranslationServer.set_locale("pl")
	Tokens.reduced_motion = true
	_fixture()
	nav = NAV.new()
	save = SAVE.new()
	content = CONTENT.new()
	config = RecoveryConfig.new()
	analytics = ANALYTICS.new()
	events = EVENTS.new()
	monetization = RestorePort.new()
	for node: ServiceStub in [nav, save, content, config, analytics, events, monetization]:
		add_child_autofree(node)
		node.initialize(FixedClock.new())
	store = RecoveryStorage.new()
	save.configure(store, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	nav.configure(save, config, content)
	assert_eq(nav.configure_p2(func() -> Error: return OK, false), OK)
	host = SubViewport.new()
	host.size = Vector2i(1080, 1920)
	add_child_autofree(host)
	recovery = RECOVERY.new()
	recovery.configure(nav, save, config, content, monetization, analytics)


func after_each() -> void:
	Platform.analytics = adapter
	recovery.close()
	nav.free()
	await wait_process_frames(2)
	for path: String in [MANIFEST, PACK]:
		DirAccess.remove_absolute(path)
	TranslationServer.set_locale(locale)
	Tokens.reduced_motion = motion


func _fixture() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "/pl/packs")
	for relative: String in ["pl/manifest.json", "pl/packs/c-0001-0003.json"]:
		var source: PackedByteArray = FileAccess.get_file_as_bytes(
			"res://tests/fixtures/content/" + relative
		)
		var file: FileAccess = FileAccess.open(ROOT.path_join(relative), FileAccess.WRITE)
		file.store_buffer(source)
		file.close()


func _primary() -> void:
	(recovery.presentation().get_node("State") as StatePanel).action_requested.emit()


func _secondary() -> void:
	(recovery.presentation().get_node("Secondary") as TextButton).pressed.emit()


func test_missing_content_retry_and_stale_actions_are_safe() -> void:
	DirAccess.remove_absolute(MANIFEST)
	assert_ne(recovery.start(host, ROOT), OK)
	assert_eq(nav.boot_failure_stage, &"content")
	assert_eq(nav.go_home(), ERR_UNCONFIGURED)
	var old: Node = recovery.presentation()
	assert_eq((old.get_node("State") as StatePanel).kind, &"error")
	watch_signals(recovery)
	_fixture()
	_primary()
	assert_null(recovery.presentation())
	assert_eq(nav.current_screen(), NAV.Screen.LEVEL)
	var writes: int = store.writes
	old.primary_requested.emit()
	assert_eq(store.writes, writes)
	assert_signal_emit_count(recovery, "started", 1)
	assert_eq(nav.boot_failure_stage, &"")


func _home_retry(malformed: bool) -> void:
	if malformed:
		var file: FileAccess = FileAccess.open(PACK, FileAccess.WRITE)
		file.store_string("{}")
		file.close()
	else:
		DirAccess.remove_absolute(MANIFEST)
	assert_ne(recovery.start(host, ROOT), OK)
	assert_eq(nav.boot_failure_stage, &"content")
	_secondary()
	assert_eq(nav.current_screen(), NAV.Screen.HOME)
	assert_true((nav.mounted_screen().find_child("Play", true, false) as PrimaryButton).disabled)
	assert_false((recovery.presentation().get_node("Secondary") as TextButton).visible)
	_fixture()
	_primary()
	assert_null(recovery.presentation())
	assert_eq(nav.current_screen(), NAV.Screen.LEVEL)


func test_missing_manifest_home_keeps_working_inline_retry() -> void:
	_home_retry(false)


func test_malformed_pack_home_disables_play_and_retry_recovers() -> void:
	_home_retry(true)


func _toast() -> Toast:
	for node: Node in get_tree().get_nodes_in_group(Toast.GROUP):
		if node is Toast and node.get_parent() == nav.mounted_screen():
			return node
	return null


func test_real_backup_recovery_shows_toast_once_on_locked_home_level() -> void:
	store.mode = &"backup"
	assert_eq(recovery.start(host, ROOT), OK)
	assert_eq(nav.current_screen(), NAV.Screen.LEVEL)
	assert_not_null(_toast())
	assert_eq(_toast().text_key, "nav.toast.backup_restored")
	assert_true(_toast().visible)
	assert_null(recovery.presentation())
	_toast().hide_message()
	assert_eq(nav.enqueue_toast("nav.toast.purchases_restored"), OK)
	await wait_process_frames(2)
	assert_false(_toast().visible, "Ordinary messages still wait for Home")
	var progress: Dictionary = save.get_section(&"progress")
	progress.by_lang.pl.current_slot = 2
	progress.by_lang.pl.highest_completed_slot = 1
	assert_eq(save.set_section(&"progress", progress), OK)
	assert_eq(save.flush(), OK)
	assert_eq(nav.go_home(), OK)
	var toast: Toast = _toast()
	assert_eq(toast.text_key, "nav.toast.purchases_restored")


func test_lost_save_restore_requested_continue_and_reload_once() -> void:
	store.mode = &"lost"
	assert_eq(recovery.start(host, ROOT), OK)
	assert_not_null(recovery.presentation())
	assert_eq(
		(recovery.presentation().get_node("State") as StatePanel).action_key,
		"recovery.action.restore"
	)
	_primary()
	assert_eq(monetization.calls, 1)
	assert_eq(
		(recovery.presentation().get_node("Status") as Label).text,
		tr("recovery.status.restore_error")
	)
	monetization.result = OK
	_primary()
	assert_eq(monetization.calls, 2)
	assert_eq(
		(recovery.presentation().get_node("Status") as Label).text, tr("recovery.status.requested")
	)
	assert_eq((recovery.presentation().get_node("State") as StatePanel).action_key, "")
	_secondary()
	assert_null(recovery.presentation())
	var reloaded: SAVE = SAVE.new()
	add_child_autofree(reloaded)
	reloaded.initialize(FixedClock.new())
	reloaded.configure(store)
	assert_eq(reloaded.load(), OK)
	assert_false(reloaded.last_load_report().get("corrupted", false))
	recovery.close()
	nav.configure(reloaded, config, content)
	assert_eq(nav.configure_p2(func() -> Error: return OK, false), OK)
	recovery = RECOVERY.new()
	recovery.configure(nav, reloaded, config, content, monetization, analytics)
	assert_eq(recovery.start(host, ROOT), OK)
	assert_null(recovery.presentation())


func test_failed_continue_keeps_lost_panel_and_retry_succeeds() -> void:
	store.mode = &"lost"
	assert_eq(recovery.start(host, ROOT), OK)
	assert_eq(save.set_section(&"daily", save.get_section(&"daily")), OK)
	store.fail_at = store.writes + 1
	_secondary()
	assert_not_null(recovery.presentation())
	assert_eq(
		(recovery.presentation().get_node("Status") as Label).text, tr("recovery.status.save_error")
	)
	_secondary()
	assert_null(recovery.presentation())


func _runtime_queue() -> Queue:
	assert_eq(save.load(), OK)
	assert_eq(config.load(), OK)
	assert_eq(content.load_manifest("pl", ROOT), OK)
	var queue: Queue = Queue.new()
	assert_eq(analytics.start_runtime(save, config, content, events, queue), OK)
	return queue


func test_deferred_content_event_coalesces_and_survives_queue_failure() -> void:
	var queue: Queue = _runtime_queue()
	DirAccess.remove_absolute(MANIFEST)
	assert_ne(recovery.start(host, ROOT), OK)
	assert_ne(recovery.start(host, ROOT), OK)
	assert_true(queue.entries.is_empty())
	_fixture()
	queue.fail = true
	assert_eq(recovery.start(host, ROOT), OK)
	assert_true(queue.entries.is_empty())
	queue.fail = false
	assert_eq(recovery.start(host, ROOT), OK)
	assert_eq(queue.entries.size(), 1)
	assert_eq(queue.entries[0].name, "content_load_failed")
	assert_true(queue.entries[0].event_params.error_code is int)
	assert_eq(queue.entries[0].event_params.size(), 1)
	assert_eq(recovery.start(host, ROOT), OK)
	assert_eq(queue.entries.size(), 1)


func test_noncontent_failure_does_not_emit_content_event_and_normal_start_has_no_panel() -> void:
	var queue: Queue = _runtime_queue()
	config.fail_load = true
	assert_ne(recovery.start(host, ROOT), OK)
	assert_eq(nav.boot_failure_stage, &"config")
	assert_ne(nav.go_home(true), OK)
	config.fail_load = false
	assert_eq(recovery.start(host, ROOT), OK)
	assert_null(recovery.presentation())
	assert_true(queue.entries.is_empty())


func test_lost_modal_traps_focus_and_locale_preserves_error_status() -> void:
	store.mode = &"lost"
	assert_eq(recovery.start(host, ROOT), OK)
	var box: Control = recovery.presentation()
	var sheet: Sheet
	for node: Node in get_tree().get_nodes_in_group(Sheet.GROUP):
		if node.get_viewport() == host:
			sheet = node
	assert_not_null(sheet)
	assert_false(sheet.dismissible)
	assert_true(sheet.handle_back())
	assert_true(box.is_ancestor_of(host.gui_get_focus_owner()))
	_primary()
	TranslationServer.set_locale("en")
	await wait_process_frames(2)
	assert_eq(
		(box.get_node("Status") as Label).text, "Could not request purchase restore. Try again."
	)
	var underlying: Control = (nav.mounted_screen() as LevelScreen).hint_button
	underlying.grab_focus()
	assert_true(box.is_ancestor_of(host.gui_get_focus_owner()))


func test_first_install_creates_save_without_lost_explanation() -> void:
	store.mode = &"fresh"
	assert_eq(recovery.start(host, ROOT), OK)
	assert_null(recovery.presentation())
	assert_false(save.last_load_report().get("corrupted", false))


func test_host_teardown_closes_caller_owned_modal_content_without_orphans() -> void:
	store.mode = &"lost"
	assert_eq(recovery.start(host, ROOT), OK)
	var box: Control = recovery.presentation()
	host.free()
	recovery.close()
	await wait_process_frames(2)
	assert_false(is_instance_valid(box))
	assert_null(recovery.presentation())


func test_enqueue_receipt_prevents_duplicate_after_delivery_removal_failure() -> void:
	Platform.analytics = AnalyticsFake.new()
	var queue: Queue = _runtime_queue()
	events.consent_changed.emit(true)
	DirAccess.remove_absolute(MANIFEST)
	assert_ne(recovery.start(host, ROOT), OK)
	_fixture()
	queue.fail_on_replace = 2
	assert_eq(recovery.start(host, ROOT), OK)
	assert_eq(queue.entries.size(), 1)
	assert_eq(analytics.pending_count(), 1)
	queue.fail_on_replace = -1
	assert_eq(recovery.start(host, ROOT), OK)
	assert_eq(queue.entries.size(), 1, "Accepted report must not be enqueued twice")
