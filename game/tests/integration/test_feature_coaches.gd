# gdlint: disable=max-public-methods
extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const CONTENT: Script = preload("res://services/content.gd")
const CONFIG: Script = preload("res://services/config.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const EVENTS: Script = preload("res://services/events.gd")
const FIXTURE: Script = preload("res://tests/integration/test_level_tutorial.gd")
const LEVEL: PackedScene = preload("res://features/level/level.tscn")
const HOME: PackedScene = preload("res://features/home/home.tscn")
var save: SAVE
var content: CONTENT
var config: CONFIG
var economy: ECONOMY
var bus: EVENTS
var storage: FIXTURE.Storage
var blocked: bool = false
var _motion: bool
var _locale: String
var _pseudo: bool
var _targets: Dictionary[StringName, ActionButton] = {}
var _captions: Dictionary[StringName, Label] = {}


func before_each() -> void:
	_motion = Tokens.reduced_motion
	_locale = TranslationServer.get_locale()
	_pseudo = TranslationServer.pseudolocalization_enabled
	Tokens.reduced_motion = true
	TranslationServer.set_locale("pl")
	TranslationServer.pseudolocalization_enabled = false
	save = SAVE.new()
	content = CONTENT.new()
	config = CONFIG.new()
	economy = ECONOMY.new()
	bus = EVENTS.new()
	for node: Node in [save, content, config, economy, bus]:
		add_child_autofree(node)
	storage = FIXTURE.Storage.new()
	save.initialize(Clock.new())
	save.configure(storage)
	assert_eq(save.load(), OK)
	assert_eq(content.load_manifest("pl"), OK)
	assert_eq(config.load(), OK)
	economy.initialize(Clock.new())
	economy.configure(save, config, bus)
	assert_eq(save.configure_onboarding(bus), OK)
	assert_eq(save.complete_tutorial(), OK)
	blocked = false
	_targets.clear()
	_captions.clear()


func after_each() -> void:
	Tokens.reduced_motion = _motion
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo


func _view(dimensions: Vector2i = Vector2i(1080, 1920)) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = dimensions
	add_child_autofree(viewport)
	return viewport


func _advance(slot: int) -> void:
	var section: Dictionary = save.get_section(&"progress")
	section.by_lang.pl.current_slot = slot
	assert_eq(save.set_section(&"progress", section), OK)
	assert_eq(save.flush(), OK)


func _protocol(viewport: SubViewport) -> FeatureCoaches:
	var area: Control = Control.new()
	area.size = Vector2(viewport.size)
	viewport.add_child(area)
	for feature: String in FeatureCoaches.FEATURES:
		var target: IconButton = IconButton.new()
		target.configure_icon(preload("res://assets/icons/shuffle.svg"), "level.hud.shuffle")
		target.size = Vector2.ONE * Tokens.Touch.MIN_TARGET
		area.add_child(target)
		_targets[StringName(feature)] = target
		var caption: Label = CatalogSurface.label(&"Caption")
		caption.visible = false
		area.add_child(caption)
		_captions[StringName(feature)] = caption
	var helper: FeatureCoaches = FeatureCoaches.new()
	assert_eq(
		helper.configure(
			save,
			bus,
			func(feature: StringName, target: Control) -> bool:
				return _targets.get(feature) == target,
			func() -> bool: return blocked
		),
		OK
	)
	area.add_child(helper)
	return helper


func _show(helper: FeatureCoaches, feature: StringName) -> Error:
	return helper.show(feature, _targets[feature], _captions[feature])


func _level(viewport: SubViewport, slot: int, opt_in: bool = true) -> LevelScreen:
	var host: LevelScreen = LEVEL.instantiate()
	host.configure(save, content, slot, bus)
	assert_eq(host.configure_p2(economy, config), OK)
	if opt_in:
		assert_eq(host.configure_coaches(func() -> bool: return blocked), OK)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 292
	host.configure_rng(rng)
	viewport.add_child(host)
	return host


func _home(viewport: SubViewport) -> Control:
	var host: Control = HOME.instantiate()
	var nav: Node = Node.new()
	add_child_autofree(nav)
	host.configure(save, content, config, nav)
	assert_eq(host.configure_coaches(bus, func() -> bool: return blocked), OK)
	viewport.add_child(host)
	return host


func test_validate_before_write_and_preserve_foreign_highlight() -> void:
	var helper: FeatureCoaches = _protocol(_view())
	var writes: int = storage.writes
	assert_eq(helper.show(&"coins", _targets[&"hint"], _captions[&"hint"]), ERR_INVALID_PARAMETER)
	_targets[&"hint"].highlighted = true
	assert_eq(_show(helper, &"hint"), ERR_INVALID_PARAMETER)
	helper.dismiss()
	assert_true(_targets[&"hint"].highlighted)
	_targets[&"shuffle"].hide()
	assert_eq(_show(helper, &"shuffle"), ERR_INVALID_PARAMETER)
	var foreign: Label = CatalogSurface.label(&"Caption")
	foreign.visible = false
	add_child_autofree(foreign)
	assert_eq(helper.show(&"reveal", _targets[&"reveal"], foreign), ERR_INVALID_PARAMETER)
	assert_eq(storage.writes, writes)
	assert_eq(helper.active_feature(), &"")


func test_persist_before_paint_and_save_callback_reentry_is_busy() -> void:
	var helper: FeatureCoaches = _protocol(_view())
	bus.onboarding_step.connect(
		func(step: int) -> void:
			assert_eq(step, 2)
			assert_true("shuffle" in save.onboarding_snapshot().seen)
			assert_eq(helper.active_feature(), &"")
			assert_false(_targets[&"shuffle"].highlighted)
			assert_false(_captions[&"shuffle"].visible)
			assert_eq(_show(helper, &"hint"), ERR_BUSY)
			helper.refresh()
	)
	assert_eq(_show(helper, &"shuffle"), OK)
	assert_eq(helper.active_feature(), &"shuffle")
	assert_true(_targets[&"shuffle"].highlighted)
	assert_true(_captions[&"shuffle"].visible)
	var writes: int = storage.writes
	assert_eq(_show(helper, &"shuffle"), OK)
	assert_eq(storage.writes, writes)


func test_queue_waits_for_explicit_consent_resolution_and_single_active_fifo() -> void:
	var helper: FeatureCoaches = _protocol(_view())
	blocked = true
	assert_eq(_show(helper, &"shuffle"), OK)
	assert_eq(_show(helper, &"hint"), OK)
	assert_eq(save.onboarding_snapshot().seen.size(), 0)
	blocked = false
	assert_eq(helper.active_feature(), &"")
	helper.refresh()
	assert_eq(helper.active_feature(), &"shuffle")
	assert_false("hint" in save.onboarding_snapshot().seen)
	helper.dismiss()
	await wait_process_frames(2)
	assert_eq(helper.active_feature(), &"hint")
	assert_false(_targets[&"shuffle"].highlighted)
	assert_eq(save.onboarding_snapshot().seen, ["shuffle", "hint"])


func test_failed_metadata_requires_named_retry_and_navigation_never_paints() -> void:
	var helper: FeatureCoaches = _protocol(_view())
	storage.fail_at = storage.writes + 1
	assert_eq(_show(helper, &"hint"), ERR_FILE_CANT_WRITE)
	assert_false(_captions[&"hint"].visible)
	assert_false(_targets[&"hint"].highlighted)
	var writes: int = storage.writes
	helper.refresh()
	assert_eq(storage.writes, writes)
	assert_eq(helper.retry(), OK)
	assert_eq(helper.active_feature(), &"hint")
	helper.dismiss()
	storage.fail_at = storage.writes + 1
	assert_eq(_show(helper, &"shuffle"), ERR_FILE_CANT_WRITE)
	assert_eq(helper.prepare_navigation(), OK)
	assert_eq(helper.active_feature(), &"")
	assert_false(_captions[&"shuffle"].visible)
	assert_true("shuffle" in save.onboarding_snapshot().seen)


func test_foreign_pending_action_and_unrelated_flush_cannot_authorize_replay() -> void:
	var helper: FeatureCoaches = _protocol(_view())
	storage.fail_at = storage.writes + 1
	assert_eq(save.mark_coach_seen(&"hint"), ERR_FILE_CANT_WRITE)
	assert_eq(_show(helper, &"shuffle"), ERR_BUSY)
	var writes: int = storage.writes
	assert_eq(helper.retry(), ERR_BUSY)
	assert_eq(storage.writes, writes)
	assert_eq(save.retry_onboarding(), OK)
	assert_eq(helper.retry(), OK)
	assert_eq(helper.active_feature(), &"shuffle")
	helper.dismiss()
	storage.fail_at = storage.writes + 1
	assert_eq(_show(helper, &"reveal"), ERR_FILE_CANT_WRITE)
	assert_eq(save.flush(), OK)
	assert_eq(helper.retry(), OK)
	assert_eq(helper.active_feature(), &"")
	assert_false(_captions[&"reveal"].visible)


func test_timeout_keeps_full_hold_under_reduced_motion_and_exit_does_not_replay() -> void:
	var viewport: SubViewport = _view()
	var helper: FeatureCoaches = _protocol(viewport)
	assert_eq(_show(helper, &"reveal"), OK)
	var timer: Timer = helper.get_child(0)
	assert_almost_eq(timer.wait_time, float(Tokens.Motion.TOAST_HOLD * 2) / 1000, 0.001)
	timer.timeout.emit()
	assert_eq(helper.active_feature(), &"")
	assert_eq(_show(helper, &"shuffle"), OK)
	var parent: Node = helper.get_parent()
	parent.remove_child(helper)
	assert_false(_targets[&"shuffle"].highlighted)
	assert_true(timer.is_stopped())
	parent.add_child(helper)
	assert_eq(_show(helper, &"shuffle"), OK)
	assert_eq(helper.active_feature(), &"")


func test_target_removed_or_blocker_arrives_during_commit_never_paints() -> void:
	var helper: FeatureCoaches = _protocol(_view())
	bus.onboarding_step.connect(func(_step: int) -> void: blocked = true, CONNECT_ONE_SHOT)
	assert_eq(_show(helper, &"hint"), OK)
	assert_eq(helper.active_feature(), &"")
	assert_false(_captions[&"hint"].visible)
	blocked = false
	bus.onboarding_step.connect(
		func(_step: int) -> void: _targets[&"shuffle"].free(), CONNECT_ONE_SHOT
	)
	assert_eq(_show(helper, &"shuffle"), OK)
	assert_eq(helper.active_feature(), &"")
	assert_false(_captions[&"shuffle"].visible)


func test_seen_flags_are_independent_of_maximum_step() -> void:
	var helper: FeatureCoaches = _protocol(_view())
	assert_eq(_show(helper, &"reveal"), OK)
	helper.dismiss()
	assert_eq(_show(helper, &"shuffle"), OK)
	assert_eq(int(save.onboarding_snapshot().step), 6)
	assert_true("shuffle" in save.onboarding_snapshot().seen)


func test_level_boundaries_default_opt_in_and_tutorial_prerequisite() -> void:
	_advance(1)
	var viewport: SubViewport = _view()
	var host: LevelScreen = _level(viewport, 1)
	await wait_process_frames(4)
	assert_eq(host.coaches.active_feature(), &"")
	host.free()
	_advance(2)
	host = _level(viewport, 2, false)
	assert_null(host.coaches)
	host.free()
	host = _level(viewport, 2)
	await wait_process_frames(4)
	assert_eq(host.coaches.active_feature(), &"shuffle")
	assert_false(host.hint_button.visible)
	assert_eq(host.wheel.size.x, float(Tokens.Layout.WHEEL_MIN))
	assert_eq(host.configure_coaches(func() -> bool: return false), ERR_BUSY)
	var raw: LevelScreen = LEVEL.instantiate()
	raw.configure(save, content, 2, bus)
	assert_eq(raw.configure_coaches(func() -> bool: return false), ERR_UNCONFIGURED)
	raw.free()


func test_bonus_only_after_committed_eligible_bonus_and_modal_completion_blockers() -> void:
	assert_eq(save.mark_coach_seen(&"shuffle"), OK)
	_advance(5)
	var host: LevelScreen = _level(_view(), 5)
	await wait_process_frames(4)
	assert_eq(host.coaches.active_feature(), &"")
	blocked = true
	var level: LevelData = host.controller.get_board().get_level()
	var tiles: PackedInt32Array = _spell(level, level.bonus_words()[0])
	assert_not_null(host.controller.submit(tiles))
	await wait_process_frames(2)
	assert_eq(host.coaches.active_feature(), &"")
	assert_false("bonus" in save.onboarding_snapshot().seen)
	blocked = false
	host.refresh_coaches()
	assert_eq(host.coaches.active_feature(), &"bonus")
	host.completion_layer.visible = true
	host.refresh_coaches()
	assert_eq(host.coaches.active_feature(), &"")


func _spell(level: LevelData, word: String) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for character: String in word:
		for index: int in level.tile_count():
			if level.tile_letter(index) == character and index not in result:
				result.append(index)
				break
	return result


func test_native_touch_dismisses_without_moving_wheel_and_same_swipe_submits() -> void:
	_advance(2)
	var viewport: SubViewport = _view()
	var host: LevelScreen = _level(viewport, 2)
	await wait_process_frames(4)
	var before: Rect2 = host.wheel.get_global_rect()
	var tiles: PackedInt32Array = _spell(
		host.controller.get_board().get_level(), host.controller.get_board().get_level().word(0)
	)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 4
	touch.pressed = true
	touch.position = host.wheel.get_global_transform() * host.wheel.tile_position(tiles[0])
	viewport.push_input(touch, true)
	assert_eq(host.coaches.active_feature(), &"")
	assert_eq(host.wheel.get_global_rect(), before)
	assert_true(host.wheel.is_dragging())
	for index: int in range(1, tiles.size()):
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.index = 4
		drag.position = host.wheel.get_global_transform() * host.wheel.tile_position(tiles[index])
		viewport.push_input(drag, true)
	touch.pressed = false
	viewport.push_input(touch, true)
	assert_true(host.controller.is_complete())
	assert_eq(host.progress.current_slot(), 3)


func test_native_mouse_on_target_still_shuffles_and_foreign_highlight_survives_offer_refresh(
) -> void:
	_advance(2)
	var viewport: SubViewport = _view()
	var host: LevelScreen = _level(viewport, 2)
	await wait_process_frames(4)
	watch_signals(bus)
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = host.shuffle_button.get_global_rect().get_center()
	mouse.pressed = true
	viewport.push_input(mouse, true)
	assert_eq(host.coaches.active_feature(), &"")
	mouse.pressed = false
	viewport.push_input(mouse, true)
	assert_signal_emit_count(bus, "shuffle_performed", 1)


func test_home_journey_guard_caption_and_retained_entry() -> void:
	_advance(9)
	var viewport: SubViewport = _view()
	var home: Control = _home(viewport)
	await wait_process_frames(4)
	assert_eq(home.coaches.active_feature(), &"")
	home.free()
	_advance(10)
	blocked = true
	home = _home(viewport)
	await wait_process_frames(4)
	assert_eq(home.coaches.active_feature(), &"")
	blocked = false
	home.refresh_coaches()
	assert_eq(home.coaches.active_feature(), &"journey")
	assert_true(home.coach_caption.visible)
	viewport.remove_child(home)
	viewport.add_child(home)
	await wait_process_frames(4)
	assert_eq(home.coaches.active_feature(), &"")
	assert_false(home.coach_caption.visible)
	assert_eq(home.prepare_navigation(), OK)


func test_native_layout_matrix_captions_avoid_wheel_tile_hits() -> void:
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				TranslationServer.pseudolocalization_enabled = pseudo
				_advance(12)
				var viewport: SubViewport = _view(dimensions)
				var host: LevelScreen = _level(viewport, 12)
				host.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				await wait_process_frames(4)
				for label: Node in host.wheel.get_parent().get_children():
					if label is Label and label.theme_type_variation == &"Caption":
						assert_true(
							Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(
								label.get_global_rect()
							)
						)
						assert_false(
							label.get_global_rect().intersects(host.wheel.get_global_rect())
						)
				assert_eq(host.wheel.size.x, float(Tokens.Layout.WHEEL_MIN))
				viewport.free()


func test_tutorial_prerequisite_and_actual_save_restart_suppress_seen() -> void:
	storage = FIXTURE.Storage.new()
	save = SAVE.new()
	add_child_autofree(save)
	save.initialize(Clock.new())
	save.configure(storage)
	assert_eq(save.load(), OK)
	var viewport: SubViewport = _view()
	var helper: FeatureCoaches = _protocol(viewport)
	var writes: int = storage.writes
	assert_eq(_show(helper, &"shuffle"), ERR_UNAVAILABLE)
	assert_eq(storage.writes, writes)
	assert_eq(save.complete_tutorial(), OK)
	assert_eq(_show(helper, &"shuffle"), OK)
	helper.dismiss()
	var restored: SAVE = SAVE.new()
	add_child_autofree(restored)
	restored.initialize(Clock.new())
	restored.configure(storage)
	assert_eq(restored.load(), OK)
	var second: FeatureCoaches = FeatureCoaches.new()
	assert_eq(
		second.configure(
			restored,
			bus,
			func(_feature: StringName, _target: Control) -> bool: return true,
			func() -> bool: return false
		),
		OK
	)
	helper.get_parent().add_child(second)
	assert_eq(_show(second, &"shuffle"), OK)
	assert_eq(second.active_feature(), &"")


func test_queued_caption_taken_by_foreign_owner_is_not_claimed_or_cleared() -> void:
	var helper: FeatureCoaches = _protocol(_view())
	blocked = true
	assert_eq(_show(helper, &"shuffle"), OK)
	_captions[&"shuffle"].visible = true
	_captions[&"shuffle"].text = "foreign fixture"
	blocked = false
	helper.refresh()
	assert_false("shuffle" in save.onboarding_snapshot().seen)
	helper.dismiss()
	assert_true(_captions[&"shuffle"].visible)
	assert_eq(_captions[&"shuffle"].text, "foreign fixture")


func test_restored_bonus_is_coached_after_queued_screen_is_recreated() -> void:
	assert_eq(save.mark_coach_seen(&"shuffle"), OK)
	_advance(5)
	var viewport: SubViewport = _view()
	blocked = true
	var host: LevelScreen = _level(viewport, 5)
	var level: LevelData = host.controller.get_board().get_level()
	host.controller.submit(_spell(level, level.bonus_words()[0]))
	await wait_process_frames(2)
	assert_false("bonus" in save.onboarding_snapshot().seen)
	host.free()
	blocked = false
	host = _level(viewport, 5)
	await wait_process_frames(4)
	assert_eq(host.coaches.active_feature(), &"bonus")


func test_real_paid_modal_and_stuck_offer_coordinate_highlight_ownership() -> void:
	var path: String = "user://t0292-modal-proof.json"
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
	assert_eq(owner.configure_onboarding(bus), OK)
	assert_eq(owner.complete_tutorial(), OK)
	assert_eq(owner.mark_coach_seen(&"shuffle"), OK)
	_complete_campaign(progress_owner, 1, 6)
	var viewport: SubViewport = _view()
	var host: LevelScreen = LEVEL.instantiate()
	host.configure(owner, content, 7, bus)
	assert_eq(host.configure_p2(wallet, config), OK)
	assert_eq(host.configure_paid_tools(progress_owner, port), OK)
	assert_eq(host.configure_coaches(func() -> bool: return blocked), OK)
	viewport.add_child(host)
	await wait_process_frames(4)
	assert_eq(host.coaches.active_feature(), &"hint")
	assert_true(host.hint_button.highlighted)
	host.stuck_offer.refresh()
	assert_true(host.hint_button.highlighted)
	assert_false(host.stuck_offer.caption.visible)
	host.free()
	_complete_campaign(progress_owner, 7, 11)
	blocked = true
	host = LEVEL.instantiate()
	host.configure(owner, content, 12, bus)
	assert_eq(host.configure_p2(wallet, config), OK)
	assert_eq(host.configure_paid_tools(progress_owner, port), OK)
	assert_eq(host.configure_coaches(func() -> bool: return blocked), OK)
	viewport.add_child(host)
	await wait_process_frames(4)
	host.paid_tools_ui.open_shop()
	blocked = false
	host.refresh_coaches()
	assert_true(host.paid_tools_ui.modal_open())
	assert_eq(host.coaches.active_feature(), &"")
	assert_false("reveal" in owner.onboarding_snapshot().seen)
	host.paid_tools_ui.sheet.close()
	for motion: Tween in get_tree().get_processed_tweens():
		motion.custom_step(Tokens.dur(Tokens.Motion.FAST) * 2)
	await wait_process_frames(2)
	host.refresh_coaches()
	assert_eq(host.coaches.active_feature(), &"reveal")
	host.free()
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(path + suffix)


func _complete_campaign(owner: Node, first: int, last: int) -> void:
	for slot: int in range(first, last + 1):
		var board: BoardState = BoardState.new(content.level_for_slot(slot))
		assert_eq(owner.bind_board(board), OK)
		for index: int in board.get_level().word_count():
			for cell: Vector2i in board.get_level().word_cells(index):
				board.reveal_cell(cell)
		assert_eq(owner.complete_level(slot), OK)


func test_home_layout_matrix_preserves_native_target_rect_on_dismissal() -> void:
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
				# Fresh owner per case: at-most-once is never bypassed on a live owner.
				var disk: FIXTURE.Storage = FIXTURE.Storage.new()
				save = SAVE.new()
				add_child_autofree(save)
				save.initialize(Clock.new())
				save.configure(disk)
				assert_eq(save.load(), OK)
				assert_eq(save.configure_onboarding(bus), OK)
				assert_eq(save.complete_tutorial(), OK)
				_advance(10)
				TranslationServer.pseudolocalization_enabled = pseudo
				var viewport: SubViewport = _view(dimensions)
				var home: Control = _home(viewport)
				home.theme = load(
					(
						"res://ui/theme/generated/theme_hc_130.tres"
						if hc
						else "res://ui/theme/generated/theme_default_100.tres"
					)
				)
				await wait_process_frames(6)
				assert_eq(home.coaches.active_feature(), &"journey")
				var target: Control = home.find_child("Journey", true, false)
				var before: Rect2 = target.get_global_rect()
				assert_true(
					Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(before),
					str(
						[
							dimensions,
							pseudo,
							hc,
							before,
							target.get_combined_minimum_size(),
							target.get_parent().get_global_rect()
						]
					)
				)
				assert_true(
					Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(
						home.coach_caption.get_global_rect()
					)
				)
				assert_false(before.intersects(home.coach_caption.get_global_rect()))
				var touch: InputEventScreenTouch = InputEventScreenTouch.new()
				touch.pressed = true
				touch.position = Vector2.ONE * Tokens.Space.XS
				viewport.push_input(touch, true)
				touch.pressed = false
				viewport.push_input(touch, true)
				await wait_process_frames(3)
				assert_eq(home.coaches.active_feature(), &"")
				assert_eq(target.get_global_rect(), before)
				viewport.free()


func test_failed_progress_bonus_is_not_eligible_even_on_explicit_refresh() -> void:
	assert_eq(save.mark_coach_seen(&"shuffle"), OK)
	_advance(5)
	var host: LevelScreen = _level(_view(), 5)
	await wait_process_frames(4)
	var level: LevelData = host.controller.get_board().get_level()
	storage.fail_at = storage.writes + 1
	assert_null(host.controller.submit(_spell(level, level.bonus_words()[0])))
	host.refresh_coaches()
	assert_eq(host.coaches.active_feature(), &"")
	assert_false("bonus" in save.onboarding_snapshot().seen)
	assert_not_null(host.controller.submit(PackedInt32Array([0, 1, 2])))
	await wait_process_frames(3)
	assert_eq(host.coaches.active_feature(), &"bonus")


func test_off_campaign_and_missing_language_progress_reject_activation() -> void:
	_advance(2)
	var raw: LevelScreen = LEVEL.instantiate()
	raw.configure(save, content, 1, bus)
	assert_eq(raw.configure_p2(economy, config), OK)
	assert_eq(raw.configure_coaches(func() -> bool: return false), ERR_UNCONFIGURED)
	assert_eq(save.set_setting(&"language", "en"), OK)
	assert_eq(save.flush(), OK)
	raw.configure(save, content, 2, bus)
	assert_eq(raw.configure_coaches(func() -> bool: return false), ERR_UNCONFIGURED)
	raw.free()
