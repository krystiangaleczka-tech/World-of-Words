# gdlint: disable=max-public-methods
# One isolated matrix verifies public P2 reads, transaction routing and durable effects.
extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const PROGRESS: Script = preload("res://services/progress.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONTENT: Script = preload("res://services/content.gd")
const EVENTS: Script = preload("res://services/events.gd")
const PATH: String = "user://t0242-p2-save.json"
const ROOT: String = "user://t0242-content"
const FIXTURE: String = "res://tests/fixtures/content"
const ID: String = "12345678-1234-4234-8234-123456789abc"


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 1790942400


class TestConfig:
	extends "res://services/config.gd"
	var overrides: Dictionary = {"economy.journal.max_entries": 2}

	func get_int(key: StringName) -> int:
		return overrides[str(key)] if overrides.has(str(key)) else super.get_int(key)


class InterruptedStorage:
	extends SaveStorage
	var stop_at: StringName = &""
	var invisible: bool = false

	func checkpoint(step: StringName) -> Error:
		return ERR_BUSY if step == stop_at else OK

	func read_document(suffix: String = "") -> Dictionary:
		return {} if invisible else super.read_document(suffix)


class AvailableFake:
	extends ProgressCommitPort
	var calls: int = 0

	func is_available() -> bool:
		calls += 1
		return true


class LosingProgress:
	extends "res://services/progress.gd"
	var lose: bool = true

	func accept_commit(receipt: Dictionary) -> Error:
		return ERR_UNAVAILABLE if lose else super.accept_commit(receipt)


var _b: Dictionary


func before_each() -> void:
	_clean()
	_write_content("pl")
	_b = _bundle()


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	for language: String in ["pl", "en"]:
		DirAccess.remove_absolute(ROOT.path_join(language + "/manifest.json"))
		DirAccess.remove_absolute(ROOT.path_join(language + "/packs/c-0001-0003.json"))


func _write_content(language: String, version: int = 1) -> void:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(FIXTURE.path_join("pl/manifest.json"))
	)
	var pack: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(FIXTURE.path_join("pl/packs/c-0001-0003.json"))
	)
	pack.lang = language
	DirAccess.make_dir_recursive_absolute(ROOT.path_join(language + "/packs"))
	var file: FileAccess = FileAccess.open(
		ROOT.path_join(language + "/packs/c-0001-0003.json"), FileAccess.WRITE
	)
	file.store_string(JSON.stringify(pack, "", true, true))
	file.close()
	manifest.lang = language
	manifest.content_version = version
	manifest.packs[0].sha256 = FileAccess.get_sha256(
		ROOT.path_join(language + "/packs/c-0001-0003.json")
	)
	manifest["regions"] = [
		{"id": "first", "name_key": "journey.region.first", "first": 1, "last": 1},
		{"id": "second", "name_key": "journey.region.second", "first": 2, "last": 3}
	]
	manifest["locations"] = [
		{
			"id": "one",
			"region": "first",
			"name_key": "journey.location.one",
			"first": 1,
			"last": 1,
			"postcard": "postcards/one.webp",
			"pieces": 4
		},
		{
			"id": "two",
			"region": "second",
			"name_key": "journey.location.two",
			"first": 2,
			"last": 3,
			"postcard": "postcards/two.webp",
			"pieces": 4
		}
	]
	manifest["landmarks"] = []
	file = FileAccess.open(ROOT.path_join(language + "/manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "", true, true))
	file.close()


func _bundle(
	storage: SaveStorage = null, activate: bool = true, owner: PROGRESS = null
) -> Dictionary:
	var save: SAVE = SAVE.new()
	var progress: PROGRESS = PROGRESS.new() if owner == null else owner
	var economy: ECONOMY = ECONOMY.new()
	var content: CONTENT = CONTENT.new()
	var config: TestConfig = TestConfig.new()
	var events: EVENTS = EVENTS.new()
	for node: Node in [save, progress, economy, content, config, events]:
		add_child_autofree(node)
	save.initialize(FixedClock.new())
	economy.initialize(FixedClock.new())
	progress.initialize(FixedClock.new())
	save.configure(
		storage if storage != null else SaveStorage.new(PATH), func() -> String: return ID
	)
	assert_eq(config.load(), OK)
	assert_eq(content.load_manifest("pl", ROOT), OK)
	progress.configure(save, content)
	assert_eq(progress.configure_atomic(config), OK)
	economy.configure(save, config, events)
	var port: AtomicProgressPort = AtomicProgressPort.new()
	assert_eq(port.configure(save, progress, economy), OK)
	assert_eq(save.load(), OK)
	if activate:
		assert_eq(progress.configure_p2(config, port, events), OK)
	return {
		"save": save,
		"progress": progress,
		"economy": economy,
		"content": content,
		"config": config,
		"events": events,
		"port": port
	}


func _board(bundle: Dictionary = {}, complete: bool = true) -> BoardState:
	var b: Dictionary = _b if bundle.is_empty() else bundle
	var level: LevelData = b.content.level_for_slot(b.progress.current_slot())
	var board: BoardState = BoardState.new(level)
	if complete:
		for index: int in level.word_count():
			for cell: Vector2i in level.word_cells(index):
				board.reveal_cell(cell)
	assert_eq(b.progress.bind_board(board), OK)
	return board


func _write(document: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", true, true))
	file.close()


func _proof(slot: int, bundle: Dictionary = {}) -> Dictionary:
	var b: Dictionary = _b if bundle.is_empty() else bundle
	var atomic: Dictionary = b.save.get_section(&"meta").atomic
	return atomic.processed[
		"%d:campaign_complete:%s:%d" % [atomic.lineage, b.content.get_language(), slot]
	]


func _watch(bundle: Dictionary = {}) -> void:
	var b: Dictionary = _b if bundle.is_empty() else bundle
	watch_signals(b.progress)
	watch_signals(b.events)


func test_explicit_real_activation_default_fake_and_unconfigured_stay_inert() -> void:
	assert_true(_b.progress.p2_ready())
	assert_eq(_b.progress.p2_state(), "ready")
	assert_eq(_b.progress.current_slot(), 1)
	assert_eq(_b.progress.highest_completed_slot(), 0)
	var b: Dictionary = _bundle(null, false)
	assert_false(b.progress.p2_ready())
	assert_eq(b.progress.language_progress(), {})
	assert_eq(
		b.progress.configure_p2(b.config, ProgressCommitPort.new(), b.events), ERR_UNAVAILABLE
	)
	var fake: AvailableFake = AvailableFake.new()
	assert_eq(b.progress.configure_p2(b.config, fake, b.events), ERR_UNAVAILABLE)
	assert_eq(fake.calls, 0)
	assert_false(b.progress.p2_ready())


func test_committed_reads_copy_isolation_no_getter_write_or_unlock_backfill() -> void:
	_watch()
	var file: String = FileAccess.get_file_as_string(PATH)
	var snapshot: Dictionary = _b.progress.language_progress()
	assert_eq(snapshot.current_slot, 1)
	assert_eq(snapshot.location_stars, {})
	assert_eq(_b.progress.stars(), 0)
	assert_false(_b.progress.is_feature_unlocked(&"hint"))
	assert_eq(_b.progress.location_state(&"unknown"), {})
	assert_eq(_b.progress.region_state(&"unknown"), {})
	assert_false(_b.progress.location_state(&"one").campaign_complete)
	assert_false(_b.progress.location_state(&"one").postcard_complete)
	assert_false(_b.progress.region_state(&"second").unlocked)
	snapshot.unlocked.append("hint")
	var location: Dictionary = _b.progress.location_state(&"one")
	location.metadata.id = "mutated"
	assert_false(_b.progress.is_feature_unlocked(&"hint"))
	assert_eq(_b.progress.location_state(&"one").metadata.id, "one")
	assert_eq(FileAccess.get_file_as_string(PATH), file)
	assert_signal_not_emitted(_b.events, "stars_earned")


func test_completion_persists_full_candidate_and_announces_in_order_under_save_guard() -> void:
	var order: Array[String] = []
	_b.events.economy_changed.connect(
		func(
			_op: StringName, _reason: StringName, _amounts: Dictionary, _wallet: Dictionary
		) -> void:
			order.append("economy")
	)
	_b.progress.completed.connect(
		func(slot: int) -> void:
			order.append("completed")
			assert_eq(slot, 1)
			assert_eq(_b.progress.current_slot(), 2)
			assert_eq(_b.progress.stars(), 1)
			assert_eq(_b.economy.snapshot().coins, 25)
			assert_eq(_b.progress.complete_level(1), ERR_BUSY)
			assert_eq(_b.economy.grant(&"nested", {"coins": 1}), ERR_BUSY)
			assert_eq(_b.save.set_setting(&"language", "en"), ERR_BUSY)
			assert_eq(_b.progress.configure_p2(_b.config, _b.port, _b.events), ERR_BUSY)
	)
	_b.events.stars_earned.connect(
		func(_language: String, _slot: int, _stars: int) -> void: order.append("stars")
	)
	_b.events.postcard_piece_revealed.connect(
		func(_language: String, _location: String, _pieces: int) -> void: order.append("piece")
	)
	_b.events.location_complete.connect(
		func(_language: String, _location: String) -> void: order.append("card")
	)
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	assert_eq(order, ["economy", "completed", "stars", "piece", "card"])
	assert_eq(_b.progress.location_state(&"one").pieces, 4)
	assert_true(_b.progress.location_state(&"one").postcard_complete)
	assert_true(_b.progress.region_state(&"first").campaign_complete)
	assert_true(_b.progress.region_state(&"second").unlocked)


func test_meta_payloads_and_unlocks_come_from_durable_delta_once() -> void:
	_watch()
	_b.config.overrides["unlocks.hint_slot"] = 2
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	assert_true(_b.progress.is_feature_unlocked(&"hint"))
	assert_eq(_b.economy.snapshot().items.hint, 3)
	assert_signal_emitted_with_parameters(_b.events, "stars_earned", ["pl", 1, 1])
	assert_signal_emitted_with_parameters(_b.events, "postcard_piece_revealed", ["pl", "one", 4])
	assert_signal_emitted_with_parameters(_b.events, "location_complete", ["pl", "one"])
	assert_signal_emitted_with_parameters(_b.events, "feature_unlocked", ["pl", &"hint", 1])
	assert_eq(_b.progress.complete_level(1), OK)
	assert_eq(_b.progress.accept_commit(_proof(1)), OK)
	assert_signal_emit_count(_b.progress, "completed", 1)
	assert_signal_emit_count(_b.events, "stars_earned", 1)
	assert_eq(_b.economy.snapshot().coins, 25)


func test_incomplete_skipped_and_invalid_slots_do_not_advance_or_grant() -> void:
	_watch()
	_board({}, false)
	assert_eq(_b.progress.complete_level(1), ERR_INVALID_PARAMETER)
	assert_eq(_b.progress.complete_level(2), ERR_INVALID_PARAMETER)
	assert_eq(_b.progress.complete_level(0), ERR_INVALID_PARAMETER)
	assert_eq(_b.progress.complete_level(4), ERR_INVALID_PARAMETER)
	assert_eq(_b.economy.snapshot().coins, 0)
	assert_signal_not_emitted(_b.progress, "completed")
	assert_signal_not_emitted(_b.events, "stars_earned")


func test_each_checkpoint_retry_and_restart_old_or_one() -> void:
	for checkpoint: StringName in [
		&"temp_opened", &"temp_written", &"temp_flushed", &"backup_rotated", &"primary_promoted"
	]:
		for suffix: String in ["", ".tmp", ".bak"]:
			DirAccess.remove_absolute(PATH + suffix)
		var storage: InterruptedStorage = InterruptedStorage.new(PATH)
		_b = _bundle(storage)
		_watch()
		_board()
		storage.stop_at = checkpoint
		var success: bool = checkpoint in [&"backup_rotated", &"primary_promoted"]
		assert_eq(_b.progress.complete_level(1), OK if success else ERR_BUSY)
		assert_eq(_b.progress.stars(), 1 if success else 0)
		assert_eq(_b.progress.location_state(&"one").pieces, 4 if success else 0)
		assert_signal_emit_count(_b.events, "stars_earned", 1 if success else 0)
		var restarted: Dictionary = _bundle()
		assert_eq(restarted.progress.current_slot(), 2 if success else 1)
		assert_eq(restarted.economy.snapshot().coins, 25 if success else 0)
		storage.stop_at = &""
		if not success:
			assert_eq(_b.progress.complete_level(2), ERR_BUSY)
			assert_eq(_b.progress.complete_level(1), OK)
		assert_eq(_b.progress.stars(), 1)
		assert_signal_emit_count(_b.progress, "completed", 1)


func test_pause_resolves_pending_even_after_screen_unbind() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	var storage: InterruptedStorage = InterruptedStorage.new(PATH)
	_b = _bundle(storage)
	_watch()
	_board()
	storage.stop_at = &"temp_flushed"
	assert_eq(_b.progress.complete_level(1), ERR_BUSY)
	_b.progress.unbind_board()
	storage.stop_at = &""
	_b.progress.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_b.progress.current_slot(), 2)
	assert_eq(_b.economy.snapshot().coins, 25)
	assert_signal_emit_count(_b.events, "stars_earned", 1)


func test_unknown_reads_keep_old_views_and_exact_request_until_recovery() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	var storage: InterruptedStorage = InterruptedStorage.new(PATH)
	_b = _bundle(storage)
	_board()
	storage.stop_at = &"temp_flushed"
	assert_eq(_b.progress.complete_level(1), ERR_BUSY)
	storage.invisible = true
	assert_eq(_b.progress.complete_level(1), ERR_UNAVAILABLE)
	assert_eq(_b.progress.stars(), 0)
	assert_eq(_b.economy.snapshot().coins, 0)
	storage.invisible = false
	storage.stop_at = &""
	assert_eq(_b.progress.complete_level(1), OK)
	assert_eq(_b.progress.stars(), 1)


func test_restart_replays_historical_effects_once_without_rolling_back_view() -> void:
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	var proof: Dictionary = _proof(1)
	_board()
	assert_eq(_b.progress.complete_level(2), OK)
	_board()
	assert_eq(_b.progress.complete_level(3), OK)
	assert_eq(_b.economy.journal().size(), 2)
	var restarted: Dictionary = _bundle()
	_watch(restarted)
	var result: Dictionary = restarted.port.recover(
		proof.operation_id, {"request_hash": proof.request_hash}
	)
	assert_eq(result.state, "replayed")
	assert_eq(result.snapshot.current_slot, 4)
	assert_eq(restarted.progress.stars(), 3)
	assert_eq(restarted.economy.snapshot().coins, 75)
	assert_signal_emit_count(restarted.events, "stars_earned", 1)
	assert_eq(
		restarted.port.recover(proof.operation_id, {"request_hash": proof.request_hash}).error, OK
	)
	assert_signal_emit_count(restarted.events, "stars_earned", 1)


func test_reset_invalidates_old_receipts_and_new_lineage_can_complete() -> void:
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	var proof: Dictionary = _proof(1)
	assert_eq(_b.save.debug_reset(), OK)
	_watch()
	assert_eq(_b.progress.accept_commit(proof), ERR_INVALID_DATA)
	assert_eq(_b.progress.stars(), 0)
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	assert_eq(_b.save.get_section(&"meta").atomic.lineage, 1)
	assert_signal_emit_count(_b.events, "stars_earned", 1)
	assert_eq(_b.economy.snapshot().coins, 25)


func test_missing_language_and_language_switch_preserve_independent_progress_and_wallet() -> void:
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	_write_content("en")
	assert_eq(_b.save.set_setting(&"language", "en"), OK)
	assert_false(_b.progress.p2_ready())
	assert_eq(_b.progress.complete_level(2), ERR_UNAVAILABLE)
	assert_eq(_b.content.load_manifest("en", ROOT), OK)
	assert_true(_b.progress.p2_ready())
	var primary: String = FileAccess.get_file_as_string(PATH)
	assert_eq(_b.progress.language_progress().current_slot, 1)
	assert_eq(_b.progress.stars(), 0)
	assert_eq(FileAccess.get_file_as_string(PATH), primary)
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	assert_eq(_b.economy.snapshot().coins, 50)
	assert_eq(_b.save.get_section(&"progress").by_lang.pl.current_slot, 2)
	assert_eq(_b.progress.language_progress("pl"), {}, "inactive metadata fails closed")
	assert_eq(_b.save.set_setting(&"language", "pl"), OK)
	assert_eq(_b.content.load_manifest("pl", ROOT), OK)
	assert_eq(_b.progress.stars(), 1)
	assert_eq(_b.economy.snapshot().coins, 50)


func test_historical_endpoint_separates_campaign_from_missing_postcard_credit() -> void:
	var progress: Dictionary = _b.save.get_section(&"progress")
	progress.by_lang.pl.current_slot = 2
	progress.by_lang.pl.highest_completed_slot = 1
	progress.by_lang.pl.completed_slot = 1
	progress.by_lang.pl.stars = 7
	assert_eq(_b.save.set_section(&"progress", progress), OK)
	assert_eq(_b.save.flush(), OK)
	var file: String = FileAccess.get_file_as_string(PATH)
	assert_eq(_b.progress.stars(), 7)
	assert_eq(_b.progress.region_state(&"first").stars, 0)
	assert_true(_b.progress.location_state(&"one").campaign_complete)
	assert_false(_b.progress.location_state(&"one").postcard_complete)
	assert_eq(_b.progress.location_state(&"one").stars, 0)
	assert_eq(_b.progress.complete_level(1), OK)
	assert_eq(_b.economy.snapshot().coins, 0)
	assert_eq(FileAccess.get_file_as_string(PATH), file)


func test_legacy_blocked_activation_preserves_original_and_p1_fallback() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	var document: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/save/v3.json")
	)
	document.meta.atomic = "legacy-extension"
	_write(document)
	var b: Dictionary = _bundle(null, false)
	var primary: String = FileAccess.get_file_as_string(PATH)
	assert_eq(b.progress.configure_p2(b.config, b.port, b.events), ERR_UNAVAILABLE)
	assert_eq(b.progress.p2_state(), "needs_migration")
	assert_false(b.progress.p2_ready())
	assert_eq(FileAccess.get_file_as_string(PATH), primary)
	assert_eq(b.progress.complete_level(1), OK, "initial failed P2 activation keeps P1")
	assert_eq(b.save.get_section(&"meta").atomic, "legacy-extension")


func test_later_incompatibility_fails_closed_without_switching_back_to_p1() -> void:
	var progress: Dictionary = _b.save.get_section(&"progress")
	progress.by_lang.pl.highest_completed_slot = 1
	assert_eq(_b.save.set_section(&"progress", progress), OK)
	assert_eq(_b.save.flush(), OK)
	assert_eq(_b.progress.p2_state(), "needs_migration")
	assert_eq(_b.progress.complete_level(1), ERR_UNAVAILABLE)
	assert_eq(_b.economy.snapshot().coins, 0)
	assert_eq(_b.save.get_section(&"progress").by_lang.pl.current_slot, 1)


func test_save_level_dirty_data_does_not_become_a_committed_meta_view() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	var storage: InterruptedStorage = InterruptedStorage.new(PATH)
	_b = _bundle(storage)
	var board: BoardState = _board({}, false)
	assert_true(board.reveal_cell(Vector2i(0, 0)))
	storage.stop_at = &"temp_flushed"
	assert_eq(_b.progress.save_level(board), ERR_BUSY)
	assert_eq(_b.progress.stars(), 0)
	assert_eq(_b.save.committed_view().sections.progress.by_lang.pl.level_state, null)
	storage.stop_at = &""
	assert_eq(_b.progress.save_level(board), OK)
	assert_eq(_b.progress.current_slot(), 1)


func test_lost_notifications_do_not_erase_durability_and_recovery_publishes_once() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	var losing: LosingProgress = LosingProgress.new()
	_b = _bundle(null, true, losing)
	_watch()
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	assert_eq(_b.progress.stars(), 1)
	assert_eq(_b.economy.snapshot().coins, 25)
	assert_signal_not_emitted(_b.events, "stars_earned")
	var proof: Dictionary = _proof(1)
	losing.lose = false
	assert_eq(_b.port.recover(proof.operation_id, {"request_hash": proof.request_hash}).error, OK)
	assert_eq(_b.port.recover(proof.operation_id, {"request_hash": proof.request_hash}).error, OK)
	assert_signal_emit_count(_b.events, "stars_earned", 1)


func test_foreign_or_mutated_receipt_cannot_publish_effects() -> void:
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	var proof: Dictionary = _proof(1)
	_watch()
	proof.delta.stars = 999
	assert_eq(_b.progress.accept_commit(proof), ERR_INVALID_DATA)
	assert_signal_not_emitted(_b.events, "stars_earned")
	assert_eq(_b.progress.stars(), 1)


func test_pause_completes_bound_board_atomically_without_p1_advance() -> void:
	_watch()
	_board()
	_b.progress.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_b.progress.current_slot(), 2)
	assert_eq(_b.economy.snapshot().coins, 25)
	assert_signal_emit_count(_b.events, "stars_earned", 1)


func test_reset_cannot_complete_or_pause_the_previous_lineage_board() -> void:
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	assert_eq(_b.save.debug_reset(), OK)
	_watch()
	assert_eq(_b.progress.complete_level(1), ERR_INVALID_PARAMETER)
	_b.progress.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_b.progress.current_slot(), 1)
	assert_eq(_b.progress.stars(), 0)
	assert_eq(_b.economy.snapshot().coins, 0)
	assert_signal_not_emitted(_b.events, "economy_changed")
	assert_signal_not_emitted(_b.events, "stars_earned")
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	assert_eq(_b.progress.stars(), 1)
	assert_eq(_b.economy.snapshot().coins, 25)


func test_economy_callbacks_cannot_publish_progress_inside_the_economy_batch() -> void:
	_b.config.overrides["unlocks.hint_slot"] = 2
	var order: Array[String] = []
	_b.events.economy_changed.connect(
		func(
			_op: StringName, _reason: StringName, _amounts: Dictionary, _wallet: Dictionary
		) -> void:
			order.append("economy")
			assert_eq(_b.progress.accept_commit(_proof(1)), ERR_BUSY)
	)
	_b.progress.completed.connect(func(_slot: int) -> void: order.append("completed"))
	_b.events.stars_earned.connect(
		func(_language: String, _slot: int, _stars: int) -> void: order.append("stars")
	)
	_board()
	assert_eq(_b.progress.complete_level(1), OK)
	assert_eq(order, ["economy", "economy", "completed", "stars"])
	assert_eq(_b.economy.snapshot().coins, 25)
	assert_eq(_b.economy.snapshot().items.hint, 3)
	assert_eq(_b.progress.accept_commit(_proof(1)), OK)
	assert_eq(order, ["economy", "economy", "completed", "stars"])


func test_reset_cannot_persist_the_previous_lineage_partial_board() -> void:
	var board: BoardState = _board({}, false)
	var level: LevelData = board.get_level()
	board.reveal_cell(level.word_cells(0)[0])
	assert_eq(_b.progress.save_level(board), OK)
	assert_eq(_b.save.debug_reset(), OK)
	var file: String = FileAccess.get_file_as_string(PATH)
	var reset_progress: Dictionary = _b.save.get_section(&"progress")
	assert_eq(_b.progress.save_level(board), ERR_INVALID_PARAMETER)
	_b.progress.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq_deep(_b.save.get_section(&"progress"), reset_progress)
	assert_null(_b.save.get_section(&"progress").by_lang.pl.level_state)
	assert_eq(FileAccess.get_file_as_string(PATH), file)
	var fresh: BoardState = _board({}, false)
	assert_eq(_b.progress.save_level(fresh), OK)
	assert_eq(_b.save.get_section(&"progress").by_lang.pl.level_state, fresh.to_dict())
