# gdlint: disable=max-public-methods
extends GutTest

const FIXTURE: Script = preload("res://tests/integration/test_paid_tool_transactions.gd")
const SAVE: Script = preload("res://services/save.gd")
const PROGRESS: Script = preload("res://services/progress.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONTENT: Script = preload("res://services/content.gd")
const EVENTS: Script = preload("res://services/events.gd")
const MONETIZATION: Script = preload("res://services/monetization.gd")
const SCENE: PackedScene = preload("res://features/level/level.tscn")
const PATH: String = "user://t0279-offer-save.json"


class OfferClock:
	extends Clock
	var now: int = 0

	func monotonic_msec() -> int:
		return now


class OfferConfig:
	extends "res://tests/integration/test_paid_tool_transactions.gd".ToolConfig
	var idle_seconds: int = 45
	var invalid_streak: int = 5
	var hint_unlock: int = 2

	func get_int(key: StringName) -> int:
		if key == &"unlocks.hint_slot":
			return hint_unlock
		if key == &"hint.offer_idle_seconds":
			return idle_seconds
		return invalid_streak if key == &"hint.offer_invalid_streak" else super.get_int(key)


var offer_clock: OfferClock
var b: Dictionary
var disk: FIXTURE.InterruptedStorage
var _motion: bool
var _locale: String
var _pseudo: bool


func before_each() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	_motion = Tokens.reduced_motion
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	Tokens.reduced_motion = true
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	var save: SAVE = SAVE.new()
	var progress: PROGRESS = PROGRESS.new()
	var economy: ECONOMY = ECONOMY.new()
	var content: CONTENT = CONTENT.new()
	offer_clock = OfferClock.new()
	var config: OfferConfig = OfferConfig.new()
	var bus: EVENTS = EVENTS.new()
	for node: Node in [save, progress, economy, content, config, bus]:
		add_child_autofree(node)
	var clock: FIXTURE.FixedClock = FIXTURE.FixedClock.new()
	save.initialize(clock)
	progress.initialize(clock)
	economy.initialize(clock)
	disk = FIXTURE.InterruptedStorage.new(PATH)
	save.configure(disk, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert_eq(content.load_manifest("pl", FIXTURE.ROOT), OK)
	assert_eq(config.load(), OK)
	progress.configure(save, content)
	assert_eq(progress.configure_atomic(config), OK)
	economy.configure(save, config, bus)
	var port: AtomicProgressPort = AtomicProgressPort.new()
	assert_eq(port.configure(save, progress, economy), OK)
	assert_eq(save.load(), OK)
	assert_eq(progress.configure_p2(config, port, bus), OK)
	var first: BoardState = BoardState.new(content.level_for_slot(1))
	assert_eq(progress.bind_board(first), OK)
	for index: int in first.get_level().word_count():
		for cell: Vector2i in first.get_level().word_cells(index):
			first.reveal_cell(cell)
	assert_eq(progress.complete_level(1), OK)
	b = {
		"save": save,
		"progress": progress,
		"economy": economy,
		"content": content,
		"config": config,
		"bus": bus,
		"port": port
	}
	wallet(500, 0, 0)


func after_each() -> void:
	Tokens.reduced_motion = _motion
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func wallet(coins: int, hints: int, reveals: int) -> void:
	var section: Dictionary = b.save.get_section(&"economy")
	section.coins = coins
	section.items = {"hint": hints, "reveal": reveals}
	assert_eq(b.save.set_section(&"economy", section), OK)
	assert_eq(b.save.flush(), OK)


func screen(service: Node = null, dimensions: Vector2i = Vector2i(1080, 1920)) -> LevelScreen:
	var view: SubViewport = SubViewport.new()
	view.size = dimensions
	add_child_autofree(view)
	var host: LevelScreen = SCENE.instantiate()
	host.configure(b.save, b.content, 2, b.bus)
	assert_eq(host.configure_p2(b.economy, b.config), OK)
	assert_eq(host.configure_paid_tools(b.progress, b.port, service), OK)
	assert_eq(host.configure_offer_clock(offer_clock), OK)
	view.add_child(host)
	return host


func invalid(host: LevelScreen, count: int = 1) -> void:
	for index: int in count:
		host.wheel.word_attempted.emit(PackedInt32Array([0, 0, 0]))


func test_idle_boundary_is_once_only_and_never_mutates_or_opens_a_sheet() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	watch_signals(host)
	var before: Dictionary = b.save.committed_view()
	offer_clock.now = 44999
	host.stuck_offer.refresh()
	assert_false(host.stuck_offer.caption.visible)
	offer_clock.now = 45000
	host.stuck_offer.refresh()
	assert_true(host.stuck_offer.caption.visible)
	assert_true(host.hint_button.highlighted)
	assert_signal_emitted_with_parameters(host, "stuck_offer_shown", [&"idle"])
	assert_false(host.paid_tools_ui.modal_open())
	assert_eq_deep(b.save.committed_view(), before)
	var timers: Array[Node] = host.stuck_offer.find_children("*", "Timer", false, false)
	for timer: Timer in timers:
		if not timer.is_stopped():
			timer.timeout.emit()
	assert_false(host.stuck_offer.caption.visible)
	host.stuck_offer.refresh()
	assert_signal_emit_count(host, "stuck_offer_shown", 1)


func test_invalid_threshold_ignores_short_releases_and_uses_live_config() -> void:
	b.config.invalid_streak = 3
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	watch_signals(host)
	invalid(host, 2)
	host.wheel.word_attempted.emit(PackedInt32Array([0, 1]))
	host.wheel.short_released.emit(PackedInt32Array([0, 1]))
	assert_false(host.stuck_offer.caption.visible)
	invalid(host)
	assert_true(host.stuck_offer.caption.visible)
	assert_signal_emitted_with_parameters(host, "stuck_offer_shown", [&"invalid_streak"])
	host.hint_button.pressed.emit()
	await wait_process_frames(2)
	assert_eq(b.economy.snapshot().coins, 400)
	assert_eq(host.controller.get_board().revealed_cells().size(), 1)
	assert_false(host.stuck_offer.caption.visible)


func test_level_bonus_and_already_found_reset_streak_but_only_new_words_reset_idle() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	invalid(host, 4)
	offer_clock.now = 30000
	host.wheel.word_attempted.emit(PackedInt32Array([0, 1, 2]))
	invalid(host, 4)
	assert_false(host.stuck_offer.caption.visible)
	host.wheel.word_attempted.emit(PackedInt32Array([0, 3, 2]))
	invalid(host, 4)
	assert_false(host.stuck_offer.caption.visible)
	host.wheel.word_attempted.emit(PackedInt32Array([0, 3, 2]))
	invalid(host, 4)
	assert_false(host.stuck_offer.caption.visible)
	offer_clock.now = 74999
	host.stuck_offer.refresh()
	assert_false(host.stuck_offer.caption.visible)
	offer_clock.now = 75000
	host.stuck_offer.refresh()
	assert_true(host.stuck_offer.caption.visible)


func test_modal_and_pending_write_defer_without_consuming_the_offer() -> void:
	wallet(0, 0, 0)
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	host.hint_button.pressed.emit()
	offer_clock.now = 45000
	host.stuck_offer.refresh()
	assert_false(host.stuck_offer.caption.visible)
	host.paid_tools_ui.not_now.pressed.emit()
	await wait_process_frames(3)
	assert_true(host.stuck_offer.caption.visible)
	assert_false(host.paid_tools_ui.modal_open())


func test_failed_paid_write_and_completion_cannot_show_an_offer() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	disk.stop_at = &"temp_opened"
	host.hint_button.pressed.emit()
	offer_clock.now = 45000
	host.stuck_offer.refresh()
	assert_false(host.stuck_offer.caption.visible)
	disk.stop_at = &""
	host.paid_tools_ui.retry.pressed.emit()
	await wait_process_frames(3)
	host.wheel.word_attempted.emit(PackedInt32Array([0, 1, 2]))
	host.wheel.word_attempted.emit(PackedInt32Array([2, 1, 0, 3]))
	assert_true(host.controller.is_complete())
	host.stuck_offer.refresh()
	assert_false(host.stuck_offer.caption.visible)


func test_reentry_and_application_suspend_exclude_away_time_and_preserve_latch() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	watch_signals(host)
	var parent: Node = host.get_parent()
	parent.remove_child(host)
	offer_clock.now = 50000
	parent.add_child(host)
	await wait_process_frames(3)
	assert_false(host.stuck_offer.caption.visible)
	host.stuck_offer.notification(NOTIFICATION_APPLICATION_PAUSED)
	offer_clock.now = 100000
	host.stuck_offer.notification(NOTIFICATION_APPLICATION_RESUMED)
	host.stuck_offer.refresh()
	assert_false(host.stuck_offer.caption.visible)
	offer_clock.now = 145000
	host.stuck_offer.refresh()
	assert_true(host.stuck_offer.caption.visible)
	parent.remove_child(host)
	parent.add_child(host)
	await wait_process_frames(3)
	offer_clock.now += 45000
	host.stuck_offer.refresh()
	assert_false(host.stuck_offer.caption.visible)
	assert_signal_emit_count(host, "stuck_offer_shown", 1)
	assert_eq(host.controller.result_ready.get_connections().size(), 2)


func test_normal_motion_stops_on_exit() -> void:
	Tokens.reduced_motion = false
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	offer_clock.now = 45000
	host.stuck_offer.refresh()
	assert_true(host.hint_button.highlighted)
	var parent: Node = host.get_parent()
	parent.remove_child(host)
	assert_false(host.hint_button.highlighted)
	assert_eq(host.hint_button.scale, Vector2.ONE)
	parent.add_child(host)
	await wait_process_frames(3)
	assert_false(host.stuck_offer.caption.visible)


func test_twelve_case_native_caption_geometry_and_noninteractive_copy() -> void:
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				offer_clock.now = 0
				TranslationServer.pseudolocalization_enabled = pseudo
				var host: LevelScreen = screen(null, dimensions)
				host.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				await wait_process_frames(3)
				var wheel_rect: Rect2 = host.wheel.get_global_rect()
				offer_clock.now = 45000
				host.stuck_offer.refresh()
				await wait_process_frames(3)
				var caption: Label = host.stuck_offer.caption
				assert_true(caption.is_visible_in_tree())
				assert_eq(host.wheel.get_global_rect(), wheel_rect)
				assert_false(caption.text.is_empty())
				assert_eq(caption.mouse_filter, Control.MOUSE_FILTER_IGNORE)
				assert_true(
					Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(caption.get_global_rect())
				)
				assert_false(caption.get_global_rect().intersects(host.wheel.get_global_rect()))
				assert_gte(
					caption.size.y, float(caption.get_line_height() * caption.get_line_count())
				)
				host.get_parent().free()


func test_locked_hint_and_replaced_owner_configuration_never_offer() -> void:
	b.config.hint_unlock = 3
	var section: Dictionary = b.save.get_section(&"progress")
	section.unlocked.erase("hint")
	section.by_lang.pl.unlocked.erase("hint")
	assert_eq(b.save.set_section(&"progress", section), OK)
	assert_eq(b.save.flush(), OK)
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	offer_clock.now = 45000
	host.stuck_offer.refresh()
	assert_false(host.stuck_offer.caption.visible)
	assert_false(host.hint_button.visible)
	b.config.hint_unlock = 2
	var alternate: OfferConfig = OfferConfig.new()
	add_child_autofree(alternate)
	assert_eq(alternate.load(), OK)
	b.economy.configure(b.save, alternate, b.bus)
	host.refresh_paid_hud()
	host.stuck_offer.refresh()
	assert_false(host.stuck_offer.caption.visible)
	assert_false(host.hint_button.highlighted)


func test_paid_reveal_word_resets_idle_before_the_old_deadline() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	offer_clock.now = 44000
	host.p2_hud.reveal.activated.emit(&"reveal")
	await wait_process_frames(3)
	assert_true("MODA" in host.controller.get_board().found_words())
	offer_clock.now = 45000
	host.stuck_offer.refresh()
	assert_false(host.stuck_offer.caption.visible)
	offer_clock.now = 89000
	host.stuck_offer.refresh()
	assert_true(host.stuck_offer.caption.visible)
