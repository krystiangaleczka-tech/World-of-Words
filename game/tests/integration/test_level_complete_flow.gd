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
const PATH: String = "user://t0281-ui-save.json"


class CompleteConfig:
	extends "res://tests/integration/test_bonus_transactions.gd".BonusConfig
	var double_slot: int = 2
	var multiple: int = 2
	var journey_slot: int = 6
	var legal_slot: int = 6
	var ad_slot: int = 16
	var piece_cost: int = 12
	var reward_enabled: bool = true
	var base_reward: int = 25

	func get_int(key: StringName) -> int:
		var values: Dictionary = {
			&"meta.postcard.piece_star_cost": piece_cost,
			&"unlocks.journey_slot": journey_slot,
			&"consent.ump_after_slot": legal_slot,
			&"consent.att_after_slot": legal_slot,
			&"ads.interstitial.first_slot": ad_slot,
			&"ads.interstitial.session_grace_seconds": 0,
			&"unlocks.double_reward_slot": double_slot,
			&"economy.reward.level_complete": base_reward,
			&"economy.reward.double_multiplier": multiple
		}
		return int(values[key]) if values.has(key) else super.get_int(key)

	func get_bool(key: StringName) -> bool:
		return reward_enabled if key == &"ads.rewarded.double.enabled" else super.get_bool(key)


var b: Dictionary
var disk: FIXTURE.InterruptedStorage
var _motion: bool
var _locale: String
var _pseudo: bool
var _low_mode: bool
var _route_nodes: Array[Node] = []


func before_each() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	_low_mode = OS.low_processor_usage_mode
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
	var config: CompleteConfig = CompleteConfig.new()
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
	for node: Node in _route_nodes:
		if is_instance_valid(node):
			node.free()
	_route_nodes.clear()
	OS.low_processor_usage_mode = _low_mode
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


func screen(
	service: Node = null,
	dimensions: Vector2i = Vector2i(1080, 1920),
	nav: Node = null,
	slot: int = 2
) -> LevelScreen:
	var view: SubViewport = SubViewport.new()
	view.size = dimensions
	add_child_autofree(view)
	var host: LevelScreen = SCENE.instantiate()
	host.configure(b.save, b.content, slot, b.bus)
	if nav != null:
		host.configure_navigation(nav)
	assert_eq(host.configure_p2(b.economy, b.config), OK)
	assert_eq(host.configure_paid_tools(b.progress, b.port, service), OK)
	assert_eq(host.configure_bonus_meter(), OK)
	assert_eq(host.configure_completion(service), OK)
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


func provider(outcome: StringName = &"reward", immediate: bool = true) -> Dictionary:
	var service: MONETIZATION = MONETIZATION.new()
	add_child_autofree(service)
	service.initialize(FIXTURE.FixedClock.new())
	var consent: ConsentFake = ConsentFake.new()
	consent.set_outcome(&"request_info", &"not_required")
	var ads: AdsFake = AdsFake.new()
	ads.set_outcome(&"initialize", &"ready")
	ads.set_outcome(&"load_rewarded", &"ready")
	ads.set_outcome(&"load_interstitial", &"ready")
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


func test_actual_receipt_rewards_exclude_multiple_chests_and_postcard_is_committed() -> void:
	counter(25)
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	complete(host)
	await wait_process_frames(5)
	assert_eq(host.complete_ui.stars.value, 1)
	assert_eq(host.complete_ui.coins.value, b.config.get_int(&"economy.reward.level_complete"))
	assert_eq(b.economy.snapshot().coins, 700 + host.complete_ui.coins.value)
	assert_true(host.bonus_ui.summary.visible)
	assert_false(host.complete_ui.postcard.visible, "Fixture has no image")
	var pieces: int = b.save.committed_view().sections.progress.by_lang.pl.location_pieces.get(
		"one", 0
	)
	assert_eq(
		host.complete_ui.progress_bar.value,
		float(pieces) / b.config.get_int(&"meta.postcard.pieces")
	)
	assert_true(host.complete_ui.credits.text.contains(str(pieces)))
	assert_true(host.complete_ui.message.visible)
	assert_true(host.complete_ui.double_button.disabled)


func test_paid_final_completion_uses_same_receipt_rewards() -> void:
	wallet(500, 0, 1)
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	host.wheel.word_attempted.emit(PackedInt32Array([0, 1, 2]))
	host.p2_hud.reveal.activated.emit(&"reveal")
	await wait_process_frames(5)
	assert_true(host.completion_layer.visible)
	assert_eq(host.complete_ui.stars.value, 1)
	assert_eq(host.complete_ui.coins.value, b.config.get_int(&"economy.reward.level_complete"))


func test_success_doubles_only_base_once_even_with_remove_forced_ads_and_chest() -> void:
	counter(10)
	var provider_bundle: Dictionary = provider()
	assert_eq(b.economy.grant_purchase("fixture-remove-ads", "nc.remove_forced_ads.v1"), OK)
	var host: LevelScreen = screen(provider_bundle.service)
	await wait_process_frames(3)
	complete(host)
	await wait_process_frames(5)
	var base: int = host.complete_ui.coins.value
	host.complete_ui.double_button.pressed.emit()
	host.complete_ui.double_button.pressed.emit()
	await wait_process_frames(3)
	assert_eq(host.complete_ui.coins.value, base * 2)
	assert_eq(b.economy.snapshot().coins, 600 + base * 2)
	assert_false(host.complete_ui.double_button.visible)
	host.complete_ui.double_button.pressed.emit()
	provider_bundle.ads.reward_earned.emit()
	await wait_process_frames(2)
	assert_eq(b.economy.snapshot().coins, 600 + base * 2)
	assert_false(host.continue_button.disabled)


func test_pending_earned_write_retries_without_another_ad_and_blocks_continue() -> void:
	var p: Dictionary = provider()
	var host: LevelScreen = screen(p.service)
	await wait_process_frames(3)
	complete(host)
	await wait_process_frames(5)
	var before: int = b.economy.snapshot().coins
	disk.stop_at = &"temp_opened"
	host.complete_ui.double_button.pressed.emit()
	await wait_process_frames(3)
	assert_eq(p.service.rewarded_state(), &"pending_reward")
	assert_eq(b.economy.snapshot().coins, before)
	assert_true(host.continue_button.disabled)
	assert_eq(host.prepare_navigation(), ERR_BUSY)
	assert_false(host.complete_ui.double_button.disabled)
	var calls: int = p.ads.calls.entries.size()
	disk.stop_at = &""
	host.complete_ui.double_button.pressed.emit()
	await wait_process_frames(3)
	assert_eq(
		b.economy.snapshot().coins, before + b.config.get_int(&"economy.reward.level_complete")
	)
	assert_eq(p.ads.calls.entries.size(), calls)
	assert_false(host.complete_ui.double_button.visible)
	assert_false(host.continue_button.disabled)


func test_no_fill_never_grants_and_releases_continue() -> void:
	await assert_no_reward(&"no_fill")


func test_early_close_never_grants_and_releases_continue() -> void:
	await assert_no_reward(&"early_close")


func assert_no_reward(outcome: StringName) -> void:
	var p: Dictionary = provider(outcome)
	var host: LevelScreen = screen(p.service)
	await wait_process_frames(3)
	complete(host)
	await wait_process_frames(5)
	var before: int = b.economy.snapshot().coins
	host.complete_ui.double_button.pressed.emit()
	await wait_process_frames(3)
	assert_eq(b.economy.snapshot().coins, before)
	assert_true(host.complete_ui.double_button.visible)
	assert_true(host.complete_ui.message.visible)
	assert_false(host.continue_button.disabled)


func test_unlock_and_zero_or_disabled_multiplier_hide_offer() -> void:
	b.config.double_slot = 12
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	complete(host)
	await wait_process_frames(5)
	assert_false(host.complete_ui.double_button.visible)
	host.complete_ui.double_button.pressed.emit()
	assert_eq(b.economy.snapshot().coins, 500 + host.complete_ui.coins.value)


func test_retained_reentry_preserves_reward_and_does_not_replay_count_up() -> void:
	var p: Dictionary = provider()
	var host: LevelScreen = screen(p.service)
	await wait_process_frames(3)
	complete(host)
	await wait_process_frames(5)
	host.complete_ui.double_button.pressed.emit()
	await wait_process_frames(3)
	var before: Dictionary = b.save.committed_view()
	var parent: Node = host.get_parent()
	parent.remove_child(host)
	parent.add_child(host)
	await wait_process_frames(3)
	assert_false(host.complete_ui.double_button.visible)
	assert_false(host.complete_ui.coins.counting)
	assert_eq_deep(b.save.committed_view(), before)
	var again: LevelScreen = SCENE.instantiate()
	again.configure(b.save, b.content, 2, b.bus)
	assert_eq(again.configure_p2(b.economy, b.config), OK)
	assert_eq(again.configure_paid_tools(b.progress, b.port, p.service), ERR_INVALID_PARAMETER)
	again.free()


func test_normal_motion_count_up_and_exit_cleanup() -> void:
	Tokens.reduced_motion = false
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	complete(host)
	host.board_view.wave_finished.emit()
	await wait_process_frames(3)
	assert_true(host.complete_ui.coins.counting)
	assert_eq(host.complete_ui.coins.value, b.config.get_int(&"economy.reward.level_complete"))
	var parent: Node = host.get_parent()
	parent.remove_child(host)
	assert_false(host.complete_ui.coins.counting)
	parent.add_child(host)
	await wait_process_frames(3)
	assert_false(host.complete_ui.coins.counting)


func test_foreign_or_late_opt_ins_are_rejected() -> void:
	var host: LevelScreen = SCENE.instantiate()
	host.configure(b.save, b.content, 2, b.bus)
	assert_eq(host.configure_completion(), ERR_UNCONFIGURED)
	assert_eq(host.configure_p2(b.economy, b.config), OK)
	assert_eq(host.configure_paid_tools(b.progress, b.port), OK)
	assert_eq(host.configure_bonus_meter(), OK)
	var foreign: MONETIZATION = MONETIZATION.new()
	add_child_autofree(foreign)
	assert_eq(host.configure_completion(foreign), ERR_INVALID_PARAMETER)
	assert_eq(host.configure_completion(), OK)
	assert_eq(host.configure_completion(), ERR_BUSY)
	host.free()


class RouteScreen:
	extends Control
	var error: Error = OK

	func prepare_navigation() -> Error:
		return error


func navigation(service: Node) -> Node:
	var nav: Node = load("res://services/nav.gd").new()
	var holder: Control = Control.new()
	add_child(nav)
	add_child(holder)
	_route_nodes.append(holder)
	_route_nodes.append(nav)
	nav.initialize(FIXTURE.FixedClock.new())
	nav.configure(b.save, b.config, b.content)
	assert_eq(nav.configure_p2(Callable(), false), OK)
	nav.configure_screens(func(_kind: int) -> Node: return RouteScreen.new())
	assert_eq(nav.start(holder, FIXTURE.ROOT), OK)
	assert_eq(nav.go_to_level(2), OK)
	assert_eq(nav.configure_campaign_continue(service, b.economy), OK)
	return nav


func complete_bound() -> void:
	var board: BoardState = BoardState.new(b.content.level_for_slot(2))
	assert_eq(b.progress.bind_board(board), OK)
	for index: int in board.get_level().word_count():
		for cell: Vector2i in board.get_level().word_cells(index):
			board.reveal_cell(cell)
	assert_eq(b.progress.complete_level(2), OK)


func test_continue_uses_synchronous_service_callback_once_and_rejects_invalid_intents() -> void:
	var p: Dictionary = provider()
	var nav: Node = navigation(p.service)
	assert_eq(nav.continue_campaign(2, 0), ERR_UNAVAILABLE)
	assert_eq(nav.continue_campaign(1, 0), ERR_INVALID_PARAMETER)
	complete_bound()
	watch_signals(nav)
	assert_eq(nav.continue_campaign(2, 0), OK)
	assert_eq(nav.level_slot(), 3)
	assert_signal_emit_count(nav, "screen_changed", 1)
	p.service.continuation_ready.emit(2)
	p.service.continuation_ready.emit(1)
	assert_signal_emit_count(nav, "screen_changed", 1)

	await wait_process_frames(2)


func manual_provider() -> Dictionary:
	var service: MONETIZATION = MONETIZATION.new()
	add_child_autofree(service)
	service.initialize(FIXTURE.FixedClock.new())
	var consent: ConsentFake = ConsentFake.new()
	consent.set_outcome(&"request_info", &"not_required", false)
	var ads: AdsFake = AdsFake.new()
	ads.set_outcome(&"initialize", &"ready")
	assert_eq(service.configure(b.save, b.config, b.bus, consent, ads, false), OK)
	return {"service": service, "consent": consent, "ads": ads}


func test_async_continue_blocks_back_and_duplicate_press_until_provider_finishes() -> void:
	var p: Dictionary = manual_provider()
	var nav: Node = navigation(p.service)
	complete_bound()
	watch_signals(nav)
	assert_eq(nav.continue_campaign(2, 0), OK)
	assert_eq(nav.level_slot(), 2)
	assert_eq(nav.continue_campaign(2, 0), ERR_BUSY)
	assert_eq(nav.handle_back(), ERR_BUSY)
	assert_eq(nav.go_to_level(3), ERR_BUSY)
	assert_eq(nav.configure_campaign_continue(p.service, b.economy), ERR_BUSY)
	p.service.continuation_ready.emit(1)
	assert_eq(nav.level_slot(), 2)
	assert_true(p.consent.settle(p.consent.operation_token()))
	assert_eq(nav.level_slot(), 3)
	assert_signal_emit_count(nav, "screen_changed", 1)

	await wait_process_frames(2)


func test_async_route_failure_can_retry_and_watchdog_releases_navigation() -> void:
	var p: Dictionary = manual_provider()
	var nav: Node = navigation(p.service)
	complete_bound()
	watch_signals(nav)
	assert_eq(nav.continue_campaign(2, 0), OK)
	nav.mounted_screen().error = ERR_CANT_OPEN
	assert_true(p.consent.settle(p.consent.operation_token()))
	assert_signal_emitted_with_parameters(nav, "campaign_continue_failed", [ERR_CANT_OPEN])
	assert_eq(nav.level_slot(), 2)
	nav.mounted_screen().error = OK
	assert_eq(nav.continue_campaign(2, 0), OK)
	assert_eq(nav.level_slot(), 3)

	await wait_process_frames(2)


func test_pending_continue_host_exit_discards_old_callback() -> void:
	var p: Dictionary = manual_provider()
	var nav: Node = navigation(p.service)
	complete_bound()
	assert_eq(nav.continue_campaign(2, 0), OK)
	nav.mounted_screen().get_parent().free()
	assert_true(p.consent.settle(p.consent.operation_token()))
	assert_eq(nav.level_slot(), 2)
	assert_eq(nav.go_to_level(3), ERR_UNCONFIGURED)


func test_watchdog_releases_pending_continue_and_foreign_binding_is_rejected() -> void:
	var p: Dictionary = manual_provider()
	var nav: Node = navigation(p.service)
	var foreign: MONETIZATION = MONETIZATION.new()
	add_child_autofree(foreign)
	assert_eq(nav.configure_campaign_continue(foreign, b.economy), ERR_INVALID_PARAMETER)
	complete_bound()
	assert_eq(nav.continue_campaign(2, 0), OK)
	p.service.expire_operation()
	assert_eq(nav.level_slot(), 3)

	await wait_process_frames(2)


func test_real_screen_continue_calls_nav_and_async_failure_reenables_button() -> void:
	var p: Dictionary = manual_provider()
	var nav: Node = navigation(p.service)
	var host: LevelScreen = screen(p.service, Vector2i(1080, 1920), nav)
	await wait_process_frames(3)
	complete(host)
	await wait_process_frames(5)
	host.continue_button.pressed.emit()
	host.continue_button.pressed.emit()
	assert_true(host.continue_button.disabled)
	assert_eq(nav.level_slot(), 2)
	nav.mounted_screen().error = ERR_CANT_OPEN
	assert_true(p.consent.settle(p.consent.operation_token()))
	assert_false(host.continue_button.disabled)
	nav.mounted_screen().error = OK
	host.continue_button.pressed.emit()
	assert_eq(nav.level_slot(), 3)
	await wait_process_frames(2)


func test_continue_waits_for_legal_form_and_att_before_routing() -> void:
	b.config.legal_slot = 2
	var service: MONETIZATION = MONETIZATION.new()
	add_child_autofree(service)
	service.initialize(FIXTURE.FixedClock.new())
	var consent: ConsentFake = ConsentFake.new()
	consent.set_outcome(&"request_info", &"required")
	consent.set_outcome(&"show_form_if_required", &"obtained", false)
	consent.set_outcome(&"request_att", &"denied", false)
	var ads: AdsFake = AdsFake.new()
	ads.set_outcome(&"initialize", &"ready")
	assert_eq(service.configure(b.save, b.config, b.bus, consent, ads, true), OK)
	var nav: Node = navigation(service)
	complete_bound()
	assert_eq(nav.continue_campaign(2, 0), OK)
	assert_eq(consent.calls.entries.back().method, "show_form_if_required")
	assert_eq(nav.level_slot(), 2)
	assert_true(consent.settle(consent.operation_token()))
	assert_eq(consent.calls.entries.back().method, "request_att")
	assert_eq(nav.level_slot(), 2)
	assert_eq(ads.calls.entries.size(), 0)
	assert_true(consent.settle(consent.operation_token()))
	assert_eq(ads.calls.entries.front().method, "initialize")
	assert_eq(nav.level_slot(), 3)
	await wait_process_frames(2)


func test_continue_waits_for_eligible_interstitial_close() -> void:
	b.config.ad_slot = 2
	b.config.legal_slot = 2
	var p: Dictionary = provider()
	# The warm-up Continue initialized the SDK and preloaded an interstitial.
	p.ads.set_outcome(&"show_interstitial", &"shown", false)
	var nav: Node = navigation(p.service)
	complete_bound()
	assert_eq(nav.continue_campaign(2, 0), OK)
	assert_eq(p.ads.calls.entries.back().method, "show_interstitial")
	assert_eq(nav.level_slot(), 2)
	assert_eq(nav.handle_back(), ERR_BUSY)
	assert_true(p.ads.settle(p.ads.operation_token()))
	assert_eq(nav.level_slot(), 3)
	await wait_process_frames(2)


func test_new_committed_postcard_credit_routes_before_next_level() -> void:
	b.config.journey_slot = 2
	var p: Dictionary = provider()
	var nav: Node = navigation(p.service)
	var before: int = nav.postcard_piece_count(2)
	b.config.piece_cost = 2
	complete_bound()
	assert_gt(nav.postcard_piece_count(2), before)
	assert_eq(nav.continue_campaign(2, before), OK)
	assert_eq(nav.current_screen(), nav.Screen.POSTCARD)
	await wait_process_frames(2)


func test_zero_base_hides_offer() -> void:
	b.config.base_reward = 0
	await assert_hidden_offer()


func test_multiplier_one_hides_offer() -> void:
	b.config.multiple = 1
	await assert_hidden_offer()


func test_disabled_reward_hides_offer() -> void:
	b.config.reward_enabled = false
	await assert_hidden_offer()


func assert_hidden_offer() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	complete(host)
	await wait_process_frames(5)
	assert_false(host.complete_ui.double_button.visible)
	assert_eq(host.complete_ui.stars.value, 1)
	var before: Dictionary = b.save.committed_view()
	host.complete_ui.double_button.pressed.emit()
	assert_eq_deep(b.save.committed_view(), before)


func test_terminal_completion_can_claim_x2_while_continue_is_disabled() -> void:
	complete_bound()
	var p: Dictionary = provider()
	var host: LevelScreen = screen(p.service, Vector2i(1080, 1920), null, 3)
	await wait_process_frames(3)
	host.wheel.word_attempted.emit(PackedInt32Array([0, 1, 2, 3, 4]))
	host.wheel.word_attempted.emit(PackedInt32Array([2, 1, 0, 4]))
	await wait_process_frames(5)
	assert_true(host.completion_layer.visible)
	assert_true(host.continue_button.disabled)
	assert_true(host.complete_ui.double_button.visible)
	host.complete_ui.double_button.pressed.emit()
	await wait_process_frames(3)
	assert_false(host.complete_ui.double_button.visible)
	assert_eq(host.complete_ui.coins.value, b.config.get_int(&"economy.reward.level_complete") * 2)
	assert_true(host.continue_button.disabled)


func test_postcard_group_is_hidden_before_journey_unlock() -> void:
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	complete(host)
	await wait_process_frames(5)
	assert_false(host.complete_ui.postcard.is_visible_in_tree())
	assert_false(host.complete_ui.progress_bar.is_visible_in_tree())
	assert_false(host.complete_ui.credits.is_visible_in_tree())


func test_postcard_group_is_visible_at_journey_unlock_with_missing_art_caption() -> void:
	b.config.journey_slot = 2
	var host: LevelScreen = screen()
	await wait_process_frames(3)
	complete(host)
	await wait_process_frames(5)
	assert_true(host.complete_ui.progress_bar.is_visible_in_tree())
	assert_true(host.complete_ui.credits.is_visible_in_tree())
	assert_true(host.complete_ui.credits.text.contains(host.tr("journey.location.missing_art")))
