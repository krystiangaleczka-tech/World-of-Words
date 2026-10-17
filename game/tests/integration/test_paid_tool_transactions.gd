# gdlint: disable=max-public-methods
extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const PROGRESS: Script = preload("res://services/progress.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONTENT: Script = preload("res://services/content.gd")
const EVENTS: Script = preload("res://services/events.gd")
const PATH: String = "user://t0336-paid-tools.json"
const ROOT: String = "res://tests/fixtures/paid_tools"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class ToolConfig:
	extends "res://services/config.gd"
	var hint_price: int = 100

	func get_int(key: StringName) -> int:
		if key in [&"unlocks.hint_slot", &"unlocks.reveal_slot"]:
			return 2
		return hint_price if key == &"economy.price.hint" else super.get_int(key)


class InterruptedStorage:
	extends SaveStorage
	var stop_at: StringName = &""
	var on_read: Callable

	func checkpoint(step: StringName) -> Error:
		return ERR_FILE_CANT_WRITE if step == stop_at else OK

	func read_document(suffix: String = "") -> Dictionary:
		if on_read.is_valid():
			var callback: Callable = on_read
			on_read = Callable()
			callback.call()
		return super.read_document(suffix)


var b: Dictionary
var board: BoardState


func before_each() -> void:
	_clean()
	b = bundle()
	board = BoardState.new(b.content.level_for_slot(1))
	assert_eq(b.progress.bind_board(board), OK)
	assert_true(request(board, &"hint").is_empty(), "Slot 1 is locked")
	for index: int in board.get_level().word_count():
		for cell: Vector2i in board.get_level().word_cells(index):
			board.reveal_cell(cell)
	assert_eq(b.progress.complete_level(1), OK)
	board = BoardState.new(b.content.level_for_slot(2))
	assert_eq(b.progress.bind_board(board), OK)
	wallet(500, 0, 0)


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func bundle(storage: SaveStorage = null) -> Dictionary:
	var save: SAVE = SAVE.new()
	var progress: PROGRESS = PROGRESS.new()
	var economy: ECONOMY = ECONOMY.new()
	var content: CONTENT = CONTENT.new()
	var config: ToolConfig = ToolConfig.new()
	var bus: EVENTS = EVENTS.new()
	for node: Node in [save, progress, economy, content, config, bus]:
		add_child_autofree(node)
	save.initialize(FixedClock.new())
	economy.initialize(FixedClock.new())
	progress.initialize(FixedClock.new())
	var disk: SaveStorage = storage if storage != null else InterruptedStorage.new(PATH)
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


func wallet(coins: int, hints: int, reveals: int) -> void:
	var section: Dictionary = b.save.get_section(&"economy")
	section.coins = coins
	section.items = {"hint": hints, "reveal": reveals}
	assert_eq(b.save.set_section(&"economy", section), OK)
	assert_eq(b.save.flush(), OK)


func request(source: BoardState, kind: StringName) -> Dictionary:
	var after: BoardState = PaidToolPlan.after(source, kind)
	return b.progress.paid_tool_request(
		source, kind, b.port.tool_commands(kind, after != null and after.is_complete())
	)


func test_item_first_partial_hint_and_exact_replay() -> void:
	wallet(500, 2, 0)
	var before: Dictionary = board.to_dict()
	var intent: Dictionary = request(board, &"hint")
	assert_false(intent.is_empty())
	assert_eq(
		intent.economy_commands, [{"operation": "spend", "reason": "hint", "amounts": {"hint": 1}}]
	)
	watch_signals(b.bus)
	var result: Dictionary = b.port.transact(intent)
	assert_eq(result.error, OK)
	assert_eq(board.to_dict(), before, "The live board has not been published by an owner")
	assert_eq(b.economy.snapshot().coins, 500)
	assert_eq(b.economy.snapshot().items.hint, 1)
	assert_eq(b.save.get_section(&"progress").by_lang.pl.level_state, intent.tool.after)
	assert_eq(b.progress.current_slot(), 2)
	assert_eq(result.receipt.delta, {})
	assert_signal_emit_count(b.bus, "economy_changed", 1)
	var revision: int = b.save.committed_view().revision
	assert_eq(b.port.transact(intent).error, OK)
	assert_eq(b.save.committed_view().revision, revision)
	assert_signal_emit_count(b.bus, "economy_changed", 1)
	var conflicting: Dictionary = intent.duplicate(true)
	conflicting.economy_commands[0].amounts.hint = 2
	assert_ne(b.port.transact(conflicting).error, OK)
	assert_eq(b.economy.snapshot().items.hint, 1)


func test_coin_hint_and_both_reveal_costs() -> void:
	for kind: StringName in [&"hint", &"reveal", &"reveal"]:
		var count: int = 1 if kind == &"reveal" and board.revealed_cells().size() == 1 else 0
		wallet(500, 0, count)
		var intent: Dictionary = request(board, kind)
		var price: int = b.config.get_int(StringName("economy.price." + str(kind)))
		assert_eq(b.port.transact(intent).error, OK)
		var after: BoardState = BoardState.from_dict(board.get_level(), intent.tool.after, true)
		var reward: int = (
			b.config.get_int(&"economy.reward.level_complete") if after.is_complete() else 0
		)
		assert_eq(b.economy.snapshot().coins, (500 if count > 0 else 500 - price) + reward)
		assert_eq(b.economy.snapshot().items.reveal, 0)
		board = BoardState.from_dict(board.get_level(), intent.tool.after, true)
		if not board.is_complete():
			assert_eq(b.progress.bind_board(board), OK)


func test_final_tool_commits_completion_rewards_and_crossings_together() -> void:
	# Leave one occupied cell. The plan may complete several intersecting words.
	var last: Vector2i = board.get_level().word_cells(0)[0]
	for index: int in board.get_level().word_count():
		for cell: Vector2i in board.get_level().word_cells(index):
			if cell != last:
				board.reveal_cell(cell)
	assert_eq(b.progress.save_level(board), OK)
	var before_stars: int = b.progress.stars()
	var intent: Dictionary = request(board, &"hint")
	var candidate: BoardState = BoardState.from_dict(board.get_level(), intent.tool.after)
	assert_true(candidate.is_complete())
	watch_signals(b.bus)
	assert_eq(b.port.transact(intent).error, OK)
	assert_false(board.is_complete())
	assert_eq(b.progress.current_slot(), 3)
	assert_eq(b.progress.stars(), before_stars + 1)
	assert_eq(
		b.economy.snapshot().coins, 500 - 100 + b.config.get_int(&"economy.reward.level_complete")
	)
	assert_null(b.save.get_section(&"progress").by_lang.pl.level_state)
	assert_signal_emit_count(b.bus, "stars_earned", 1)
	assert_eq(b.port.transact(intent).error, OK)
	assert_signal_emit_count(b.bus, "stars_earned", 1)


func test_insufficient_balance_cannot_be_financed_by_final_reward() -> void:
	wallet(0, 0, 0)
	var before: Dictionary = b.save.committed_view()
	assert_true(b.economy.tool_commands(&"hint", true).is_empty())
	var intent: Dictionary = request(board, &"hint")
	assert_ne(b.port.transact(intent).error, OK)
	assert_eq(b.save.committed_view(), before)
	assert_false(b.save.writes_blocked())


func test_foreign_unsaved_complete_and_changed_board_requests_are_rejected() -> void:
	assert_true(request(BoardState.new(board.get_level()), &"hint").is_empty())
	board.reveal_cell(HintLogic.next_cell(board))
	assert_true(
		request(board, &"hint").is_empty(), "Uncheckpointed progress is not a paid baseline"
	)
	assert_eq(b.progress.save_level(board), OK)
	var intent: Dictionary = request(board, &"hint")
	board.reveal_cell(HintLogic.next_cell(board))
	assert_ne(b.port.transact(intent).error, OK)
	assert_false(b.save.writes_blocked())
	for index: int in board.get_level().word_count():
		for cell: Vector2i in board.get_level().word_cells(index):
			board.reveal_cell(cell)
	assert_true(request(board, &"reveal").is_empty())
	assert_null(PaidToolPlan.after(null, &"hint"))
	assert_null(PaidToolPlan.after(board, &"unknown"))


func test_config_change_rejects_old_proposal_and_releases_lease() -> void:
	var intent: Dictionary = request(board, &"hint")
	b.config.hint_price = 101
	assert_ne(b.port.transact(intent).error, OK)
	assert_eq(b.economy.snapshot().coins, 500)
	assert_false(b.save.writes_blocked())


func test_all_write_gaps_retry_or_restart_preserve_joint_outcome() -> void:
	for step: StringName in [
		&"temp_opened", &"temp_written", &"temp_flushed", &"backup_rotated", &"primary_promoted"
	]:
		var storage: InterruptedStorage = b.storage
		storage.stop_at = step
		var intent: Dictionary = request(board, &"hint")
		var before: Dictionary = board.to_dict()
		var result: Dictionary = b.port.transact(intent)
		assert_eq(board.to_dict(), before)
		var promoted: bool = step in [&"backup_rotated", &"primary_promoted"]
		assert_eq(result.error, OK if promoted else ERR_BUSY, str(step))
		assert_eq(b.economy.snapshot().coins, 400 if promoted else 500)
		if not promoted:
			assert_true(b.save.writes_blocked())
			assert_eq(b.save.set_setting(&"haptics_enabled", false), ERR_BUSY)
			assert_eq(b.economy.grant(&"test", {"coins": 1}), ERR_BUSY)
		# Simulate process death by loading independent real owners from the same files.
		var restarted: Dictionary = bundle()
		assert_eq(restarted.economy.snapshot().coins, 400 if promoted else 500)
		var restored: BoardState = restarted.progress.restore_level(
			restarted.content.level_for_slot(2)
		)
		assert_eq(
			AtomicRequest.hash_value(restored.to_dict()),
			AtomicRequest.hash_value(intent.tool.after if promoted else before)
		)
		storage.stop_at = &""
		assert_eq(b.port.transact(intent).error, OK)
		assert_eq(b.economy.snapshot().coins, 400)
		assert_eq(b.port.transact(intent).error, OK)
		assert_eq(b.economy.snapshot().coins, 400)
		# Reset only this test's fixture before the next independent gap.
		b = restarted
		board = restored
		if promoted:
			board = BoardState.from_dict(board.get_level(), intent.tool.after, true)
		assert_eq(b.progress.bind_board(board), OK)
		# The restarted owner must observe the original retry's durable result too.
		b = bundle()
		board = b.progress.restore_level(b.content.level_for_slot(2))
		assert_eq(b.progress.bind_board(board), OK)
		wallet(500, 0, 0)


func test_reentrant_owner_write_is_blocked_during_publication() -> void:
	var outcomes: Array[Error] = []
	b.bus.economy_changed.connect(
		func(
			_op: StringName, _reason: StringName, _amounts: Dictionary, _wallet: Dictionary
		) -> void:
			outcomes.append(b.save.set_setting(&"haptics_enabled", false))
	)
	assert_eq(b.port.transact(request(board, &"hint")).error, OK)
	assert_eq(outcomes, [ERR_BUSY])
	assert_true(b.save.get_setting(&"haptics_enabled"))


func test_historical_bonus_and_unrelated_sections_survive_paid_candidate() -> void:
	var snapshot: Dictionary = board.to_dict()
	snapshot.bonus_words = ["MAD"]
	board = BoardState.from_dict(board.get_level(), snapshot, true)
	assert_not_null(board)
	assert_eq(b.progress.bind_board(board), OK)
	assert_eq(b.progress.save_level(board), OK)
	assert_eq(b.save.set_setting(&"haptics_enabled", false), OK)
	var daily: Dictionary = b.save.get_section(&"daily")
	daily.freezes = 1
	assert_eq(b.save.set_section(&"daily", daily), OK)
	assert_eq(b.save.flush(), OK)
	var intent: Dictionary = request(board, &"hint")
	assert_eq(b.port.transact(intent).error, OK)
	assert_eq(b.save.get_section(&"progress").by_lang.pl.level_state.bonus_words, ["MAD"])
	assert_eq(b.save.get_section(&"daily"), daily)
	assert_false(b.save.get_setting(&"haptics_enabled"))


func test_final_boundary_revalidates_config_and_original_board() -> void:
	for change: String in ["config", "board"]:
		var intent: Dictionary = request(board, &"hint")
		var storage: InterruptedStorage = b.storage
		storage.on_read = func() -> void:
			if change == "config":
				b.config.hint_price = 101
			else:
				board.reveal_cell(HintLogic.next_cell(board))
		assert_ne(b.port.transact(intent).error, OK)
		assert_eq(b.economy.snapshot().coins, 500)
		assert_false(b.save.writes_blocked())
		b.config.hint_price = 100


func test_storage_replacement_never_overwrites_an_external_winner() -> void:
	var other: Dictionary = bundle()
	var intent: Dictionary = request(board, &"hint")
	var storage: InterruptedStorage = b.storage
	storage.on_read = func() -> void:
		assert_eq(other.save.set_setting(&"haptics_enabled", false), OK)
	assert_ne(b.port.transact(intent).error, OK)
	assert_eq(b.economy.snapshot().coins, 500)
	assert_false(b.save.get_setting(&"haptics_enabled"))
	assert_false(b.save.writes_blocked())


func test_final_hint_and_reveal_gaps_keep_debit_completion_and_rewards_together() -> void:
	for kind: StringName in [&"hint", &"reveal"]:
		for step: StringName in [
			&"temp_opened", &"temp_written", &"temp_flushed", &"backup_rotated", &"primary_promoted"
		]:
			before_each()
			var last: Vector2i = board.get_level().word_cells(0)[0]
			for index: int in board.get_level().word_count():
				for cell: Vector2i in board.get_level().word_cells(index):
					if cell != last:
						board.reveal_cell(cell)
			assert_eq(b.progress.save_level(board), OK)
			wallet(500, 1 if kind == &"hint" else 0, 1 if kind == &"reveal" else 0)
			var intent: Dictionary = request(board, kind)
			var disk: InterruptedStorage = b.storage
			disk.stop_at = step
			var promoted: bool = step in [&"backup_rotated", &"primary_promoted"]
			assert_eq(b.port.transact(intent).error, OK if promoted else ERR_BUSY)
			var restarted: Dictionary = bundle()
			assert_eq(restarted.progress.current_slot(), 3 if promoted else 2)
			assert_eq(restarted.progress.stars(), 2 if promoted else 1)
			assert_eq(restarted.economy.snapshot().items[str(kind)], 0 if promoted else 1)
			var reward: int = b.config.get_int(&"economy.reward.level_complete")
			assert_eq(restarted.economy.snapshot().coins, 500 + reward if promoted else 500)
			disk.stop_at = &""
			assert_eq(b.port.transact(intent).error, OK)
			assert_eq(b.port.transact(intent).error, OK)
			assert_eq(b.economy.snapshot().items[str(kind)], 0)
			assert_eq(b.economy.snapshot().coins, 500 + reward)
			assert_eq(b.progress.current_slot(), 3)
			assert_false(board.is_complete())


func test_paid_ui_bindings_certify_exact_owners_content_config_and_port() -> void:
	assert_true(b.port.certifies_tools(b.save, b.progress, b.economy, b.content, b.config))
	var config: ToolConfig = ToolConfig.new()
	add_child_autofree(config)
	assert_eq(config.load(), OK)
	assert_false(b.port.certifies_tools(b.save, b.progress, b.economy, b.content, config))
	var other: Dictionary = bundle()
	assert_false(b.port.certifies_tools(b.save, b.progress, other.economy, b.content, b.config))
	assert_false(b.port.certifies_tools(b.save, b.progress, b.economy, other.content, b.config))
	assert_false(other.port.certifies_tools(b.save, b.progress, b.economy, b.content, b.config))


func test_price_override_after_first_failed_write_keeps_issued_cost_and_next_action_requotes(
) -> void:
	var intent: Dictionary = request(board, &"hint")
	var storage: InterruptedStorage = b.storage
	storage.stop_at = &"temp_opened"
	assert_eq(b.port.transact(intent).error, ERR_BUSY)
	b.config.hint_price = 101
	storage.stop_at = &""
	assert_eq(b.port.transact(intent).error, OK)
	assert_eq(b.economy.snapshot().coins, 400)
	assert_eq(b.port.transact(intent).error, OK)
	assert_eq(b.economy.snapshot().coins, 400)
	board = BoardState.from_dict(board.get_level(), intent.tool.after, true)
	assert_eq(b.progress.bind_board(board), OK)
	var next: Dictionary = request(board, &"hint")
	assert_eq(next.economy_commands[0].amounts, {"coins": 101})
	assert_eq(b.port.transact(next).error, OK)
	assert_eq(b.economy.snapshot().coins, 299)


func test_final_paid_price_override_retry_keeps_completion_and_reward_once() -> void:
	var last: Vector2i = board.get_level().word_cells(0)[0]
	for index: int in board.get_level().word_count():
		for cell: Vector2i in board.get_level().word_cells(index):
			if cell != last:
				board.reveal_cell(cell)
	assert_eq(b.progress.save_level(board), OK)
	var intent: Dictionary = request(board, &"hint")
	var storage: InterruptedStorage = b.storage
	storage.stop_at = &"temp_opened"
	assert_eq(b.port.transact(intent).error, ERR_BUSY)
	b.config.hint_price = 101
	storage.stop_at = &""
	assert_eq(b.port.transact(intent).error, OK)
	assert_eq(b.economy.snapshot().coins, 400 + b.config.get_int(&"economy.reward.level_complete"))
	assert_eq(b.progress.current_slot(), 3)
	assert_eq(b.port.transact(intent).error, OK)
	assert_eq(b.economy.snapshot().coins, 400 + b.config.get_int(&"economy.reward.level_complete"))
