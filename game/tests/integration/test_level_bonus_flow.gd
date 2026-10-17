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
const BONUS_FIXTURE: Script = preload("res://tests/integration/test_bonus_transactions.gd")
const PATH: String = "user://t0280-ui-save.json"
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
	var config: BONUS_FIXTURE.BonusConfig = BONUS_FIXTURE.BonusConfig.new()
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
	assert_eq(host.configure_bonus_meter(), OK)
	view.add_child(host)
	return host


func counter(count: int) -> void:
	var section: Dictionary = b.save.get_section(&"economy")
	section.bonus_counter = count
	assert_eq(b.save.set_section(&"economy", section), OK)
	assert_eq(b.save.flush(), OK)


func find_bonus(host: LevelScreen) -> void:
	host.wheel.word_attempted.emit(PackedInt32Array([0, 3, 2]))


func complete(host: LevelScreen) -> void:
	host.wheel.word_attempted.emit(PackedInt32Array([0, 1, 2]))
	host.wheel.word_attempted.emit(PackedInt32Array([2, 1, 0, 3]))


func test_bonus_increments_once_and_full_meter_is_noninteractive_mid_level() -> void:
	counter(9)
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	watch_signals(host.p2_hud.meter)
	find_bonus(host)
	assert_eq(host.p2_hud.meter.count, 10)
	assert_eq(b.economy.snapshot().bonus_counter, 10)
	assert_eq(b.economy.snapshot().coins, 500)
	assert_eq(host.bonus_ui.burst.state, &"idle")
	assert_false(host.completion_layer.visible)
	assert_true(host.p2_hud.meter.disabled)
	assert_eq(host.p2_hud.meter.focus_mode, Control.FOCUS_NONE)
	host.p2_hud.meter.pressed.emit()
	assert_signal_emit_count(host.p2_hud.meter, "open_requested", 0)
	find_bonus(host)
	assert_eq(host.p2_hud.meter.count, 10)
	assert_eq(host.p2_hud.meter.state, &"already")
	assert_eq(b.economy.snapshot().coins, 500)


func test_bonus_survives_screen_recreation_and_actual_save_restart() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	find_bonus(host)
	assert_eq(b.economy.snapshot().bonus_counter, 1)
	host.get_parent().free()
	var again: LevelScreen = screen()
	await wait_process_frames(3)
	assert_eq(again.p2_hud.meter.count, 1)
	assert_true("DAM" in again.controller.get_board().bonus_words())
	find_bonus(again)
	assert_eq(again.p2_hud.meter.count, 1)
	var disk_save: SAVE = SAVE.new()
	add_child_autofree(disk_save)
	disk_save.initialize(FIXTURE.FixedClock.new())
	disk_save.configure(SaveStorage.new(PATH))
	assert_eq(disk_save.load(), OK)
	assert_eq(disk_save.get_section(&"economy").bonus_counter, 1)
	assert_true("DAM" in disk_save.get_section(&"progress").by_lang.pl.level_state.bonus_words)


func test_completion_redeems_multiple_chests_and_only_then_presents_their_reward() -> void:
	counter(25)
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	watch_signals(host.bonus_ui.burst)
	complete(host)
	await wait_process_frames(5)
	assert_true(host.completion_layer.visible)
	assert_false(host.wheel.is_visible_in_tree())
	assert_eq(b.economy.snapshot().bonus_counter, 5)
	assert_eq(host.p2_hud.meter.count, 5)
	assert_eq(b.economy.snapshot().coins, 700 + b.config.get_int(&"economy.reward.level_complete"))
	assert_eq(host.bonus_ui.burst.state, &"static")
	assert_signal_emitted_with_parameters(host.bonus_ui.burst, "finished", [&"chest", 2])
	assert_eq(host.bonus_ui.summary.text, host.tr("level.bonus.reward") % [2, 200])
	assert_false(host.bonus_ui.caption.visible)
	var parent: Node = host.get_parent()
	parent.remove_child(host)
	parent.add_child(host)
	await wait_process_frames(3)
	assert_eq(host.bonus_ui.burst.state, &"idle")
	assert_signal_emit_count(host.bonus_ui.burst, "finished", 1)


func test_zero_reward_still_presents_the_opened_chest_count() -> void:
	counter(10)
	b.config.payout = 0
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	complete(host)
	await wait_process_frames(5)
	assert_eq(b.economy.snapshot().bonus_counter, 0)
	assert_eq(host.bonus_ui.burst.state, &"static")
	assert_eq(host.bonus_ui.summary.text, host.tr("level.bonus.reward") % [1, 0])


func test_failed_checkpoint_and_completion_retry_publish_no_early_progress_or_reward() -> void:
	counter(9)
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	disk.stop_at = &"temp_opened"
	find_bonus(host)
	assert_eq(host.p2_hud.meter.count, 9)
	assert_eq(b.economy.snapshot().bonus_counter, 9)
	assert_eq(host.bonus_ui.burst.state, &"idle")
	disk.stop_at = &""
	host.wheel.word_attempted.emit(PackedInt32Array([0, 3, 2]))
	assert_eq(host.p2_hud.meter.count, 10)
	host.wheel.word_attempted.emit(PackedInt32Array([0, 1, 2]))
	disk.stop_at = &"temp_opened"
	host.wheel.word_attempted.emit(PackedInt32Array([2, 1, 0, 3]))
	assert_false(host.completion_layer.visible)
	assert_eq(host.bonus_ui.burst.state, &"idle")
	assert_eq(b.economy.snapshot().coins, 500)
	disk.stop_at = &""
	host.wheel.word_attempted.emit(PackedInt32Array([2, 1, 0, 3]))
	await wait_process_frames(5)
	assert_eq(host.bonus_ui.burst.state, &"static")
	assert_eq(b.economy.snapshot().bonus_counter, 0)
	assert_eq(b.economy.snapshot().coins, 600 + b.config.get_int(&"economy.reward.level_complete"))


func test_paid_final_reveal_redeems_and_presents_the_same_completion() -> void:
	counter(10)
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	host.wheel.word_attempted.emit(PackedInt32Array([0, 1, 2]))
	host.p2_hud.reveal.activated.emit(&"reveal")
	await wait_process_frames(5)
	assert_true(host.controller.is_complete())
	assert_eq(host.bonus_ui.burst.state, &"static")
	assert_eq(b.economy.snapshot().bonus_counter, 0)
	assert_eq(b.economy.snapshot().coins, 350 + b.config.get_int(&"economy.reward.level_complete"))


func test_foreign_nonpublication_signal_cannot_fabricate_a_reward_layer() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	var before: Dictionary = b.save.committed_view()
	b.economy.bonus_chest_redeemed.emit(2, 999)
	await wait_process_frames(3)
	assert_eq(host.bonus_ui.burst.state, &"idle")
	assert_false(host.bonus_ui.summary.visible)
	assert_eq_deep(b.save.committed_view(), before)


func test_normal_motion_meter_fill_survives_redundant_refresh_and_exit_stops_burst() -> void:
	Tokens.reduced_motion = false
	counter(9)
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	find_bonus(host)
	assert_eq(host.p2_hud.meter.state, &"filling")
	host.refresh_paid_hud()
	assert_eq(host.p2_hud.meter.state, &"filling")
	complete(host)
	host.board_view.wave_finished.emit()
	await wait_process_frames(5)
	assert_true(host.bonus_ui.burst.visible)
	var parent: Node = host.get_parent()
	parent.remove_child(host)
	assert_eq(host.bonus_ui.burst.state, &"idle")
	parent.add_child(host)
	await wait_process_frames(3)
	assert_eq(host.bonus_ui.burst.state, &"idle")


func test_native_twelve_case_full_bonus_geometry() -> void:
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				counter(10)
				TranslationServer.pseudolocalization_enabled = pseudo
				var host: LevelScreen = screen(null, dimensions)
				host.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				await wait_process_frames(4)
				assert_true(host.bonus_ui.caption.visible)
				assert_true(
					Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(
						host.bonus_ui.caption.get_global_rect()
					)
				)
				assert_false(
					host.bonus_ui.caption.get_global_rect().intersects(host.wheel.get_global_rect())
				)
				assert_gte(
					host.bonus_ui.caption.size.y,
					float(
						(
							host.bonus_ui.caption.get_line_height()
							* host.bonus_ui.caption.get_line_count()
						)
					)
				)
				host.get_parent().free()


func test_opt_in_requires_paid_owners_and_no_chest_completion_still_hides_play_area() -> void:
	var unconfigured: LevelScreen = SCENE.instantiate()
	unconfigured.configure(b.save, b.content, 2, b.bus)
	assert_eq(unconfigured.configure_bonus_meter(), ERR_UNCONFIGURED)
	assert_eq(unconfigured.configure_p2(b.economy, b.config), OK)
	assert_eq(unconfigured.configure_bonus_meter(), ERR_UNCONFIGURED)
	unconfigured.free()
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	assert_eq(host.configure_bonus_meter(), ERR_BUSY)
	complete(host)
	await wait_process_frames(5)
	assert_true(host.completion_layer.visible)
	assert_false(host.wheel.is_visible_in_tree())
	assert_eq(host.bonus_ui.burst.state, &"idle")
	assert_false(host.bonus_ui.summary.visible)
