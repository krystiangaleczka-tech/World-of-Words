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
const PATH: String = "user://t0278-ui-save.json"
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
	var config: FIXTURE.ToolConfig = FIXTURE.ToolConfig.new()
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
	view.add_child(host)
	return host


func provider(outcome: StringName = &"reward", immediate: bool = true) -> Dictionary:
	var service: MONETIZATION = MONETIZATION.new()
	add_child_autofree(service)
	service.initialize(FIXTURE.FixedClock.new())
	var consent: ConsentFake = ConsentFake.new()
	consent.set_outcome(&"request_info", &"not_required")
	var ads: AdsFake = AdsFake.new()
	ads.set_outcome(&"initialize", &"ready")
	ads.set_outcome(&"load_rewarded", &"ready")
	ads.set_outcome(&"show_rewarded", outcome, immediate)
	assert_eq(service.configure(b.save, b.config, b.bus, consent, ads, false), OK)
	var store: IapFake = IapFake.new()
	store.set_products(
		[
			{"id": "nc.remove_forced_ads.v1", "restorable": true, "price": "12,99 zł"},
			{"id": "c.coins_s.v1", "restorable": false, "price": "4,99 zł"}
		]
	)
	store.set_outcome(&"query_products", &"ready")
	store.set_outcome(&"purchase", &"success", false)
	assert_eq(service.configure_iap(b.economy, store), OK)
	assert_eq(service.start_session(), OK)
	assert_eq(service.before_next_level(6), OK)
	assert_true(service.ads_ready())
	return {"service": service, "ads": ads, "store": store}


func test_item_hint_is_durable_and_rapid_reentrant_free_paths_are_guarded() -> void:
	wallet(500, 2, 0)
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	var board: BoardState = host.controller.get_board()
	var outcomes: Array[bool] = []
	host.controller.paid_tool_committed.connect(
		func(_kind: StringName, _cells: Array[Vector2i]) -> void:
			outcomes.append(host.controller.hint())
			outcomes.append(host.controller.configure(board, b.progress, b.bus))
	)
	host.hint_button.pressed.emit()
	host.hint_button.pressed.emit()
	assert_eq(outcomes, [false, false])
	assert_eq(b.economy.snapshot().items.hint, 1)
	assert_eq(b.economy.snapshot().coins, 500)
	assert_eq(host.controller.get_board().revealed_cells().size(), 1)
	assert_true(board.revealed_cells().is_empty())
	assert_null(host.controller.submit(PackedInt32Array([0, 1, 2])))
	assert_eq(host.prepare_navigation(), ERR_BUSY)
	await wait_process_frames(2)
	assert_eq(host.prepare_navigation(), OK)
	assert_false(host.controller.paid_locked())
	assert_false(
		host.controller.configure(board, b.progress, b.bus),
		"A paid controller cannot be downgraded to free"
	)
	assert_true(host.controller.hint())
	assert_eq(b.economy.snapshot().items.hint, 0)
	assert_eq(b.economy.snapshot().coins, 500)
	await wait_process_frames(2)


func test_coin_reveal_publishes_the_longest_word_without_double_charge() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	host.p2_hud.reveal.activated.emit(&"reveal")
	host.p2_hud.reveal.activated.emit(&"reveal")
	assert_eq(b.economy.snapshot().coins, 250)
	assert_true("MODA" in host.controller.get_board().found_words())
	assert_eq(host.controller.get_board().revealed_cells().size(), 4)
	for cell: Vector2i in host.controller.get_board().get_level().word_cells(1):
		assert_eq(host.board_view.cell_node(cell).state, GridCell.State.FILLED)
	assert_eq(host.p2_hud.coins.value, 250)
	await wait_process_frames(2)
	assert_false(host.controller.paid_locked())


func test_final_paid_cell_commits_stars_rewards_and_completion_once() -> void:
	var board: BoardState = BoardState.new(b.content.level_for_slot(2))
	var last: Vector2i = board.get_level().word_cells(0)[0]
	for index: int in board.get_level().word_count():
		for cell: Vector2i in board.get_level().word_cells(index):
			if cell != last:
				board.reveal_cell(cell)
	assert_eq(b.progress.save_level(board), OK)
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	watch_signals(b.progress)
	assert_true(host.controller.hint())
	assert_eq(b.economy.snapshot().coins, 400 + b.config.get_int(&"economy.reward.level_complete"))
	assert_eq(b.progress.current_slot(), 3)
	assert_eq(b.progress.stars(), 2)
	assert_true(host.completion_layer.visible)
	assert_signal_emit_count(b.progress, "completed", 1)
	assert_false(host.controller.hint())
	await wait_process_frames(2)
	assert_eq(host.prepare_navigation(), OK)
	assert_signal_emit_count(b.progress, "completed", 1)


func test_failed_write_retains_exact_retry_across_exit_and_reentry() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	var before: Dictionary = host.controller.get_board().to_dict()
	disk.stop_at = &"temp_opened"
	host.hint_button.pressed.emit()
	assert_eq(host.controller.get_board().to_dict(), before)
	assert_eq(b.economy.snapshot().coins, 500)
	assert_true(host.controller.paid_pending())
	assert_true(host.paid_tools_ui.retry.visible)
	assert_true(host.wheel.is_locked())
	watch_signals(host)
	host.p2_hud.navigation_requested.emit(&"home")
	assert_signal_not_emitted(host, "navigation_requested")
	assert_eq(host.prepare_navigation(), ERR_BUSY)
	assert_null(host.controller.submit(PackedInt32Array([0, 1, 2])))
	var parent: Node = host.get_parent()
	parent.remove_child(host)
	parent.add_child(host)
	await wait_process_frames(2)
	assert_true(host.paid_tools_ui.retry.visible)
	disk.stop_at = &""
	b.config.hint_price = 101
	host.paid_tools_ui.retry.pressed.emit()
	assert_eq(b.economy.snapshot().coins, 400)
	assert_eq(host.controller.get_board().revealed_cells().size(), 1)
	assert_false(host.controller.paid_pending())
	assert_eq(host.hint_button.price, 101)
	await wait_process_frames(2)
	assert_eq(host.prepare_navigation(), OK)
	host.hint_button.pressed.emit()
	assert_eq(b.economy.snapshot().coins, 299)
	await wait_process_frames(2)


func test_invalid_or_replaced_bindings_fail_closed() -> void:
	var other: FIXTURE.ToolConfig = FIXTURE.ToolConfig.new()
	add_child_autofree(other)
	assert_eq(other.load(), OK)
	var invalid: LevelScreen = SCENE.instantiate()
	invalid.configure(b.save, b.content, 2, b.bus)
	assert_eq(invalid.configure_p2(b.economy, other), OK)
	assert_eq(invalid.configure_paid_tools(b.progress, b.port), ERR_UNCONFIGURED)
	invalid.free()
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	b.economy.configure(b.save, other, b.bus)
	host.hint_button.pressed.emit()
	assert_eq(b.economy.snapshot().coins, 500)
	assert_true(host.controller.get_board().revealed_cells().is_empty())
	assert_eq(host.status_label.text, host.tr("level.tool.unavailable"))


func test_unaffordable_no_provider_options_and_offline_shop_use_one_sheet() -> void:
	wallet(0, 0, 0)
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	host.hint_button.pressed.emit()
	var ui: LevelPaidTools = host.paid_tools_ui
	assert_true(ui.modal_open())
	assert_true(ui.watch_ad.disabled)
	assert_eq(ui.message.text, host.tr("level.hint.ad_unavailable"))
	assert_false(ui.get_coins.disabled)
	var identity: int = ui.sheet.get_instance_id()
	ui.get_coins.grab_focus()
	for down: bool in [true, false]:
		var action: InputEventAction = InputEventAction.new()
		action.action = &"ui_accept"
		action.pressed = down
		host.get_viewport().push_input(action)
	assert_eq(ui.sheet.get_instance_id(), identity)
	assert_eq(ui.sheet.title_key, "shop.sheet.title")
	assert_true(host.controller.get_board().revealed_cells().is_empty())
	assert_true(ui.sheet.close())
	await wait_process_frames(2)
	assert_false(ui.modal_open())
	assert_false(host.wheel.is_locked())


func test_reward_grants_hint_item_without_automatically_using_hint_or_reveal() -> void:
	wallet(0, 0, 0)
	var p: Dictionary = provider()
	var host: LevelScreen = screen(p.service)
	await wait_process_frames(2)
	host.p2_hud.reveal.activated.emit(&"reveal")
	var ui: LevelPaidTools = host.paid_tools_ui
	assert_false(ui.watch_ad.disabled)
	assert_eq(ui.watch_ad.badge, &"ad")
	ui.watch_ad.pressed.emit()
	assert_eq(b.economy.snapshot().items.hint, b.config.get_int(&"economy.reward.rewarded_hint"))
	assert_eq(b.economy.snapshot().items.reveal, 0)
	assert_true(host.controller.get_board().revealed_cells().is_empty())
	assert_eq(ui.message.text, host.tr("level.hint.reward_added"))
	assert_true(ui.sheet.toast.visible)
	assert_eq(ui.sheet.toast.text_key, "level.hint.reward_added")
	assert_false(ui.sheet.busy)
	ui.not_now.pressed.emit()
	await wait_process_frames(2)
	host.hint_button.pressed.emit()
	assert_eq(host.controller.get_board().revealed_cells().size(), 1)
	assert_eq(b.economy.snapshot().items.hint, 0)
	assert_eq(b.economy.snapshot().coins, 0)
	await wait_process_frames(2)


func test_early_close_and_no_fill_never_grant_or_reveal() -> void:
	wallet(0, 0, 0)
	var p: Dictionary = provider(&"early_close")
	var host: LevelScreen = screen(p.service)
	await wait_process_frames(2)
	host.hint_button.pressed.emit()
	var ui: LevelPaidTools = host.paid_tools_ui
	ui.watch_ad.pressed.emit()
	assert_eq(b.economy.snapshot().items.hint, 0)
	assert_eq(ui.message.text, host.tr("level.hint.no_reward"))
	p.ads.set_outcome(&"show_rewarded", &"no_fill")
	ui.watch_ad.pressed.emit()
	assert_eq(ui.message.text, host.tr("level.hint.ad_unavailable"))
	assert_true(ui.watch_ad.disabled)
	assert_eq(b.economy.snapshot().items.hint, 0)
	assert_true(host.controller.get_board().revealed_cells().is_empty())
	assert_false(ui.sheet.busy)
	assert_false(ui.get_coins.disabled)


func test_reward_write_retry_does_not_request_a_second_ad() -> void:
	wallet(0, 0, 0)
	var p: Dictionary = provider()
	var host: LevelScreen = screen(p.service)
	await wait_process_frames(2)
	host.hint_button.pressed.emit()
	disk.stop_at = &"temp_opened"
	var ui: LevelPaidTools = host.paid_tools_ui
	ui.watch_ad.pressed.emit()
	assert_eq(p.service.rewarded_state(), &"pending_reward")
	assert_eq(b.economy.snapshot().items.hint, 0)
	assert_true(ui.sheet.busy)
	assert_true(ui.sheet.handle_back())
	assert_true(ui.modal_open())
	assert_false(ui.watch_ad.disabled)
	assert_eq(ui.watch_ad.text_key, "level.tool.retry")
	disk.stop_at = &""
	ui.watch_ad.pressed.emit()
	assert_eq(b.economy.snapshot().items.hint, 1)
	assert_eq(ui.message.text, host.tr("level.hint.reward_added"))
	var shows: int = 0
	for entry: Dictionary in p.ads.calls.entries:
		if entry.method == "show_rewarded":
			shows += 1
	assert_eq(shows, 1)


func test_actual_shop_replaces_options_and_retains_purchase_busy_barrier() -> void:
	wallet(0, 0, 0)
	var p: Dictionary = provider()
	var host: LevelScreen = screen(p.service)
	await wait_process_frames(2)
	host.hint_button.pressed.emit()
	var ui: LevelPaidTools = host.paid_tools_ui
	var identity: int = ui.sheet.get_instance_id()
	ui.get_coins.pressed.emit()
	assert_eq(ui.sheet.get_instance_id(), identity)
	assert_eq(ui.sheet.title_key, "shop.sheet.title")
	assert_true(ui.sheet.coins_card.visible)
	ui.sheet.coins_card.action_requested.emit()
	assert_true(ui.sheet.busy)
	assert_false(ui.sheet.close())
	assert_eq(host.prepare_navigation(), ERR_BUSY)
	assert_true(p.store.settle(p.store.operation_token()))
	assert_false(ui.sheet.busy)


func test_manual_ad_busy_and_reward_survive_retained_screen_reentry() -> void:
	wallet(0, 0, 0)
	var p: Dictionary = provider(&"reward", false)
	var host: LevelScreen = screen(p.service)
	await wait_process_frames(2)
	host.hint_button.pressed.emit()
	var ui: LevelPaidTools = host.paid_tools_ui
	ui.watch_ad.pressed.emit()
	assert_true(ui.sheet.busy)
	assert_true(ui.watch_ad.loading)
	assert_eq(host.prepare_navigation(), ERR_BUSY)
	var parent: Node = host.get_parent()
	parent.remove_child(host)
	parent.add_child(host)
	await wait_process_frames(2)
	assert_true(ui.sheet.busy)
	assert_true(p.ads.settle(p.ads.operation_token()))
	assert_eq(b.economy.snapshot().items.hint, 1)
	assert_false(ui.sheet.busy)
	assert_eq(ui.message.text, host.tr("level.hint.reward_added"))


func test_native_twelve_case_options_geometry_touch_labels_and_scroll() -> void:
	wallet(0, 0, 0)
	for option: String in GalleryShell.OPTIONS:
		ProjectSettings.set_setting(GalleryShell.PSEUDO + option, GalleryShell.OPTIONS[option])
	TranslationServer.reload_pseudolocalization()
	for dimensions: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1440, 1920)]:
		for pseudo: bool in [false, true]:
			for hc: bool in [false, true]:
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
				host.hint_button.pressed.emit()
				await wait_process_frames(3)
				var ui: LevelPaidTools = host.paid_tools_ui
				assert_true(ui.modal_open())
				for action: ActionButton in [ui.watch_ad, ui.get_coins, ui.not_now]:
					assert_gte(action.size.y, float(Tokens.Touch.MIN_TARGET))
					assert_gte(action.size.x, action.get_combined_minimum_size().x)
					assert_false(action.text_key.is_empty())
					assert_true(
						Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(action.get_global_rect())
					)
				assert_true(ui.watch_ad.disabled)
				assert_eq(ui.watch_ad.badge, &"ad")
				assert_false(ui.message.text.is_empty())
				assert_gte(
					ui.message.size.y,
					float(ui.message.get_line_height() * ui.message.get_line_count())
				)
				ui.not_now.pressed.emit()
				await wait_process_frames(2)
				host.get_parent().free()


func test_normal_motion_feedback_blocks_second_tap_and_releases_on_retained_exit() -> void:
	Tokens.reduced_motion = false
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	host.hint_button.pressed.emit()
	host.hint_button.pressed.emit()
	assert_true(host.controller.paid_locked())
	assert_eq(b.economy.snapshot().coins, 400)
	var parent: Node = host.get_parent()
	parent.remove_child(host)
	parent.add_child(host)
	await wait_process_frames(3)
	assert_false(host.controller.paid_locked())
	assert_eq(host.controller.get_board().revealed_cells().size(), 1)
	assert_eq(b.economy.snapshot().coins, 400)


func test_foreign_provider_configuration_is_rejected_before_mount() -> void:
	var alternate: FIXTURE.ToolConfig = FIXTURE.ToolConfig.new()
	add_child_autofree(alternate)
	assert_eq(alternate.load(), OK)
	var service: MONETIZATION = MONETIZATION.new()
	add_child_autofree(service)
	service.initialize(FIXTURE.FixedClock.new())
	assert_eq(
		service.configure(b.save, alternate, b.bus, ConsentFake.new(), AdsFake.new(), false), OK
	)
	var host: LevelScreen = SCENE.instantiate()
	host.configure(b.save, b.content, 2, b.bus)
	assert_eq(host.configure_p2(b.economy, b.config), OK)
	assert_eq(host.configure_paid_tools(b.progress, b.port, service), ERR_INVALID_PARAMETER)
	host.free()
	assert_eq(b.economy.snapshot().coins, 500)


func test_ordinary_word_submission_preserves_existing_grid_cells_and_wallet() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(2)
	var cell: GridCell = host.board_view.cell_node(Vector2i.ZERO)
	var result: AttemptResult = host.controller.submit(PackedInt32Array([0, 1, 2]))
	assert_not_null(result)
	assert_eq(result.kind, AttemptResult.Kind.LEVEL)
	assert_same(host.board_view.cell_node(Vector2i.ZERO), cell)
	assert_eq(b.economy.snapshot().coins, 500)
	assert_true("DOM" in host.controller.get_board().found_words())


func test_owner_advancement_between_configuration_and_mount_cannot_enable_free_hint() -> void:
	var host: LevelScreen = SCENE.instantiate()
	host.configure(b.save, b.content, 2, b.bus)
	assert_eq(host.configure_p2(b.economy, b.config), OK)
	assert_eq(host.configure_paid_tools(b.progress, b.port), OK)
	var board: BoardState = BoardState.new(b.content.level_for_slot(2))
	assert_eq(b.progress.bind_board(board), OK)
	for index: int in board.get_level().word_count():
		for cell: Vector2i in board.get_level().word_cells(index):
			board.reveal_cell(cell)
	assert_eq(b.progress.complete_level(2), OK)
	var balance: int = b.economy.snapshot().coins
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1080, 1920)
	add_child_autofree(view)
	view.add_child(host)
	await wait_process_frames(2)
	assert_null(host.controller.get_board())
	assert_false(host.controller.hint())
	assert_eq(b.economy.snapshot().coins, balance)
	assert_true(host.wheel.is_locked())
	assert_eq(host.status_label.text, host.tr("level.tool.unavailable"))


func test_economy_config_replacement_before_mount_clears_the_paid_board() -> void:
	var host: LevelScreen = SCENE.instantiate()
	host.configure(b.save, b.content, 2, b.bus)
	assert_eq(host.configure_p2(b.economy, b.config), OK)
	assert_eq(host.configure_paid_tools(b.progress, b.port), OK)
	var replacement: FIXTURE.ToolConfig = FIXTURE.ToolConfig.new()
	add_child_autofree(replacement)
	assert_eq(replacement.load(), OK)
	replacement.hint_price = 101
	b.economy.configure(b.save, replacement, b.bus)
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1080, 1920)
	add_child_autofree(view)
	view.add_child(host)
	await wait_process_frames(2)
	assert_null(host.controller.get_board())
	assert_false(host.controller.hint())
	assert_ne(host.controller.use_paid_tool(&"hint").error, OK)
	assert_eq(b.economy.snapshot().coins, 500)
	assert_true(host.wheel.is_locked())
	assert_eq(host.status_label.text, host.tr("level.tool.unavailable"))


func test_redundant_hud_refresh_preserves_the_stock_hint_count_animation() -> void:
	Tokens.reduced_motion = false
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	var badge: Badge = host.hint_button.find_children("*", "Badge", true, false)[0]
	assert_eq(b.economy.grant(&"test", {"hint": 1}), OK)
	for tween: Tween in get_tree().get_processed_tweens():
		tween.custom_step(Tokens.dur(Tokens.Motion.FAST) / 4.0)
	var animated_scale: Vector2 = badge.scale
	assert_ne(animated_scale, Vector2.ONE)
	host.refresh_paid_hud()
	assert_eq(badge.scale, animated_scale)
	assert_eq(host.hint_button.count, 1)
