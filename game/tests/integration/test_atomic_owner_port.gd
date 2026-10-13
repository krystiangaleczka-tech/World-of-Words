# gdlint: disable=max-public-methods
# Keep the concrete-owner transaction and historical-adaptation matrix together.
extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const PROGRESS: Script = preload("res://services/progress.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONTENT: Script = preload("res://services/content.gd")
const EVENTS: Script = preload("res://services/events.gd")
const PATH: String = "user://t0333-owner-save.json"
const CONTENT_ROOT: String = "user://t0333-content"
const FIXTURE: String = "res://tests/fixtures/content"
const NO_COMMANDS: Array[Dictionary] = []
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
	var callback: Callable

	func checkpoint(step: StringName) -> Error:
		if callback.is_valid():
			callback.call()
		return ERR_BUSY if step == stop_at else OK

	func read_document(suffix: String = "") -> Dictionary:
		return {} if invisible else super.read_document(suffix)


class LosingEconomy:
	extends "res://services/economy.gd"
	var lose: bool = true

	func accept_commit(receipt: Dictionary) -> Error:
		return ERR_UNAVAILABLE if lose else super.accept_commit(receipt)


var _b: Dictionary


func before_each() -> void:
	_clean()
	_b = _bundle()


func after_each() -> void:
	_clean()


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	DirAccess.remove_absolute(CONTENT_ROOT.path_join("pl/manifest.json"))
	DirAccess.remove_absolute(CONTENT_ROOT.path_join("pl/packs/c-0001-0003.json"))


func _bundle(storage: SaveStorage = null, owner: ECONOMY = null) -> Dictionary:
	var save: SAVE = SAVE.new()
	var progress: PROGRESS = PROGRESS.new()
	var economy: ECONOMY = ECONOMY.new() if owner == null else owner
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
	assert_eq(content.load_manifest("pl", FIXTURE), OK)
	progress.configure(save, content)
	assert_eq(progress.configure_atomic(config), OK)
	economy.configure(save, config, events)
	var port: AtomicProgressPort = AtomicProgressPort.new()
	assert_eq(port.configure(save, progress, economy), OK)
	assert_eq(save.load(), OK)
	return {
		"save": save,
		"progress": progress,
		"economy": economy,
		"content": content,
		"config": config,
		"events": events,
		"port": port
	}


func _board(bundle: Dictionary = {}) -> BoardState:
	var b: Dictionary = _b if bundle.is_empty() else bundle
	var level: LevelData = b.content.level_for_slot(b.progress.current_slot())
	var board: BoardState = BoardState.new(level)
	for index: int in level.word_count():
		for cell: Vector2i in level.word_cells(index):
			board.reveal_cell(cell)
	assert_true(board.is_complete())
	assert_eq(b.progress.bind_board(board), OK)
	return board


func _request(bundle: Dictionary = {}) -> Dictionary:
	var b: Dictionary = _b if bundle.is_empty() else bundle
	_board(b)
	var commands: Array[Dictionary] = b.economy.completion_commands("pl", b.progress.current_slot())
	var request: Dictionary = b.progress.completion_request(commands)
	assert_false(request.is_empty())
	return request


func _read_context(bundle: Dictionary = {}) -> Dictionary:
	var b: Dictionary = _b if bundle.is_empty() else bundle
	return {
		"content_version": b.content.content_version(), "manifest_hash": b.content.manifest_hash()
	}


func _prepare(request: Dictionary) -> Dictionary:
	var begin: Dictionary = _b.save.begin_transaction(request)
	assert_eq(begin.error, OK)
	var transaction: SaveTransaction = begin.transaction
	var progress: ProgressPrepared = _b.progress.prepare_completion(transaction)
	var economy: EconomyPrepared = _b.economy.prepare_commands(transaction, progress)
	return {"transaction": transaction, "progress": progress, "economy": economy}


func _write(document: Dictionary, suffix: String = "") -> void:
	var file: FileAccess = FileAccess.open(PATH + suffix, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", true, true))
	file.close()


func _recover(request: Dictionary, bundle: Dictionary = {}) -> Dictionary:
	var b: Dictionary = _b if bundle.is_empty() else bundle
	return b.port.recover(request.operation_id, {"request_hash": AtomicRequest.hash_value(request)})


func test_preparation_is_value_only_and_registered_handles_are_copied() -> void:
	assert_true(_b.port.is_available())
	watch_signals(_b.events)
	var request: Dictionary = _request()
	var before: Dictionary = _b.save.committed_view()
	var primary: String = FileAccess.get_file_as_string(PATH)
	var prepared: Dictionary = _prepare(request)
	assert_eq(prepared.progress.error, OK)
	assert_eq(prepared.economy.error, OK)
	assert_same(_b.progress.prepare_completion(prepared.transaction), prepared.progress)
	assert_same(
		_b.economy.prepare_commands(prepared.transaction, prepared.progress), prepared.economy
	)
	var payload: Dictionary = _b.economy.prepared_payload(prepared.economy, prepared.transaction)
	assert_eq(payload.section.coins, 25)
	payload.section.coins = 999
	payload.notifications[0].amounts.coins = 999
	assert_eq(_b.economy.prepared_payload(prepared.economy, prepared.transaction).section.coins, 25)
	assert_eq_deep(_b.save.committed_view(), before)
	assert_eq(FileAccess.get_file_as_string(PATH), primary)
	assert_signal_not_emitted(_b.events, "economy_changed")
	assert_eq(
		_b.save.commit_transaction(prepared.transaction, prepared.progress, prepared.economy).error,
		OK
	)
	assert_eq(_b.economy.snapshot().coins, 25)
	assert_signal_emit_count(_b.events, "economy_changed", 1)
	assert_false(_b.progress.validates_prepared(prepared.progress, prepared.transaction))


func test_real_port_commits_stars_wallet_and_bounded_journal_once() -> void:
	watch_signals(_b.progress)
	watch_signals(_b.events)
	var first: Dictionary = _request()
	for slot: int in range(1, 4):
		var request: Dictionary = first if slot == 1 else _request()
		var result: Dictionary = _b.port.transact(request)
		assert_eq(result.error, OK)
		assert_eq(result.snapshot.current_slot, slot + 1)
		assert_eq(result.snapshot.stars, slot)
		assert_eq(result.receipt.committed_snapshot.stars, slot)
	assert_eq(_b.economy.snapshot().coins, 75)
	assert_eq(_b.economy.journal().size(), 2)
	var replay: Dictionary = _b.port.transact(first)
	assert_eq(replay.state, "replayed")
	assert_eq(replay.snapshot.current_slot, 4)
	assert_eq(replay.receipt.committed_snapshot.current_slot, 2)
	assert_eq(_b.economy.snapshot().coins, 75)
	assert_signal_emit_count(_b.events, "economy_changed", 3)
	assert_signal_not_emitted(_b.progress, "completed", "T-0242 still owns Progress publication")
	assert_eq(_b.save.get_section(&"meta").atomic.processed.size(), 3)
	assert_eq(
		_b.port.read_committed("pl", _read_context()).snapshot.completed_locations, ["campaign"]
	)


func test_onboarding_hint_batch_is_one_global_future_crossing() -> void:
	_b.config.overrides["unlocks.hint_slot"] = 2
	watch_signals(_b.events)
	var request: Dictionary = _request()
	assert_eq(request.economy_commands.size(), 2)
	assert_eq(_b.port.transact(request).error, OK)
	assert_eq(_b.economy.snapshot().items.hint, 3)
	assert_signal_emit_count(_b.events, "economy_changed", 2)
	assert_eq(_b.port.transact(request).state, "replayed")
	assert_eq(_b.economy.snapshot().items.hint, 3)
	var progress: Dictionary = _b.save.get_section(&"progress")
	progress.by_lang.pl = SaveSchema.LANGUAGE_STATE.duplicate(true)
	assert_eq(_b.save.set_section(&"progress", progress), OK)
	assert_eq(_b.save.flush(), OK)
	assert_eq(
		_b.economy.completion_commands("pl", 1).size(), 1, "proof denies repeated global onboarding"
	)


func test_historical_global_or_other_language_hint_unlock_denies_retroactive_grant() -> void:
	_b.config.overrides["unlocks.hint_slot"] = 2
	var progress: Dictionary = _b.save.get_section(&"progress")
	progress.by_lang["en"] = SaveSchema.LANGUAGE_STATE.duplicate(true)
	progress.by_lang.en.current_slot = 2
	progress.by_lang.en.highest_completed_slot = 1
	assert_eq(_b.save.set_section(&"progress", progress), OK)
	assert_eq(_b.save.flush(), OK)
	assert_eq(_request().economy_commands.size(), 1)
	assert_eq(_b.port.transact(_request()).error, OK)
	assert_eq(_b.economy.snapshot().items.hint, 0)
	assert_eq(_b.save.get_section(&"progress").by_lang.en.current_slot, 2)


func test_wrong_reward_commands_cannot_be_approved_by_economy() -> void:
	_board()
	for commands: Array in [
		[{"operation": "grant", "reason": "level_complete", "amounts": {"coins": 999}}],
		[{"operation": "grant", "reason": "bonus_chest", "amounts": {"coins": 100}}],
		[{"operation": "spend", "reason": "hint", "amounts": {"coins": 1}}],
		[{"operation": "grant", "reason": "rewarded_coins", "amounts": {"coins": 100}}]
	]:
		var batch: Array[Dictionary] = []
		batch.assign(commands)
		var request: Dictionary = _b.progress.completion_request(batch)
		var prepared: Dictionary = _prepare(request)
		assert_eq(prepared.progress.error, OK, "actual completed board is independently approved")
		assert_ne(prepared.economy.error, OK)
		assert_false(_b.economy.validates_prepared(prepared.economy, prepared.transaction))
		assert_eq(_b.save.abort_transaction(prepared.transaction), OK)
	assert_eq(_b.economy.snapshot().coins, 0)


func test_forged_modified_request_candidate_delta_or_handles_reject_without_writes() -> void:
	var original: Dictionary = _request()
	for field: String in ["progress_candidate", "delta"]:
		var changed: Dictionary = original.duplicate(true)
		changed[field].stars = 2
		assert_eq(_b.port.transact(changed).state, "rejected")
	var prepared: Dictionary = _prepare(original)
	var forged: ProgressPrepared = ProgressPrepared.new()
	forged.error = OK
	assert_eq(_b.economy.prepare_commands(prepared.transaction, forged).error, ERR_INVALID_DATA)
	assert_false(_b.progress.validates_prepared(forged, prepared.transaction))
	var wallet: EconomyPrepared = EconomyPrepared.new()
	wallet.error = OK
	assert_false(_b.economy.validates_prepared(wallet, prepared.transaction))
	assert_eq(
		_b.save.commit_transaction(prepared.transaction, prepared.progress, wallet).error,
		ERR_INVALID_DATA
	)
	assert_eq(_b.save.abort_transaction(prepared.transaction), OK)
	assert_eq(_b.economy.snapshot().coins, 0)


func test_stale_config_content_language_or_board_invalidates_owner_preparation() -> void:
	var request: Dictionary = _request()
	var prepared: Dictionary = _prepare(request)
	_b.config.overrides["economy.reward.level_complete"] = 26
	assert_false(_b.economy.validates_prepared(prepared.economy, prepared.transaction))
	_b.config.overrides.erase("economy.reward.level_complete")
	_b.config.overrides["meta.postcard.piece_star_cost"] = 1
	assert_false(_b.progress.validates_prepared(prepared.progress, prepared.transaction))
	_b.config.overrides.erase("meta.postcard.piece_star_cost")
	assert_true(_b.progress.validates_prepared(prepared.progress, prepared.transaction))
	assert_eq(_b.save.abort_transaction(prepared.transaction), OK)
	assert_eq(_b.save.set_setting(&"language", "en"), OK)
	assert_false(_b.port.is_available())
	assert_eq(_b.port.transact(request).error, ERR_UNAVAILABLE)


func test_unbound_or_incomplete_board_cannot_issue_an_intent() -> void:
	assert_eq(_b.progress.completion_request(NO_COMMANDS), {})
	var board: BoardState = BoardState.new(_b.content.level_for_slot(1))
	assert_eq(_b.progress.bind_board(board), OK)
	assert_eq(_b.progress.completion_request(NO_COMMANDS), {})
	var request: Dictionary = _request()
	_b.progress.unbind_board()
	assert_eq(_b.port.transact(request).error, OK, "approved intent retains its completed board")
	assert_eq(_b.economy.snapshot().coins, 25)


func test_each_checkpoint_restart_exposes_old_or_one_whole_operation() -> void:
	for checkpoint: StringName in [
		&"temp_opened", &"temp_written", &"temp_flushed", &"backup_rotated", &"primary_promoted"
	]:
		_clean()
		var storage: InterruptedStorage = InterruptedStorage.new(PATH)
		_b = _bundle(storage)
		var request: Dictionary = _request()
		storage.stop_at = checkpoint
		var result: Dictionary = _b.port.transact(request)
		var success: bool = checkpoint in [&"backup_rotated", &"primary_promoted"]
		assert_eq(result.error, OK if success else ERR_BUSY)
		var restarted: Dictionary = _bundle()
		assert_eq(restarted.economy.snapshot().coins, 25 if success else 0)
		assert_eq(restarted.progress.current_slot(), 2 if success else 1)
		assert_eq(restarted.save.get_section(&"meta").atomic.processed.size(), 1 if success else 0)
		storage.stop_at = &""
		if not success:
			assert_eq(_recover(request).state, "pending")
			assert_eq(_b.port.transact(request).error, OK)
		assert_eq(_b.economy.snapshot().coins, 25)
		assert_eq(_recover(request).state, "replayed")


func test_pending_request_rejects_other_requests_and_independent_writes() -> void:
	_clean()
	var storage: InterruptedStorage = InterruptedStorage.new(PATH)
	_b = _bundle(storage)
	var request: Dictionary = _request()
	storage.stop_at = &"temp_flushed"
	assert_eq(_b.port.transact(request).state, "pending")
	var other: Dictionary = request.duplicate(true)
	other.economy_commands[0].amounts.coins = 26
	assert_eq(_b.port.transact(other).error, ERR_BUSY)
	assert_eq(_b.economy.grant(&"other", {"coins": 1}), ERR_BUSY)
	assert_eq(_b.save.debug_reset(), ERR_BUSY)
	assert_eq(_b.save.set_setting(&"language", "en"), ERR_BUSY)
	assert_eq(_b.economy.snapshot().coins, 0)
	storage.stop_at = &""
	assert_eq(_b.port.transact(request).error, OK)
	assert_eq(_b.economy.snapshot().coins, 25)


func test_callbacks_cannot_reenter_and_values_are_published_before_events() -> void:
	var request: Dictionary = _request()
	_b.events.economy_changed.connect(
		func(
			_operation: StringName, _reason: StringName, amounts: Dictionary, wallet: Dictionary
		) -> void:
			assert_eq(_b.progress.current_slot(), 2)
			assert_eq(_b.economy.snapshot().coins, 25)
			assert_eq(_b.port.transact(request).error, ERR_BUSY)
			assert_eq(_b.economy.grant(&"nested", {"coins": 1}), ERR_BUSY)
			assert_eq(_b.save.set_setting(&"language", "en"), ERR_BUSY)
			amounts.coins = 999
			wallet.coins = 999
	)
	assert_eq(_b.port.transact(request).error, OK)
	assert_eq(_b.economy.snapshot().coins, 25)
	assert_eq(_b.economy.journal()[0].amounts.coins, 25)


func test_receipt_forgery_reset_and_manual_duplicate_publication() -> void:
	watch_signals(_b.events)
	var request: Dictionary = _request()
	var receipt: Dictionary = _b.port.transact(request).receipt
	assert_eq(_b.economy.accept_commit(receipt), OK)
	assert_signal_emit_count(_b.events, "economy_changed", 1)
	var fake: Dictionary = receipt.duplicate(true)
	fake.notifications[0].amounts.coins = 999
	assert_eq(_b.economy.accept_commit(fake), ERR_INVALID_DATA)
	assert_eq(_b.save.debug_reset(), OK)
	assert_eq(_b.economy.accept_commit(receipt), ERR_INVALID_DATA)
	assert_eq(_recover(request).state, "rejected")
	assert_eq(_b.economy.snapshot().coins, 0)


func test_restart_recovers_proof_without_reapplying_money_and_copies_views() -> void:
	var request: Dictionary = _request()
	assert_eq(_b.port.transact(request).error, OK)
	var restarted: Dictionary = _bundle()
	var result: Dictionary = _recover(request, restarted)
	assert_eq(result.state, "replayed")
	assert_eq(restarted.economy.snapshot().coins, 25)
	result.snapshot.stars = 999
	result.receipt.economy_snapshot.coins = 999
	assert_eq(restarted.port.read_committed("pl", _read_context(restarted)).snapshot.stars, 1)
	assert_eq(_recover(request, restarted).receipt.economy_snapshot.coins, 25.0)


func test_semantically_incompatible_v4_remains_p1_with_original_file() -> void:
	var original: Dictionary = SaveSchema.canonical(SaveStorage.new(PATH).read_document())
	for change: Callable in [
		func(d: Dictionary) -> void: d.progress.by_lang.pl.highest_completed_slot = 1,
		func(d: Dictionary) -> void: d.progress.by_lang.pl.completed_slot = 1,
		func(d: Dictionary) -> void: d.progress.by_lang.pl.current_slot = 9,
		func(d: Dictionary) -> void: d.progress.by_lang.pl.postcards = ["campaign"],
		func(d: Dictionary) -> void:
			d.progress.by_lang.pl.stars = 1
			d.progress.by_lang.pl.location_stars = {"campaign": 1}
	]:
		var document: Dictionary = original.duplicate(true)
		change.call(document)
		_clean()
		_write(document)
		var b: Dictionary = _bundle()
		assert_false(b.port.is_available())
		assert_eq(b.port.read_committed("pl", _read_context(b)).state, "needs_migration")
		assert_eq_deep(SaveSchema.canonical(SaveStorage.new(PATH).read_document()), document)
		assert_eq(b.save.set_setting(&"haptics_enabled", false), OK)
		assert_false(b.progress.p2_ready())


func test_v3_collision_preserves_p1_and_real_port_fails_closed() -> void:
	_clean()
	var document: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/save/v3.json")
	)
	document.meta.atomic = "legacy-extension"
	_write(document)
	_b = _bundle()
	assert_false(_b.port.is_available())
	assert_eq(_b.port.read_committed("pl", _read_context()).state, "needs_migration")
	assert_eq(_b.save.get_section(&"meta").atomic, "legacy-extension")
	assert_eq(_b.save.set_setting(&"haptics_enabled", false), OK)
	assert_eq(_b.save.get_section(&"meta").atomic, "legacy-extension")
	assert_eq(SaveStorage.new(PATH).read_document().schema_version, 3.0)


func test_missing_language_retired_credits_and_global_stars_are_lossless() -> void:
	var progress: Dictionary = _b.save.get_section(&"progress")
	progress.by_lang.pl.stars = 7
	progress.by_lang.pl.location_pieces = {"retired-place": 8}
	progress.by_lang.pl.postcards = ["retired-card"]
	progress.by_lang.pl.unlocked = ["retired-feature"]
	progress.by_lang.pl["extension"] = {"keep": [1]}
	progress.by_lang["en"] = SaveSchema.LANGUAGE_STATE.duplicate(true)
	progress.by_lang.en.stars = 5
	assert_eq(_b.save.set_section(&"progress", progress), OK)
	assert_eq(_b.save.flush(), OK)
	assert_eq(_b.port.read_committed("pl", _read_context()).snapshot.location_stars, {})
	assert_eq(_b.port.transact(_request()).error, OK)
	var state: Dictionary = _b.save.get_section(&"progress").by_lang.pl
	assert_eq(state.stars, 8)
	assert_eq(state.location_stars, {"campaign": 1})
	assert_eq(state.location_pieces["retired-place"], 8)
	assert_true(state.postcards.has("retired-card"))
	assert_true(state.unlocked.has("retired-feature"))
	assert_eq(state.extension, {"keep": [1]})
	assert_eq(_b.save.get_section(&"progress").by_lang.en.stars, 5)
	progress = _b.save.get_section(&"progress")
	progress.by_lang.erase("pl")
	assert_eq(_b.save.set_section(&"progress", progress), OK)
	assert_eq(_b.save.flush(), OK)
	var primary: String = FileAccess.get_file_as_string(PATH)
	assert_eq(_b.port.read_committed("pl", _read_context()).snapshot.current_slot, 1)
	assert_eq(FileAccess.get_file_as_string(PATH), primary)
	assert_false(_b.save.get_section(&"progress").by_lang.has("pl"))


func test_independent_grant_spend_use_shared_builder_without_activating_p2() -> void:
	assert_eq(_b.economy.grant(&"earned", {"coins": 100, "hint": 2}), OK)
	assert_true(_b.economy.spend(&"hint", {"coins": 25, "hint": 1}))
	assert_eq(_b.economy.snapshot().coins, 75)
	assert_eq(_b.economy.snapshot().items.hint, 1)
	assert_eq(_b.economy.journal().size(), 2)
	assert_eq(_b.economy.journal()[0].timestamp, 1790942400)
	assert_false(_b.progress.p2_ready())
	assert_eq(_b.progress.configure_p2(_b.config, _b.port, _b.events), OK)
	assert_eq_deep(_b.progress.language_progress(), ProgressSnapshot.new().snapshot())
	assert_false(ProgressCommitPort.new().is_available())


func test_zero_configured_rewards_produce_valid_empty_batch() -> void:
	_b.config.overrides["economy.reward.level_complete"] = 0
	watch_signals(_b.events)
	var request: Dictionary = _request()
	assert_eq(request.economy_commands, [])
	assert_eq(_b.port.transact(request).error, OK)
	assert_eq(_b.economy.snapshot().coins, 0)
	assert_eq(_b.economy.journal(), [])
	assert_signal_not_emitted(_b.events, "economy_changed")


func test_unavailable_default_wrong_bindings_and_closed_contexts() -> void:
	var unconfigured: AtomicProgressPort = AtomicProgressPort.new()
	assert_false(unconfigured.is_available())
	assert_eq(unconfigured.read_committed("pl", {}).state, "unavailable")
	assert_eq(unconfigured.transact({}).error, ERR_INVALID_PARAMETER)
	assert_eq(_b.port.configure(_b.save, _b.progress, _b.economy), ERR_ALREADY_IN_USE)
	assert_eq(_b.port.read_committed("pl", {}).error, ERR_UNAVAILABLE)
	var context: Dictionary = _read_context()
	context.content_version = 1.0
	assert_eq(_b.port.read_committed("pl", context).error, ERR_UNAVAILABLE)
	assert_eq(_b.port.recover("id", {}).error, ERR_INVALID_PARAMETER)
	assert_eq(_b.port.recover("id", {"request_hash": "bad"}).error, ERR_INVALID_PARAMETER)


func _alternate_manifest() -> Dictionary:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(FIXTURE.path_join("pl/manifest.json"))
	)
	DirAccess.make_dir_recursive_absolute(CONTENT_ROOT.path_join("pl/packs"))
	var pack: FileAccess = FileAccess.open(
		CONTENT_ROOT.path_join("pl/packs/c-0001-0003.json"), FileAccess.WRITE
	)
	pack.store_buffer(FileAccess.get_file_as_bytes(FIXTURE.path_join("pl/packs/c-0001-0003.json")))
	pack.close()
	return manifest


func _write_manifest(manifest: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(
		CONTENT_ROOT.path_join("pl/manifest.json"), FileAccess.WRITE
	)
	file.store_string(JSON.stringify(manifest, "", true, true))
	file.close()


func test_manifest_fingerprint_tracks_accepted_bytes_and_failed_load_keeps_identity() -> void:
	assert_eq(
		_b.content.manifest_hash(), FileAccess.get_sha256(FIXTURE.path_join("pl/manifest.json"))
	)
	var prior: String = _b.content.manifest_hash()
	var manifest: Dictionary = _alternate_manifest()
	manifest.lang = "other"
	_write_manifest(manifest)
	assert_eq(_b.content.load_manifest("pl", CONTENT_ROOT), ERR_INVALID_DATA)
	assert_eq(_b.content.manifest_hash(), prior)
	assert_eq(_b.content.content_version(), 1)
	manifest.lang = "pl"
	manifest.content_version = 2
	_write_manifest(manifest)
	assert_eq(_b.content.load_manifest("pl", CONTENT_ROOT), OK)
	assert_eq(
		_b.content.manifest_hash(),
		FileAccess.get_sha256(CONTENT_ROOT.path_join("pl/manifest.json"))
	)
	assert_ne(_b.content.manifest_hash(), prior)


func test_manifest_or_live_board_change_invalidates_same_lease_without_grants() -> void:
	var board: BoardState = _board()
	var request: Dictionary = _b.progress.completion_request(
		_b.economy.completion_commands("pl", 1)
	)
	var prepared: Dictionary = _prepare(request)
	board.evaluate(PackedInt32Array([2, 1, 0]))
	assert_false(_b.progress.validates_prepared(prepared.progress, prepared.transaction))
	assert_eq(_b.save.abort_transaction(prepared.transaction), OK)
	request = _request()
	prepared = _prepare(request)
	var manifest: Dictionary = _alternate_manifest()
	manifest.content_version = 2
	_write_manifest(manifest)
	assert_eq(_b.content.load_manifest("pl", CONTENT_ROOT), OK)
	assert_false(_b.progress.validates_prepared(prepared.progress, prepared.transaction))
	assert_eq(
		_b.save.commit_transaction(prepared.transaction, prepared.progress, prepared.economy).error,
		ERR_INVALID_DATA
	)
	assert_eq(_b.save.abort_transaction(prepared.transaction), OK)
	assert_eq(_b.economy.snapshot().coins, 0)


func test_wrong_concrete_owner_approval_is_not_adopted() -> void:
	var board: BoardState = _board()
	var commands: Array[Dictionary] = _b.economy.completion_commands("pl", 1)
	var request: Dictionary = _b.progress.completion_request(commands)
	var other: PROGRESS = PROGRESS.new()
	add_child_autofree(other)
	other.configure(_b.save, _b.content)
	assert_eq(other.configure_atomic(_b.config), OK)
	assert_eq(other.bind_board(board), OK)
	assert_eq_deep(other.completion_request(commands), request)
	var prepared: Dictionary = _prepare(request)
	var wrong: ProgressPrepared = other.prepare_completion(prepared.transaction)
	assert_eq(wrong.error, OK)
	assert_false(_b.save.validates_progress(wrong, prepared.transaction))
	assert_eq(_b.economy.prepare_commands(prepared.transaction, wrong).error, ERR_INVALID_DATA)
	assert_eq(_b.save.abort_transaction(prepared.transaction), OK)


func test_real_independent_pending_grant_is_not_adopted_or_discarded() -> void:
	_clean()
	var storage: InterruptedStorage = InterruptedStorage.new(PATH)
	_b = _bundle(storage)
	storage.stop_at = &"temp_flushed"
	assert_eq(_b.economy.grant(&"earned", {"coins": 1}), ERR_BUSY)
	var request: Dictionary = _request()
	assert_eq(_b.port.transact(request).error, ERR_BUSY)
	assert_eq(_b.economy.snapshot().coins, 0)
	storage.stop_at = &""
	assert_eq(_b.economy.grant(&"earned", {"coins": 1}), OK)
	assert_eq(_b.economy.snapshot().coins, 1)
	assert_eq(_b.port.transact(_request()).error, OK)
	assert_eq(_b.economy.snapshot().coins, 26)


func test_v3_lossless_upgrade_read_has_no_grants_or_implicit_persistence() -> void:
	_clean()
	var source: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/save/v3.json")
	)
	source["root_extension"] = {"keep": [1]}
	source.economy.bonus_counter = 7
	source.economy["owner_extension"] = {"keep": true}
	_write(source)
	_b = _bundle()
	var primary: String = FileAccess.get_file_as_string(PATH)
	var result: Dictionary = _b.port.read_committed("pl", _read_context())
	assert_eq(result.error, OK)
	assert_eq(result.snapshot.location_stars, {})
	assert_eq(_b.economy.snapshot().coins, 0)
	assert_eq(FileAccess.get_file_as_string(PATH), primary)
	assert_eq(
		_b.port.transact(_request()).error, ERR_BUSY, "dirty migration is not another owner's proof"
	)
	assert_eq(_b.save.flush(), OK)
	assert_eq(_b.port.transact(_request()).error, OK)
	assert_eq(_b.save.get_section(&"economy").bonus_counter, 7)
	assert_eq(_b.save.get_section(&"economy").owner_extension, {"keep": true})
	assert_eq(SaveStorage.new(PATH).read_document().root_extension, {"keep": [1.0]})


func test_unknown_reads_recover_later_without_forgetting_pending_handles() -> void:
	_clean()
	var storage: InterruptedStorage = InterruptedStorage.new(PATH)
	_b = _bundle(storage)
	var request: Dictionary = _request()
	storage.stop_at = &"temp_flushed"
	assert_eq(_b.port.transact(request).state, "pending")
	storage.invisible = true
	assert_eq(_recover(request).error, ERR_UNAVAILABLE)
	assert_eq(_b.economy.snapshot().coins, 0)
	storage.invisible = false
	storage.stop_at = &""
	_b.progress.unbind_board()
	assert_eq(_b.port.transact(request).error, OK)
	assert_eq(_b.economy.snapshot().coins, 25)


func test_failed_publication_is_durable_and_recover_can_publish_later_once() -> void:
	_clean()
	var losing: LosingEconomy = LosingEconomy.new()
	_b = _bundle(null, losing)
	watch_signals(_b.events)
	var request: Dictionary = _request()
	assert_eq(_b.port.transact(request).error, OK)
	assert_eq(_b.economy.snapshot().coins, 25)
	assert_signal_not_emitted(_b.events, "economy_changed")
	losing.lose = false
	assert_eq(_recover(request).error, OK)
	assert_eq(_recover(request).error, OK)
	assert_eq(_b.economy.snapshot().coins, 25)
	assert_signal_emit_count(_b.events, "economy_changed", 1)
