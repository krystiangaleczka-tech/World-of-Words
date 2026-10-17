extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const CONTENT: Script = preload("res://services/content.gd")
const CONFIG: Script = preload("res://services/config.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const EVENTS: Script = preload("res://services/events.gd")
const SCENE: PackedScene = preload("res://features/level/level.tscn")


class Storage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)
	var writes: int = 0
	var fail_at: int = -1

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func commit(text: String, _rotate: bool) -> Error:
		writes += 1
		if writes == fail_at:
			return ERR_FILE_CANT_WRITE
		document = JSON.parse_string(text)
		return OK


var save: SAVE
var content: CONTENT
var config: CONFIG
var economy: ECONOMY
var bus: EVENTS
var storage: Storage
var _motion: bool
var _locale: String
var _pseudo: bool


func before_each() -> void:
	_motion = Tokens.reduced_motion
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	Tokens.reduced_motion = true
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	storage = Storage.new()
	save = SAVE.new()
	content = CONTENT.new()
	config = CONFIG.new()
	economy = ECONOMY.new()
	bus = EVENTS.new()
	for node: Node in [save, content, config, economy, bus]:
		add_child_autofree(node)
	save.initialize(Clock.new())
	save.configure(storage)
	assert_eq(save.load(), OK)
	assert_eq(content.load_manifest("pl"), OK)
	assert_eq(config.load(), OK)
	economy.initialize(Clock.new())
	economy.configure(save, config, bus)


func after_each() -> void:
	Tokens.reduced_motion = _motion
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo


func view(dimensions: Vector2i = Vector2i(1080, 1920)) -> SubViewport:
	var result: SubViewport = SubViewport.new()
	result.size = dimensions
	add_child_autofree(result)
	return result


func screen(parent: Node, tutorial: bool = true) -> LevelScreen:
	var result: LevelScreen = SCENE.instantiate()
	result.configure(save, content, 1, bus)
	assert_eq(result.configure_p2(economy, config), OK)
	if tutorial:
		assert_eq(result.configure_tutorial(), OK)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 291
	result.configure_rng(rng)
	parent.add_child(result)
	return result


func test_opt_in_guards_and_fresh_mount_does_not_write() -> void:
	var raw: LevelScreen = SCENE.instantiate()
	raw.configure(save, content, 1, bus)
	assert_eq(raw.configure_tutorial(), ERR_UNCONFIGURED)
	assert_eq(raw.configure_p2(economy, config), OK)
	raw.configure(save, content, 2, bus)
	assert_eq(raw.configure_tutorial(), ERR_UNCONFIGURED)
	raw.configure(save, null, 1, bus)
	assert_eq(raw.configure_tutorial(), ERR_UNCONFIGURED)
	raw.free()
	var writes: int = storage.writes
	var mounted: LevelScreen = screen(view())
	assert_eq(storage.writes, writes)
	assert_true(mounted.tutorial_ui.caption.visible)
	assert_eq(mounted.configure_tutorial(), ERR_BUSY)
	var p1: LevelScreen = SCENE.instantiate()
	p1.configure(save, content, 1, bus)
	view().add_child(p1)
	assert_null(p1.tutorial_ui)
	assert_true(p1.hint_button.is_visible_in_tree())
	var progress_data: Dictionary = save.get_section(&"progress")
	progress_data.by_lang.pl.current_slot = 2
	assert_eq(save.set_section(&"progress", progress_data), OK)
	assert_eq(save.flush(), OK)
	raw = SCENE.instantiate()
	raw.configure(save, content, 1, bus)
	assert_eq(raw.configure_p2(economy, config), OK)
	assert_eq(raw.configure_tutorial(), ERR_UNCONFIGURED)
	raw.free()


func test_native_swipe_touch_keeps_caption_then_committed_word_hides_once() -> void:
	var viewport: SubViewport = view()
	var host: LevelScreen = screen(viewport)
	await wait_process_frames(4)
	watch_signals(bus)
	watch_signals(host.controller)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	touch.position = host.wheel.get_global_transform() * host.wheel.tile_position(0)
	viewport.push_input(touch, true)
	assert_eq(host.tutorial_ui.hand.state, &"hidden")
	assert_true(host.tutorial_ui.caption.visible)
	assert_eq(int(save.onboarding_snapshot().step), 0)
	for index: int in [1, 2]:
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.index = 3
		drag.position = host.wheel.get_global_transform() * host.wheel.tile_position(index)
		viewport.push_input(drag, true)
	touch.pressed = false
	touch.position = host.wheel.get_global_transform() * host.wheel.tile_position(2)
	viewport.push_input(touch, true)
	assert_false(host.tutorial_ui.caption.visible)
	assert_eq(int(save.onboarding_snapshot().step), 1)
	assert_signal_emit_count(host.controller, "player_word_committed", 1)
	assert_signal_emit_count(bus, "onboarding_step", 1)
	assert_eq(host.progress.current_slot(), 2)
	host.controller.submit(PackedInt32Array([0, 1, 2]))
	assert_signal_emit_count(bus, "onboarding_step", 1)


func test_invalid_short_repeat_and_hints_do_not_finish_lesson() -> void:
	var host: LevelScreen = screen(view())
	watch_signals(host.controller)
	host.controller.submit(PackedInt32Array([0]))
	host.controller.submit(PackedInt32Array([1, 0, 2]))
	assert_true(host.controller.hint())
	assert_true(host.tutorial_ui.caption.visible)
	assert_eq(int(save.onboarding_snapshot().step), 0)
	assert_signal_emit_count(host.controller, "player_word_committed", 0)
	host.controller.submit(PackedInt32Array([0, 2, 1]))
	assert_false(host.tutorial_ui.caption.visible)
	assert_signal_emit_count(host.controller, "player_word_committed", 1)
	host.controller.submit(PackedInt32Array([0, 2, 1]))
	assert_signal_emit_count(host.controller, "player_word_committed", 1)


func test_failed_progress_does_not_teach_until_exact_retry() -> void:
	var host: LevelScreen = screen(view())
	watch_signals(host.controller)
	storage.fail_at = storage.writes + 1
	assert_null(host.controller.submit(PackedInt32Array([0, 2, 1])))
	assert_true(host.tutorial_ui.caption.visible)
	assert_eq(int(save.onboarding_snapshot().step), 0)
	assert_signal_emit_count(host.controller, "player_word_committed", 0)
	assert_not_null(host.controller.submit(PackedInt32Array([1, 0, 2])))
	assert_eq(int(save.onboarding_snapshot().step), 1)
	assert_signal_emit_count(host.controller, "player_word_committed", 1)
	assert_eq(host.controller.get_board().bonus_words(), PackedStringArray(["KTO"]))


func test_metadata_failure_hides_live_lesson_and_retries_without_word_replay() -> void:
	var host: LevelScreen = screen(view())
	watch_signals(bus)
	storage.fail_at = storage.writes + 2
	assert_not_null(host.controller.submit(PackedInt32Array([0, 2, 1])))
	assert_true(host.tutorial_ui.pending)
	assert_false(host.tutorial_ui.caption.visible)
	assert_eq(int(save.onboarding_snapshot().step), 0)
	assert_eq(host.status_label.text, tr("level.state.persistence_failed"))
	var board: Dictionary = host.controller.get_board().to_dict()
	var progress_data: Dictionary = save.get_section(&"progress")
	assert_eq(host.retry_tutorial(), OK)
	assert_false(host.tutorial_ui.pending)
	assert_eq_deep(host.controller.get_board().to_dict(), board)
	assert_eq_deep(save.get_section(&"progress"), progress_data)
	assert_eq(int(save.onboarding_snapshot().step), 1)
	assert_signal_emit_count(bus, "onboarding_step", 1)
	assert_signal_emit_count(bus, "bonus_found", 1)
	assert_eq(host.retry_tutorial(), OK)
	assert_signal_emit_count(bus, "onboarding_step", 1)


func test_navigation_retries_pending_metadata_and_respects_failure() -> void:
	var host: LevelScreen = screen(view())
	storage.fail_at = storage.writes + 2
	host.controller.submit(PackedInt32Array([0, 2, 1]))
	storage.fail_at = storage.writes + 1
	assert_eq(host.prepare_navigation(), ERR_FILE_CANT_WRITE)
	assert_true(host.tutorial_ui.pending)
	assert_eq(host.prepare_navigation(), OK)
	assert_false(host.tutorial_ui.pending)
	assert_eq(int(save.onboarding_snapshot().step), 1)


func test_restore_hint_derived_words_never_infers_player_solve() -> void:
	var viewport: SubViewport = view()
	var host: LevelScreen = screen(viewport, false)
	for index: int in 2:
		assert_true(host.controller.hint())
	assert_eq(host.prepare_navigation(), OK)
	host.free()
	host = screen(viewport)
	assert_eq(host.controller.get_board().revealed_cells().size(), 2)
	assert_true(host.tutorial_ui.caption.visible)
	assert_eq(int(save.onboarding_snapshot().step), 0)
	# A fully hint-derived found_words record is ambiguous as well.
	var board: BoardState = BoardState.new(content.level_for_slot(1))
	for cell: Vector2i in board.get_level().word_cells(0):
		board.reveal_cell(cell)
	var record: Dictionary = board.to_dict()
	assert_eq(record.found_words, ["KOT"])
	# Persist a consistent restored checkpoint without manufacturing an attempted word.
	var section: Dictionary = save.get_section(&"progress")
	section.by_lang.pl.level_state = record
	assert_eq(save.set_section(&"progress", section), OK)
	assert_eq(save.flush(), OK)
	host.free()
	host = screen(viewport)
	assert_eq(host.controller.get_board().found_words(), PackedStringArray(["KOT"]))
	assert_true(host.tutorial_ui.caption.visible)
	assert_eq(int(save.onboarding_snapshot().step), 0)


func test_restored_eligible_bonus_reconciles_and_committed_state_suppresses() -> void:
	var viewport: SubViewport = view()
	var host: LevelScreen = screen(viewport, false)
	host.controller.submit(PackedInt32Array([0, 2, 1]))
	host.free()
	watch_signals(bus)
	host = screen(viewport)
	assert_eq(int(save.onboarding_snapshot().step), 1)
	assert_false(host.tutorial_ui.caption.visible)
	assert_signal_emit_count(bus, "onboarding_step", 1)
	host.free()
	var section: Dictionary = save.get_section(&"progress")
	section.by_lang.pl.level_state = null
	assert_eq(save.set_section(&"progress", section), OK)
	assert_eq(save.flush(), OK)
	host = screen(viewport)
	assert_false(host.tutorial_ui.caption.visible)
	assert_eq(host.tutorial_ui.hand.state, &"hidden")
	assert_signal_emit_count(bus, "onboarding_step", 1)


func test_controller_freezes_player_source_before_presentation_and_excludes_diagnostics() -> void:
	var host: LevelScreen = screen(view())
	host.controller.state_changed.connect(
		func() -> void:
			assert_false(host.tutorial_ui.caption.visible)
			assert_eq(int(save.onboarding_snapshot().step), 1)
	)
	host.controller.result_ready.connect(
		func(result: AttemptResult) -> void: result.kind = AttemptResult.Kind.INVALID
	)
	host.controller.submit(PackedInt32Array([0, 2, 1]))
	assert_eq(int(save.onboarding_snapshot().step), 1)
	var controller: LevelController = LevelController.new()
	add_child_autofree(controller)
	assert_true(
		controller.configure(BoardState.new(content.level_for_slot(1)), host.progress, bus, false)
	)
	watch_signals(controller)
	controller.submit(PackedInt32Array([0, 1, 2]))
	assert_signal_emit_count(controller, "player_word_committed", 0)


func test_retained_reentry_resize_and_reduced_motion_preserve_touch_dismissal() -> void:
	Tokens.reduced_motion = false
	var viewport: SubViewport = view()
	var host: LevelScreen = screen(viewport)
	await wait_process_frames(4)
	assert_eq(host.tutorial_ui.hand.state, &"playing")
	var press: InputEventScreenTouch = InputEventScreenTouch.new()
	press.pressed = true
	host.wheel.gui_input.emit(press)
	host.tutorial_ui.hand.cancel()
	viewport.remove_child(host)
	viewport.add_child(host)
	viewport.size = Vector2i(1440, 1920)
	await wait_process_frames(4)
	assert_true(host.tutorial_ui.caption.visible)
	assert_eq(host.tutorial_ui.hand.state, &"hidden")
	assert_eq(host.controller.player_word_committed.get_connections().size(), 1)
	assert_eq(host.wheel.gui_input.get_connections().size(), 1)
	host.controller.submit(PackedInt32Array([0, 2, 1]))
	assert_false(host.tutorial_ui.caption.visible)
	viewport.remove_child(host)
	viewport.add_child(host)
	await wait_process_frames(3)
	assert_false(host.tutorial_ui.caption.visible)


func test_layout_matrix_uses_actual_target_centres_and_static_arrow() -> void:
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				TranslationServer.pseudolocalization_enabled = pseudo
				var viewport: SubViewport = view(dimensions)
				var host: LevelScreen = screen(viewport)
				host.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				await wait_process_frames(4)
				assert_eq(host.tutorial_ui.hand.state, &"static")
				assert_false(host.tutorial_ui.hand.is_processing())
				var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(dimensions))
				for control: Control in [
					host.tutorial_ui.caption, host.board_view, host.wheel, host.preview
				]:
					assert_true(bounds.encloses(control.get_global_rect()), str(control))
				assert_eq(host.tutorial_ui.hand.points.size(), 3)
				for index: int in 3:
					assert_almost_eq(
						host.tutorial_ui.hand.points[index],
						host.wheel.position + host.wheel.tile_position(index),
						Vector2.ONE * 0.01
					)
				assert_false(host.hint_button.is_visible_in_tree())
				assert_false(host.shuffle_button.is_visible_in_tree())
				assert_false(host.p2_hud.settings.is_inside_tree())
				viewport.free()


func test_retry_never_commits_an_unrelated_pending_coach() -> void:
	var host: LevelScreen = screen(view())
	assert_eq(save.complete_tutorial(), OK)
	host.progress.completed.connect(
		func(_slot: int) -> void:
			storage.fail_at = storage.writes + 1
			assert_eq(save.mark_coach_seen(&"shuffle"), ERR_FILE_CANT_WRITE)
	)
	host.controller.submit(PackedInt32Array([0, 1, 2]))
	assert_true(host.tutorial_ui.pending)
	var writes: int = storage.writes
	assert_eq(host.retry_tutorial(), ERR_BUSY)
	assert_eq(storage.writes, writes)
	assert_eq(save.retry_onboarding(), OK)
	assert_eq(host.retry_tutorial(), OK)
	assert_false(host.tutorial_ui.pending)


func test_real_atomic_p2_checkpoint_and_completion_finish_teaching_once() -> void:
	var path: String = "user://t0291-atomic-proof.json"
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(path + suffix)
	var owner: SAVE = SAVE.new()
	var progress_owner: Node = load("res://services/progress.gd").new()
	var wallet: ECONOMY = ECONOMY.new()
	for node: Node in [owner, progress_owner, wallet]:
		add_child_autofree(node)
	owner.initialize(Clock.new())
	progress_owner.initialize(Clock.new())
	wallet.initialize(Clock.new())
	owner.configure(
		SaveStorage.new(path), func() -> String: return "12345678-1234-4234-8234-123456789abc"
	)
	progress_owner.configure(owner, content)
	assert_eq(progress_owner.configure_atomic(config), OK)
	wallet.configure(owner, config, bus)
	var port: AtomicProgressPort = AtomicProgressPort.new()
	assert_eq(port.configure(owner, progress_owner, wallet), OK)
	assert_eq(owner.load(), OK)
	assert_eq(progress_owner.configure_p2(config, port, bus), OK)
	var host: LevelScreen = SCENE.instantiate()
	host.configure(owner, content, 1, bus)
	assert_eq(host.configure_p2(wallet, config), OK)
	assert_eq(host.configure_paid_tools(progress_owner, port), OK)
	assert_eq(host.configure_bonus_meter(), OK)
	assert_eq(host.configure_tutorial(), OK)
	view().add_child(host)
	watch_signals(bus)
	assert_not_null(host.controller.submit(PackedInt32Array([0, 2, 1])))
	assert_eq(int(owner.onboarding_snapshot().step), 1)
	assert_false(host.tutorial_ui.caption.visible)
	assert_signal_emit_count(bus, "onboarding_step", 1)
	assert_not_null(host.controller.submit(PackedInt32Array([0, 1, 2])))
	assert_eq(progress_owner.current_slot(), 2)
	assert_signal_emit_count(bus, "onboarding_step", 1)
	assert_eq(int(JSON.parse_string(FileAccess.get_file_as_string(path)).meta.onboarding_step), 1)
	host.free()
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(path + suffix)
