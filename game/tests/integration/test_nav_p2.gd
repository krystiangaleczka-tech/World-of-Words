# gdlint: disable=max-public-methods
# Public GUT cases cover the complete navigation/lifecycle matrix in one isolated suite.
extends GutTest

const NAV: Script = preload("res://services/nav.gd")
const SAVE: Script = preload("res://services/save.gd")
const CONFIG: Script = preload("res://services/config.gd")
const CONTENT: Script = preload("res://services/content.gd")
const PATH: String = "user://t0243-nav-save.json"
const FIXTURE: String = "res://tests/fixtures/content"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class ConfigOverride:
	extends "res://services/config.gd"
	var threshold: int = 2

	func get_int(key: StringName) -> int:
		return threshold if key == &"unlocks.journey_slot" else super.get_int(key)


class LimitedContent:
	extends "res://services/content.gd"
	var available_slot: int = 3

	func level_for_slot(slot: int) -> LevelData:
		return null if slot > available_slot else super.level_for_slot(slot)


class BootConfig:
	extends "res://services/config.gd"
	var fail: bool = true
	var during_load: Callable

	func load(directory: String = "res://data/config") -> Error:
		var error: Error = super.load(directory)
		if during_load.is_valid():
			during_load.call()
		return ERR_CANT_OPEN if fail else error


class FailureStorage:
	extends SaveStorage
	var fail: bool = false

	func checkpoint(_step: StringName) -> Error:
		return ERR_BUSY if fail else OK


class PersistScreen:
	extends Control
	var result: Error = OK
	var calls: int = 0

	func prepare_navigation() -> Error:
		calls += 1
		return result


var _b: Dictionary
var _old_reduction: bool
var _old_low_mode: bool


func before_each() -> void:
	_clean()
	_old_reduction = Tokens.reduced_motion
	_old_low_mode = OS.low_processor_usage_mode
	Tokens.reduced_motion = true
	_b = _bundle()


func after_each() -> void:
	Tokens.reduced_motion = _old_reduction
	OS.low_processor_usage_mode = _old_low_mode
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func _bundle(
	animated: bool = false, content_override: CONTENT = null, config_override: CONFIG = null
) -> Dictionary:
	var save: SAVE = SAVE.new()
	var config: CONFIG = config_override if config_override != null else ConfigOverride.new()
	var content: CONTENT = content_override if content_override != null else CONTENT.new()
	var nav: NAV = NAV.new()
	var host: Control = Control.new()
	var storage: FailureStorage = FailureStorage.new(PATH)
	var counts: Array[int] = [0]
	for node: Node in [save, config, content, nav, host]:
		add_child_autofree(node)
	for service: ServiceStub in [save, config, content, nav]:
		service.initialize(FixedClock.new())
	save.configure(storage, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	nav.configure(save, config, content)
	assert_eq(
		nav.configure_p2(
			func() -> Error:
				counts[0] += 1
				return OK,
			animated
		),
		OK
	)
	nav.configure_screens(func(_screen: int) -> Node: return PersistScreen.new())
	return {
		"save": save,
		"config": config,
		"content": content,
		"nav": nav,
		"host": host,
		"storage": storage,
		"background": counts
	}


func _saved_slot(slot: int) -> void:
	assert_eq(_b.save.load(), OK)
	var progress: Dictionary = _b.save.get_section(&"progress")
	progress.by_lang.pl.current_slot = slot
	progress.by_lang.pl.highest_completed_slot = slot - 1
	progress.by_lang.pl.completed_slot = slot - 1
	assert_eq(_b.save.set_section(&"progress", progress), OK)
	assert_eq(_b.save.flush(), OK)


func _start() -> void:
	assert_eq(_b.nav.start(_b.host, FIXTURE), OK)


func _toast() -> Toast:
	for node: Node in get_tree().get_nodes_in_group(Toast.GROUP):
		if node is Toast:
			if (
				node.get_parent() == _b.nav.mounted_screen()
				or node.get_parent().get_parent() == _b.nav
			):
				return node as Toast
	return null


func test_boot_before_at_and_after_threshold_and_terminal_slot() -> void:
	_start()
	assert_eq(_b.nav.current_screen(), NAV.Screen.LEVEL)
	assert_eq(_b.nav.level_slot(), 1)
	_saved_slot(2)
	_start()
	assert_eq(_b.nav.current_screen(), NAV.Screen.HOME)
	assert_true(_b.nav.home_unlocked())
	_saved_slot(4)
	_start()
	assert_eq(_b.nav.current_screen(), NAV.Screen.HOME)
	assert_eq(_b.nav.level_slot(), 3, "terminal display clamping does not change routing")
	assert_eq(_b.save.get_section(&"progress").by_lang.pl.current_slot, 4)


func test_boot_failure_retry_preserves_pending_messages_without_screen() -> void:
	_saved_slot(2)
	assert_eq(_b.nav.enqueue_toast("nav.toast.backup_restored"), OK)
	watch_signals(_b.nav)
	assert_eq(_b.nav.start(_b.host, "res://tests/fixtures/missing"), ERR_FILE_NOT_FOUND)
	assert_eq(_b.nav.current_screen(), NAV.Screen.BOOT)
	assert_null(_toast())
	assert_signal_not_emitted(_b.nav, "screen_changed")
	_start()
	assert_eq(_toast().text_key, "nav.toast.backup_restored")
	assert_true(_toast().visible)


func test_routes_validate_gate_and_preserve_history_slots() -> void:
	assert_eq(_b.nav.go_to_screen(NAV.Screen.JOURNEY), ERR_UNCONFIGURED)
	_start()
	assert_eq(_b.nav.go_home(), ERR_UNAVAILABLE)
	assert_eq(_b.nav.go_to_level(0), ERR_INVALID_PARAMETER)
	_saved_slot(2)
	assert_eq(_b.nav.go_home(), OK)
	watch_signals(_b.nav)
	assert_eq(_b.nav.go_home(), OK)
	assert_signal_not_emitted(_b.nav, "screen_changed")
	assert_eq(_b.nav.go_to_screen(NAV.Screen.JOURNEY), OK)
	assert_eq(_b.nav.go_to_screen(NAV.Screen.POSTCARD), OK)
	assert_eq(_b.nav.handle_back(), OK)
	assert_eq(_b.nav.current_screen(), NAV.Screen.JOURNEY)
	assert_eq(_b.nav.handle_back(), OK)
	assert_eq(_b.nav.current_screen(), NAV.Screen.HOME)
	assert_eq(_b.nav.go_to_level(2), OK)
	assert_eq(_b.nav.go_to_screen(NAV.Screen.SETTINGS), OK)
	assert_eq(_b.nav.handle_back(), OK)
	assert_eq(_b.nav.current_screen(), NAV.Screen.LEVEL)
	assert_eq(_b.nav.level_slot(), 2)
	assert_eq(_b.nav.go_to_screen(NAV.Screen.DEBUG), ERR_INVALID_PARAMETER)


func test_back_saves_before_background_and_routes_unlocked_home() -> void:
	_start()
	var screen: PersistScreen = _b.nav.mounted_screen()
	assert_eq(_b.save.set_setting(&"haptics_enabled", false), OK)
	assert_eq(_b.nav.handle_back(), OK)
	assert_eq(screen.calls, 1)
	assert_eq(_b.background[0], 1)
	assert_eq(_b.nav.current_screen(), NAV.Screen.LEVEL)
	_saved_slot(2)
	assert_eq(_b.nav.handle_back(), OK)
	assert_eq(_b.nav.current_screen(), NAV.Screen.HOME)
	assert_eq(_b.background[0], 1)
	assert_eq(_b.nav.handle_back(), OK)
	assert_eq(_b.background[0], 2)


func test_failed_screen_persistence_and_flush_preserve_screen_and_history() -> void:
	_start()
	var screen: PersistScreen = _b.nav.mounted_screen()
	screen.result = ERR_BUSY
	assert_eq(_b.nav.handle_back(), ERR_BUSY)
	assert_eq(_b.background[0], 0)
	assert_eq(_b.nav.go_to_screen(NAV.Screen.SETTINGS), ERR_BUSY)
	assert_eq(_b.nav.mounted_screen(), screen)
	screen.result = OK
	_b.storage.fail = true
	assert_eq(_b.save.set_setting(&"haptics_enabled", false), ERR_BUSY)
	assert_eq(_b.nav.handle_back(), ERR_BUSY)
	assert_eq(_b.background[0], 0)
	assert_eq(_b.nav.mounted_screen(), screen)
	_b.storage.fail = false
	assert_eq(_b.nav.handle_back(), OK)
	assert_eq(_b.background[0], 1)


func test_sheet_first_busy_and_native_notifications_do_not_navigate_twice() -> void:
	_start()
	var sheet: Sheet = Sheet.new()
	_b.host.add_child(sheet)
	assert_eq(sheet.open(), OK)
	sheet.busy = true
	assert_eq(_b.nav.handle_back(), OK)
	assert_eq(sheet.state, &"open")
	assert_eq(_b.background[0], 0)
	sheet.busy = false
	sheet.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(sheet.state, &"open", "active Nav owns native event")
	_b.nav.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(sheet.state, &"closed")
	assert_eq(_b.background[0], 0)
	_b.nav.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(_b.background[0], 1)


func test_toast_queue_validation_dedupe_fifo_and_route_retention() -> void:
	assert_eq(_b.nav.enqueue_toast(""), ERR_INVALID_PARAMETER)
	assert_eq(_b.nav.enqueue_toast("nav.toast.backup_restored", &"wrong"), ERR_INVALID_PARAMETER)
	assert_eq(_b.nav.enqueue_toast("nav.toast.backup_restored"), OK)
	assert_eq(_b.nav.enqueue_toast("nav.toast.backup_restored"), OK)
	assert_eq(_b.nav.enqueue_toast("nav.toast.purchases_restored", &"success"), OK)
	_start()
	assert_null(_toast())
	_saved_slot(2)
	assert_eq(_b.nav.go_home(), OK)
	assert_eq(_toast().text_key, "nav.toast.backup_restored")
	assert_eq(_b.nav.go_to_screen(NAV.Screen.JOURNEY), OK)
	assert_false(_toast().visible)
	assert_eq(_b.nav.handle_back(), OK)
	assert_eq(_toast().text_key, "nav.toast.purchases_restored")
	_toast().hide_message()
	await get_tree().process_frame
	assert_false(_toast().visible, "duplicate queued result was suppressed")


func test_native_transition_busy_mount_order_reentrancy_and_settlement() -> void:
	_b = _bundle(true)
	Tokens.reduced_motion = false
	var callback_errors: Array[int] = []
	_b.nav.screen_changed.connect(
		func(_screen: int) -> void:
			assert_not_null(_b.nav.mounted_screen())
			callback_errors.append(_b.nav.go_to_screen(NAV.Screen.SETTINGS))
	)
	_start()
	assert_eq(_b.nav.go_to_level(2), ERR_BUSY)
	await _b.nav.transition_finished
	assert_eq(callback_errors, [ERR_BUSY])
	assert_eq(_b.nav.mounted_screen().modulate.a, 1.0)
	assert_eq(_b.nav.mounted_screen().process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(_b.nav.go_to_screen(NAV.Screen.SETTINGS), OK)
	assert_eq(_b.nav.handle_back(), ERR_BUSY)
	await _b.nav.transition_finished
	assert_eq(_b.nav.current_screen(), NAV.Screen.SETTINGS)
	assert_eq(callback_errors, [ERR_BUSY, ERR_BUSY])
	assert_true(OS.low_processor_usage_mode)
	await get_tree().process_frame


func test_reduced_transition_is_immediate_and_back_input_is_consumed() -> void:
	_start()
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	_b.nav._unhandled_input(event)
	assert_eq(_b.background[0], 1)
	_saved_slot(2)
	watch_signals(_b.nav)
	assert_eq(_b.nav.go_home(), OK)
	assert_signal_emit_count(_b.nav, "transition_finished", 1)
	assert_eq(_b.nav.configure_p2(), OK)


func test_real_level_departure_persists_partial_board_without_enabling_atomic_gameplay() -> void:
	_b.nav.configure_screens(Callable())
	_start()
	var screen: LevelScreen = _b.nav.mounted_screen()
	var board: BoardState = screen.controller.get_board()
	board.reveal_cell(board.get_level().word_cells(0)[0])
	assert_false(screen.progress.p2_ready())
	assert_eq(_b.nav.go_to_screen(NAV.Screen.SETTINGS), OK)
	assert_eq(_b.save.get_section(&"progress").by_lang.pl.level_state, board.to_dict())
	assert_eq(_b.nav.handle_back(), OK)
	var restored: LevelScreen = _b.nav.mounted_screen()
	assert_eq(restored.controller.get_board().to_dict(), board.to_dict())


func test_backup_restored_signal_queues_until_home() -> void:
	_start()
	_b.save.backup_restored.emit()
	assert_null(_toast())
	_saved_slot(2)
	assert_eq(_b.nav.go_home(), OK)
	assert_eq(_toast().text_key, "nav.toast.backup_restored")
	assert_eq(AppBackground.new().request(), ERR_UNAVAILABLE, "headless is never backgrounded")


func test_replacing_services_resets_p2_mode_and_preserves_p1_injection() -> void:
	_start()
	_b.nav.configure(_b.save, _b.config, _b.content)
	assert_eq(_b.nav.go_home(), ERR_UNAVAILABLE, "same identities preserve P2 gate")
	var config: ConfigOverride = ConfigOverride.new()
	add_child_autofree(config)
	config.initialize(FixedClock.new())
	_b.nav.configure(_b.save, config, _b.content)
	assert_eq(_b.nav.current_screen(), NAV.Screen.BOOT)
	assert_eq(_b.nav.enqueue_toast("nav.toast.backup_restored"), ERR_UNAVAILABLE)
	assert_false(_b.nav.is_in_group(NAV.BACK_GROUP))
	assert_eq(_b.nav.start(_b.host, FIXTURE), OK)
	assert_eq(_b.nav.go_home(), OK, "replacement defaults to original P1 routing")
	_b.nav.configure(_b.save, _b.config, _b.content)
	assert_eq(_b.nav.current_screen(), NAV.Screen.BOOT)
	assert_eq(_b.nav.configure_p2(Callable(), false), OK, "a later real boot can enable P2 again")
	assert_eq(_b.nav.start(_b.host, FIXTURE), OK)
	assert_eq(_b.nav.go_home(), ERR_UNAVAILABLE)
	await get_tree().process_frame


func test_real_level_departure_retries_pending_completion_before_destroying_owner() -> void:
	_b.nav.configure_screens(Callable())
	_start()
	var screen: LevelScreen = _b.nav.mounted_screen()
	var board: BoardState = screen.controller.get_board()
	for index: int in board.get_level().word_count():
		for cell: Vector2i in board.get_level().word_cells(index):
			board.reveal_cell(cell)
	watch_signals(screen.progress)
	_b.storage.fail = true
	assert_eq(screen.progress.complete_level(1), ERR_BUSY)
	assert_eq(screen.progress.current_slot(), 2, "P1 has a live pending advance")
	assert_eq(_b.nav.go_to_screen(NAV.Screen.SETTINGS), ERR_BUSY)
	assert_eq(_b.nav.mounted_screen(), screen)
	assert_signal_not_emitted(screen.progress, "completed")
	_b.storage.fail = false
	assert_eq(_b.nav.handle_back(), OK)
	assert_eq(_b.nav.current_screen(), NAV.Screen.HOME, "retry crossed the durable Home threshold")
	assert_eq(_b.background[0], 0)
	assert_signal_emitted_with_parameters(screen.progress, "completed", [1])
	assert_eq(_b.save.committed_view().sections.progress.by_lang.pl.current_slot, 2)
	await get_tree().process_frame


func test_historical_diagnostic_level_departure_does_not_overwrite_campaign() -> void:
	_saved_slot(2)
	_b.nav.configure_screens(Callable())
	_start()
	assert_eq(_b.nav.go_to_level(1), OK)
	var screen: LevelScreen = _b.nav.mounted_screen()
	var board: BoardState = screen.controller.get_board()
	board.reveal_cell(board.get_level().word_cells(0)[0])
	var primary: String = FileAccess.get_file_as_string(PATH)
	assert_eq(_b.nav.go_to_screen(NAV.Screen.SETTINGS), OK)
	assert_eq(FileAccess.get_file_as_string(PATH), primary)
	assert_eq(_b.save.committed_view().sections.progress.by_lang.pl.current_slot, 2)
	await get_tree().process_frame


func test_lost_host_retains_toasts_without_displaying_until_a_valid_restart() -> void:
	_saved_slot(2)
	_start()
	assert_eq(_b.nav.start(null, FIXTURE), ERR_UNCONFIGURED)
	assert_eq(_b.nav.current_screen(), NAV.Screen.HOME)
	_b.host.free()
	await get_tree().process_frame
	assert_eq(_b.nav.enqueue_toast("nav.toast.purchases_restored", &"success"), OK)
	assert_null(_toast(), "no presentation without an active host")
	assert_eq(_b.nav.handle_back(), ERR_UNCONFIGURED)
	assert_eq(_b.nav.go_to_level(1), ERR_UNCONFIGURED)
	assert_eq(_b.background[0], 0)
	_b.host = Control.new()
	add_child_autofree(_b.host)
	_start()
	assert_eq(_toast().text_key, "nav.toast.purchases_restored")


func test_back_revalidates_unavailable_content_and_retains_history_for_retry() -> void:
	var content: LimitedContent = LimitedContent.new()
	_b = _bundle(false, content)
	_saved_slot(3)
	_start()
	assert_eq(_b.nav.go_to_level(3), OK)
	assert_eq(_b.nav.go_to_screen(NAV.Screen.SETTINGS), OK)
	content.available_slot = 1
	assert_eq(_b.nav.handle_back(), ERR_INVALID_PARAMETER)
	assert_eq(_b.nav.current_screen(), NAV.Screen.SETTINGS)
	content.available_slot = 3
	assert_eq(_b.nav.handle_back(), OK)
	assert_eq(_b.nav.current_screen(), NAV.Screen.LEVEL)
	assert_eq(_b.nav.level_slot(), 3)


func test_boot_callbacks_cannot_route_before_domain_loading_succeeds() -> void:
	var config: BootConfig = BootConfig.new()
	_b = _bundle(false, null, config)
	assert_eq(_b.content.load_manifest("pl", FIXTURE), OK)
	var attempts: Array[int] = []
	config.during_load = func() -> void: attempts.append(_b.nav.go_to_level(1))
	watch_signals(_b.nav)
	assert_eq(_b.nav.start(_b.host, FIXTURE), ERR_CANT_OPEN)
	assert_eq(attempts, [ERR_BUSY])
	assert_eq(_b.nav.current_screen(), NAV.Screen.BOOT)
	assert_null(_b.nav.mounted_screen())
	assert_signal_not_emitted(_b.nav, "screen_changed")
	config.fail = false
	_start()
	assert_eq(attempts, [ERR_BUSY, ERR_BUSY])
	assert_eq(_b.nav.current_screen(), NAV.Screen.LEVEL)


func test_pending_toast_deferred_callbacks_are_safe_after_navigation_owner_exit() -> void:
	_saved_slot(2)
	_start()
	assert_eq(_b.nav.enqueue_toast("nav.toast.backup_restored"), OK)
	assert_eq(_b.nav.enqueue_toast("nav.toast.purchases_restored"), OK)
	_toast().hide_message()
	_b.nav.free()
	await get_tree().process_frame
	assert_eq(_b.host.get_child_count(), 0)


func test_navigation_toast_inherits_home_theme_safe_body_and_reuses_across_routes() -> void:
	_saved_slot(2)
	_b.host.size = Vector2(1080, 1920)
	_b.nav.configure_screens(
		func(_screen: int) -> Node:
			var scaffold: ScreenScaffold = ScreenScaffold.new()
			scaffold.size = Vector2(1080, 1920)
			scaffold.debug_insets = Rect2(Vector2(24, 48), Vector2(24, 48))
			scaffold.theme = load("res://ui/theme/generated/theme_hc_130.tres") as Theme
			return scaffold
	)
	_start()
	await get_tree().process_frame
	assert_eq(_b.nav.enqueue_toast("nav.toast.backup_restored"), OK)
	await get_tree().process_frame
	var toast: Toast = _toast()
	var scaffold: ScreenScaffold = _b.nav.mounted_screen()
	assert_eq(
		toast.get_theme_color(&"TEXT", &"Palette"), scaffold.get_theme_color(&"TEXT", &"Palette")
	)
	assert_true(scaffold.body.get_global_rect().encloses(toast.get_global_rect()))
	assert_eq(_b.nav.go_to_screen(NAV.Screen.JOURNEY), OK)
	assert_eq(_toast(), toast)
	assert_false(toast.visible)
	assert_eq(_b.nav.enqueue_toast("nav.toast.purchases_restored"), OK)
	assert_eq(_b.nav.handle_back(), OK)
	await get_tree().process_frame
	assert_eq(_toast(), toast)
	assert_true(toast.visible)
