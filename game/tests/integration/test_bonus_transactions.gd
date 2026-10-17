# gdlint: disable=max-public-methods
extends GutTest

const FIXTURE: Script = preload("res://tests/integration/test_paid_tool_transactions.gd")
const SAVE: Script = preload("res://services/save.gd")
const PROGRESS: Script = preload("res://services/progress.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONTENT: Script = preload("res://services/content.gd")
const EVENTS: Script = preload("res://services/events.gd")
const PATH: String = "user://t0338-bonus.json"
const ROOT: String = FIXTURE.ROOT


class BonusConfig:
	extends "res://tests/integration/test_paid_tool_transactions.gd".ToolConfig
	var required: int = 10
	var bonus_slot: int = 2
	var payout: int = 100

	func get_int(key: StringName) -> int:
		if key == &"bonus.chest.words_required":
			return required
		if key == &"unlocks.bonus_meter_slot":
			return bonus_slot
		return payout if key == &"economy.reward.bonus_chest" else super.get_int(key)


var b: Dictionary
var board: BoardState


func before_each() -> void:
	clean()
	b = bundle()
	start_second()


func after_each() -> void:
	clean()


func clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func start_second() -> void:
	var first: BoardState = BoardState.new(b.content.level_for_slot(1))
	assert_eq(b.progress.bind_board(first), OK)
	fill(first)
	assert_eq(b.progress.complete_level(1), OK)
	board = BoardState.new(b.content.level_for_slot(2))
	assert_eq(b.progress.bind_board(board), OK)
	wallet(500, 0)


func wallet(coins: int, counter: int) -> void:
	var section: Dictionary = b.save.get_section(&"economy")
	section.coins = coins
	section.bonus_counter = counter
	section.items = {"hint": 0, "reveal": 0}
	section["keep"] = {"extension": true}
	assert_eq(b.save.set_section(&"economy", section), OK)
	assert_eq(b.save.flush(), OK)


func fill(value: BoardState) -> void:
	for index: int in value.get_level().word_count():
		for cell: Vector2i in value.get_level().word_cells(index):
			value.reveal_cell(cell)


func bonus() -> void:
	assert_eq(board.evaluate(PackedInt32Array([0, 3, 2])).kind, AttemptResult.Kind.BONUS)


func bundle(storage: SaveStorage = null, unlock: int = 2) -> Dictionary:
	var save: SAVE = SAVE.new()
	var progress: PROGRESS = PROGRESS.new()
	var economy: ECONOMY = ECONOMY.new()
	var content: CONTENT = CONTENT.new()
	var config: BonusConfig = BonusConfig.new()
	config.bonus_slot = unlock
	var bus: EVENTS = EVENTS.new()
	for node: Node in [save, progress, economy, content, config, bus]:
		add_child_autofree(node)
	save.initialize(FIXTURE.FixedClock.new())
	economy.initialize(FIXTURE.FixedClock.new())
	progress.initialize(FIXTURE.FixedClock.new())
	var disk: SaveStorage = storage if storage != null else FIXTURE.InterruptedStorage.new(PATH)
	save.configure(disk, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert_eq(config.load(), OK)
	assert_eq(content.load_manifest("pl", ROOT), OK)
	progress.configure(save, content)
	assert_eq(progress.configure_atomic(config), OK)
	economy.configure(save, config, bus)
	var port: AtomicProgressPort = AtomicProgressPort.new()
	assert_eq(port.configure(save, progress, economy), OK)
	assert_eq(save.load(), OK)
	assert_eq(progress.configure_p2(config, port, bus), OK)
	assert_eq(progress.configure_bonus_progress(), OK)
	return {
		"save": save,
		"progress": progress,
		"economy": economy,
		"content": content,
		"config": config,
		"bus": bus,
		"port": port,
		"storage": disk
	}


func test_checkpoint_and_bonus_credit_commit_together_without_mid_level_redemption() -> void:
	wallet(500, 9)
	watch_signals(b.economy)
	bonus()
	var request: Dictionary = b.progress.checkpoint_request(board)
	assert_true(AtomicRequest.valid(request))
	assert_eq(request.kind, "campaign_checkpoint")
	var result: Dictionary = b.port.transact(request)
	assert_eq(result.error, OK)
	assert_eq(b.economy.snapshot().bonus_counter, 10)
	assert_eq(b.economy.snapshot().coins, 500)
	assert_eq(b.progress.current_slot(), 2)
	assert_true("DAM" in b.progress.restore_level(board.get_level()).bonus_words())
	assert_signal_emit_count(b.economy, "bonus_chest_redeemed", 0)
	assert_eq(b.port.transact(request).state, "replayed")
	assert_eq(b.economy.snapshot().bonus_counter, 10)
	var revision: int = b.save.committed_view().revision
	assert_eq(b.progress.save_level(board), OK)
	assert_eq(b.save.committed_view().revision, revision)
	assert_eq(b.save.get_section(&"economy").keep, {"extension": true})


func test_noop_fresh_board_does_not_write_and_partial_level_word_remains_uncredited() -> void:
	var revision: int = b.save.committed_view().revision
	assert_eq(b.progress.save_level(board), OK)
	assert_eq(b.save.committed_view().revision, revision)
	assert_eq(board.evaluate(PackedInt32Array([0, 1, 2])).kind, AttemptResult.Kind.LEVEL)
	assert_eq(b.progress.save_level(board), OK)
	assert_eq(b.economy.snapshot().bonus_counter, 0)
	assert_true("DOM" in b.progress.restore_level(board.get_level()).found_words())


func test_locked_bonus_words_are_saved_without_credit() -> void:
	clean()
	b = bundle(null, 3)
	start_second()
	bonus()
	assert_eq(b.progress.save_level(board), OK)
	assert_eq(b.economy.snapshot().bonus_counter, 0)
	assert_true("DAM" in b.progress.restore_level(board.get_level()).bonus_words())


func test_all_five_checkpoint_write_gaps_restart_and_retry_credit_once() -> void:
	for gap: StringName in [
		&"temp_opened", &"temp_written", &"temp_flushed", &"backup_rotated", &"primary_promoted"
	]:
		clean()
		var disk: FIXTURE.InterruptedStorage = FIXTURE.InterruptedStorage.new(PATH)
		b = bundle(disk)
		start_second()
		wallet(500, 9)
		bonus()
		var request: Dictionary = b.progress.checkpoint_request(board)
		disk.stop_at = gap
		var result: Dictionary = b.port.transact(request)
		assert_true(result.state in ["pending", "replayed"])
		disk.stop_at = &""
		var restarted: Dictionary = bundle()
		var restored: BoardState = restarted.progress.restore_level(
			restarted.content.level_for_slot(2)
		)
		assert_eq(
			restarted.economy.snapshot().bonus_counter, 10 if "DAM" in restored.bonus_words() else 9
		)
		if "DAM" not in restored.bonus_words():
			assert_eq(restarted.progress.bind_board(restored), OK)
			restored.evaluate(PackedInt32Array([0, 3, 2]))
			assert_eq(restarted.progress.save_level(restored), OK)
		assert_eq(restarted.economy.snapshot().bonus_counter, 10)
		assert_eq(
			(
				restarted
				. port
				. recover(request.operation_id, {"request_hash": AtomicRequest.hash_value(request)})
				. error
			),
			OK
		)
		assert_eq(restarted.economy.snapshot().coins, 500)


func test_completion_redeems_all_groups_and_keeps_surplus_once() -> void:
	wallet(500, 25)
	watch_signals(b.economy)
	fill(board)
	assert_eq(b.progress.complete_level(2), OK)
	assert_eq(b.economy.snapshot().bonus_counter, 5)
	assert_eq(b.economy.snapshot().coins, 700 + b.config.get_int(&"economy.reward.level_complete"))
	assert_signal_emitted_with_parameters(b.economy, "bonus_chest_redeemed", [2, 200])
	assert_eq(b.progress.complete_level(2), OK)
	assert_signal_emit_count(b.economy, "bonus_chest_redeemed", 1)
	var restarted: Dictionary = bundle()
	assert_eq(restarted.economy.snapshot().bonus_counter, 5)
	assert_eq(restarted.economy.snapshot().coins, b.economy.snapshot().coins)


func test_zero_reward_still_consumes_chests_and_notifies_live_presentation() -> void:
	b.config.payout = 0
	wallet(500, 20)
	watch_signals(b.economy)
	fill(board)
	assert_eq(b.progress.complete_level(2), OK)
	assert_eq(b.economy.snapshot().bonus_counter, 0)
	assert_eq(b.economy.snapshot().coins, 500 + b.config.get_int(&"economy.reward.level_complete"))
	assert_signal_emitted_with_parameters(b.economy, "bonus_chest_redeemed", [2, 0])


func test_all_five_completion_gaps_and_restart_cannot_repeat_chest_payout() -> void:
	for gap: StringName in [
		&"temp_opened", &"temp_written", &"temp_flushed", &"backup_rotated", &"primary_promoted"
	]:
		clean()
		var disk: FIXTURE.InterruptedStorage = FIXTURE.InterruptedStorage.new(PATH)
		b = bundle(disk)
		start_second()
		wallet(500, 20)
		fill(board)
		var request: Dictionary = b.progress.completion_request(b.port.completion_commands("pl", 2))
		disk.stop_at = gap
		var result: Dictionary = b.port.transact(request)
		assert_true(result.state in ["pending", "replayed"])
		disk.stop_at = &""
		var restarted: Dictionary = bundle()
		if restarted.progress.current_slot() == 2:
			assert_eq(restarted.economy.snapshot().bonus_counter, 20)
			var restored: BoardState = restarted.progress.restore_level(
				restarted.content.level_for_slot(2)
			)
			assert_eq(restarted.progress.bind_board(restored), OK)
			fill(restored)
			assert_eq(restarted.progress.complete_level(2), OK)
		watch_signals(restarted.economy)
		assert_eq(
			(
				restarted
				. port
				. recover(request.operation_id, {"request_hash": AtomicRequest.hash_value(request)})
				. error
			),
			OK
		)
		assert_eq(restarted.economy.snapshot().bonus_counter, 0)
		assert_eq(
			restarted.economy.snapshot().coins,
			700 + b.config.get_int(&"economy.reward.level_complete")
		)
		assert_signal_emit_count(restarted.economy, "bonus_chest_redeemed", 0)


func test_paid_final_cell_debit_completion_and_chest_form_one_candidate() -> void:
	wallet(500, 10)
	var level: LevelData = board.get_level()
	var last: Vector2i = level.word_cells(1)[-1]
	for index: int in level.word_count():
		for cell: Vector2i in level.word_cells(index):
			if cell != last:
				board.reveal_cell(cell)
	assert_eq(b.progress.save_level(board), OK)
	var request: Dictionary = b.progress.paid_tool_request(
		board, &"hint", b.port.tool_commands(&"hint", true)
	)
	watch_signals(b.economy)
	var disk: FIXTURE.InterruptedStorage = b.storage
	disk.stop_at = &"temp_opened"
	assert_ne(b.port.transact(request).error, OK)
	assert_eq(b.economy.snapshot().coins, 500)
	assert_eq(b.economy.snapshot().bonus_counter, 10)
	disk.stop_at = &""
	assert_eq(b.port.transact(request).error, OK)
	assert_eq(b.economy.snapshot().coins, 500 + b.config.get_int(&"economy.reward.level_complete"))
	assert_eq(b.economy.snapshot().bonus_counter, 0)
	assert_eq(b.progress.current_slot(), 3)
	assert_eq(b.port.transact(request).state, "replayed")
	assert_signal_emit_count(b.economy, "bonus_chest_redeemed", 1)


func test_issued_target_and_reward_survive_failed_completion_write() -> void:
	wallet(500, 20)
	fill(board)
	var disk: FIXTURE.InterruptedStorage = b.storage
	disk.stop_at = &"temp_opened"
	assert_ne(b.progress.complete_level(2), OK)
	b.config.required = 3
	b.config.payout = 77
	disk.stop_at = &""
	assert_eq(b.progress.complete_level(2), OK)
	assert_eq(b.economy.snapshot().bonus_counter, 0)
	assert_eq(b.economy.snapshot().coins, 700 + b.config.get_int(&"economy.reward.level_complete"))
	wallet(500, 10)
	board = BoardState.new(b.content.level_for_slot(3))
	assert_eq(b.progress.bind_board(board), OK)
	fill(board)
	assert_eq(b.progress.complete_level(3), OK)
	assert_eq(b.economy.snapshot().bonus_counter, 1)
	assert_eq(b.economy.snapshot().coins, 731 + b.config.get_int(&"economy.reward.level_complete"))


func test_foreign_forged_backward_and_new_historical_credit_requests_are_rejected() -> void:
	var foreign: BoardState = BoardState.new(board.get_level())
	foreign.evaluate(PackedInt32Array([0, 3, 2]))
	assert_true(b.progress.checkpoint_request(foreign).is_empty())
	bonus()
	var request: Dictionary = b.progress.checkpoint_request(board)
	var forged: Dictionary = request.duplicate(true)
	forged.economy_commands = [
		{"operation": "grant", "reason": "bonus_chest", "amounts": {"coins": 100}}
	]
	assert_false(AtomicRequest.valid(forged))
	assert_eq(b.port.transact(forged).state, "rejected")
	assert_eq(b.port.transact(request).error, OK)
	var old: BoardState = BoardState.new(board.get_level())
	assert_eq(b.progress.bind_board(old), OK)
	assert_true(b.progress.checkpoint_request(old).is_empty())
	var after: Dictionary = board.to_dict()
	after.bonus_words.append("MAD")
	var historical: BoardState = BoardState.from_dict(board.get_level(), after, true)
	assert_not_null(historical)
	assert_eq(b.progress.bind_board(historical), OK)
	assert_true(b.progress.checkpoint_request(historical).is_empty())
	assert_eq(b.economy.snapshot().bonus_counter, 1)


func test_existing_historical_credit_is_preserved_and_not_counted_again() -> void:
	var state: Dictionary = b.save.get_section(&"progress")
	var snapshot: Dictionary = board.to_dict()
	snapshot.bonus_words = ["MAD"]
	state.by_lang.pl.level_state = snapshot
	assert_eq(b.save.set_section(&"progress", state), OK)
	assert_eq(b.save.flush(), OK)
	board = b.progress.restore_level(board.get_level())
	assert_true("MAD" in board.bonus_words())
	assert_eq(b.progress.bind_board(board), OK)
	bonus()
	assert_eq(b.progress.save_level(board), OK)
	assert_eq(b.economy.snapshot().bonus_counter, 1)
	assert_true("MAD" in b.progress.restore_level(board.get_level()).bonus_words())


func test_counter_and_wallet_overflow_fail_without_partial_publication() -> void:
	wallet(500, WalletSnapshot.MAX_SAFE_COUNT)
	bonus()
	assert_ne(b.progress.save_level(board), OK)
	assert_eq(b.economy.snapshot().bonus_counter, WalletSnapshot.MAX_SAFE_COUNT)
	assert_false(b.save.writes_blocked())
	assert_false("DAM" in b.progress.restore_level(board.get_level()).bonus_words())
	wallet(WalletSnapshot.MAX_SAFE_COUNT, 10)
	fill(board)
	watch_signals(b.economy)
	assert_ne(b.progress.complete_level(2), OK)
	assert_eq(b.progress.current_slot(), 2)
	assert_eq(b.economy.snapshot().bonus_counter, 10)
	assert_eq(b.economy.snapshot().coins, WalletSnapshot.MAX_SAFE_COUNT)
	assert_signal_emit_count(b.economy, "bonus_chest_redeemed", 0)


func test_mutated_board_at_final_write_boundary_rejects_without_bonus_credit() -> void:
	bonus()
	var request: Dictionary = b.progress.checkpoint_request(board)
	var disk: FIXTURE.InterruptedStorage = b.storage
	disk.on_read = func() -> void: board.evaluate(PackedInt32Array([1, 0, 3]))
	assert_eq(b.port.transact(request).state, "rejected")
	assert_eq(b.economy.snapshot().bonus_counter, 0)
	assert_false(b.save.writes_blocked())
	assert_true(b.progress.restore_level(board.get_level()).bonus_words().is_empty())
