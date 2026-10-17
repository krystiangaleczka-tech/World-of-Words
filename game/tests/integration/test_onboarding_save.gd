# gdlint: disable=max-public-methods
extends GutTest

const SAVE: Script = preload("res://services/save.gd")
const BUS: Script = preload("res://services/events.gd")
const FIXTURE: Script = preload("res://tests/integration/test_level_hud.gd")
const DISK: Script = preload("res://tests/integration/test_paid_tool_transactions.gd")
const PATH: String = "user://t0290-onboarding.json"
var save: SAVE
var bus: BUS
var storage: FIXTURE.MemoryStorage


func before_each() -> void:
	clean()
	storage = FIXTURE.MemoryStorage.new()
	save = make_save(storage)
	bus = BUS.new()
	add_child_autofree(bus)
	assert_eq(save.configure_onboarding(bus), OK)


func after_each() -> void:
	clean()


func clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)


func make_save(disk: SaveStorage) -> SAVE:
	var owner: SAVE = SAVE.new()
	add_child_autofree(owner)
	owner.initialize(DISK.FixedClock.new())
	owner.configure(disk, func() -> String: return "12345678-1234-4234-8234-123456789abc")
	assert_eq(owner.load(), OK)
	return owner


func test_opt_in_and_invalid_intents_never_write() -> void:
	var unbound: SAVE = make_save(FIXTURE.MemoryStorage.new())
	assert_eq(unbound.complete_tutorial(), ERR_UNCONFIGURED)
	assert_eq(save.configure_onboarding(null), ERR_UNCONFIGURED)
	var before: Dictionary = save.committed_view()
	assert_eq(save.mark_coach_seen(&"hint"), ERR_UNAVAILABLE)
	assert_eq(save.mark_coach_seen(&"tutorial"), ERR_INVALID_PARAMETER)
	assert_eq(save.mark_coach_seen(&"unknown"), ERR_INVALID_PARAMETER)
	assert_eq(save.retry_onboarding(), ERR_DOES_NOT_EXIST)
	assert_eq_deep(save.committed_view(), before)


func test_each_new_action_once_and_action_step_not_historical_maximum() -> void:
	watch_signals(bus)
	assert_eq(save.complete_tutorial(), OK)
	assert_signal_emitted_with_parameters(bus, "onboarding_step", [1])
	for feature: StringName in [&"reveal", &"shuffle", &"bonus", &"hint", &"journey"]:
		assert_eq(save.mark_coach_seen(feature), OK)
		assert_signal_emitted_with_parameters(
			bus, "onboarding_step", [OnboardingState.STEPS[feature]]
		)
		var revision: int = save.committed_view().revision
		assert_eq(save.mark_coach_seen(feature), OK)
		assert_eq(save.committed_view().revision, revision)
	assert_eq(save.onboarding_snapshot().step, 6)
	assert_signal_emit_count(bus, "onboarding_step", 6)
	var revision: int = save.committed_view().revision
	assert_eq(save.complete_tutorial(), OK)
	assert_eq(save.committed_view().revision, revision)
	var copy: Dictionary = save.onboarding_snapshot()
	copy.seen.clear()
	assert_eq(save.onboarding_snapshot().seen.size(), 5)


func test_failed_write_hides_metadata_rejects_replacement_and_retries_once() -> void:
	watch_signals(bus)
	storage.fail = true
	assert_eq(save.complete_tutorial(), ERR_FILE_CANT_WRITE)
	assert_eq(save.onboarding_snapshot().step, 0)
	assert_signal_not_emitted(bus, "onboarding_step")
	assert_eq(save.mark_coach_seen(&"shuffle"), ERR_BUSY)
	assert_eq(save.configure_onboarding(bus), ERR_BUSY)
	storage.fail = false
	assert_eq(save.retry_onboarding(), OK)
	assert_eq(save.onboarding_snapshot().step, 1)
	assert_signal_emit_count(bus, "onboarding_step", 1)
	assert_eq(save.retry_onboarding(), ERR_DOES_NOT_EXIST)


func test_unrelated_flush_commits_pending_metadata_preserving_other_sections() -> void:
	storage.fail = true
	assert_ne(save.complete_tutorial(), OK)
	var economy: Dictionary = save.get_section(&"economy")
	economy.coins = 42
	assert_eq(save.set_section(&"economy", economy), OK)
	watch_signals(bus)
	storage.fail = false
	assert_eq(save.flush(), OK)
	assert_eq(save.onboarding_snapshot().step, 1)
	assert_eq(save.committed_view().sections.economy.coins, 42)
	assert_signal_emit_count(bus, "onboarding_step", 1)
	assert_eq(save.retry_onboarding(), ERR_DOES_NOT_EXIST)


func test_committed_event_blocks_reentrant_owner_writes_and_commands() -> void:
	var results: Array[int] = []
	bus.onboarding_step.connect(
		func(_step: int) -> void:
			assert_true(save.writes_blocked())
			assert_eq(save.onboarding_snapshot().step, 1)
			results.append(save.complete_tutorial())
			results.append(save.mark_coach_seen(&"shuffle"))
			results.append(save.set_setting(&"high_contrast", true))
			results.append(save.set_section(&"economy", save.get_section(&"economy")))
			results.append(save.flush())
			results.append(save.configure_onboarding(bus))
			results.append(save.begin_transaction({}).error)
			results.append(save.commit_transaction(null, null, null).error)
			results.append(save.recover_transaction("invalid", "invalid").error)
			results.append(save.abort_transaction(null))
			results.append(save.publish_receipt({}))
	)
	assert_eq(save.complete_tutorial(), OK)
	assert_eq(
		results,
		[
			ERR_BUSY,
			ERR_BUSY,
			ERR_BUSY,
			ERR_BUSY,
			ERR_BUSY,
			ERR_BUSY,
			ERR_BUSY,
			ERR_BUSY,
			ERR_BUSY,
			ERR_BUSY,
			ERR_BUSY
		]
	)
	assert_false(save.writes_blocked())


func test_error_callback_cannot_replace_inflight_action() -> void:
	var results: Array[int] = []
	save.flush_failed.connect(
		func(_error: Error) -> void:
			results.append(save.complete_tutorial())
			results.append(save.mark_coach_seen(&"shuffle"))
	)
	storage.fail = true
	assert_ne(save.complete_tutorial(), OK)
	assert_eq(results, [ERR_BUSY, ERR_BUSY])


func test_restart_preserves_history_without_replaying_side_effects() -> void:
	assert_eq(save.complete_tutorial(), OK)
	assert_eq(save.mark_coach_seen(&"reveal"), OK)
	var before: Dictionary = save.committed_view().sections
	var again: SAVE = make_save(storage)
	watch_signals(bus)
	assert_eq(again.configure_onboarding(bus), OK)
	assert_eq(again.complete_tutorial(), OK)
	assert_eq(again.mark_coach_seen(&"reveal"), OK)
	assert_eq_deep(again.committed_view().sections, before)
	assert_signal_not_emitted(bus, "onboarding_step")


func test_every_disk_interruption_retries_and_fresh_owner_keeps_once_flags() -> void:
	for checkpoint: StringName in [
		&"temp_opened", &"temp_written", &"temp_flushed", &"backup_rotated", &"primary_promoted"
	]:
		clean()
		var disk: DISK.InterruptedStorage = DISK.InterruptedStorage.new(PATH)
		var owner: SAVE = make_save(disk)
		assert_eq(owner.configure_onboarding(bus), OK)
		disk.stop_at = checkpoint
		assert_ne(owner.complete_tutorial(), OK)
		assert_eq(owner.onboarding_snapshot().step, 0)
		disk.stop_at = &""
		clear_signal_watcher()
		watch_signals(bus)
		var probe: SAVE = make_save(SaveStorage.new(PATH))
		assert_eq(probe.configure_onboarding(bus), OK)
		assert_true(probe.onboarding_snapshot().step in [0, 1])
		assert_signal_not_emitted(bus, "onboarding_step")
		assert_eq(owner.retry_onboarding(), OK)
		assert_eq(owner.mark_coach_seen(&"hint"), OK)
		var again: SAVE = make_save(SaveStorage.new(PATH))
		clear_signal_watcher()
		watch_signals(bus)
		assert_eq(again.configure_onboarding(bus), OK)
		assert_eq(again.complete_tutorial(), OK)
		assert_eq(again.mark_coach_seen(&"hint"), OK)
		assert_eq(again.onboarding_snapshot().step, 4)
		assert_eq(again.onboarding_snapshot().seen, ["hint"])
		assert_signal_not_emitted(bus, "onboarding_step")


func test_unrelated_save_notification_cannot_start_reentrant_onboarding() -> void:
	var results: Array[int] = []
	save.setting_changed.connect(
		func(_key: StringName) -> void: results.append(save.complete_tutorial())
	)
	assert_eq(save.set_setting(&"high_contrast", true), OK)
	assert_eq(results, [ERR_BUSY])
	assert_eq(save.onboarding_snapshot().step, 0)
	assert_eq(save.complete_tutorial(), OK)


func test_unknown_history_and_all_other_owner_sections_survive() -> void:
	var disk: FIXTURE.MemoryStorage = FIXTURE.MemoryStorage.new()
	disk.document.meta.onboarding_step = 100
	disk.document.meta.coach_marks_seen = ["retired", "hint"]
	disk.document.meta["extension"] = {"kept": true}
	var owner: SAVE = make_save(disk)
	assert_eq(owner.configure_onboarding(bus), OK)
	var before: Dictionary = owner.committed_view().sections
	watch_signals(bus)
	assert_eq(owner.mark_coach_seen(&"shuffle"), OK)
	assert_signal_emitted_with_parameters(bus, "onboarding_step", [2])
	assert_eq(owner.onboarding_snapshot().step, 100)
	assert_eq(owner.onboarding_snapshot().seen, ["retired", "hint", "shuffle"])
	for section: String in ["settings", "economy", "progress", "daily", "monetization"]:
		assert_eq_deep(owner.committed_view().sections[section], before[section])
	assert_eq_deep(owner.committed_view().sections.meta.extension, {"kept": true})
	assert_eq(owner.committed_view().sections.meta.install_id, before.meta.install_id)


func test_active_atomic_lease_blocks_onboarding_without_staging_metadata() -> void:
	var fixture: Script = load("res://tests/integration/test_save_atomic.gd")
	var owner: SAVE = SAVE.new()
	add_child_autofree(owner)
	owner.initialize(DISK.FixedClock.new())
	owner.configure(FIXTURE.MemoryStorage.new())
	var progress: AtomicSaveOwner = fixture.TestProgress.new()
	var economy: AtomicSaveOwner = fixture.TestEconomy.new()
	add_child_autofree(progress)
	add_child_autofree(economy)
	progress.set("save", owner)
	economy.set("save", owner)
	progress.configure(owner, null)
	economy.configure(owner, null, null)
	assert_eq(owner.configure_atomic(progress, economy), OK)
	assert_eq(owner.load(), OK)
	assert_eq(owner.configure_onboarding(bus), OK)
	var domain: Dictionary = ProgressSaveAdapter.domain(owner.get_section(&"progress").by_lang.pl)
	var candidate: Dictionary = domain.duplicate(true)
	candidate.current_slot = 2
	candidate.stars = 1
	var request: Dictionary = {
		"operation_id": "campaign_complete:pl:1",
		"kind": "campaign_complete",
		"language": "pl",
		"context":
		{
			"content_version": 1,
			"manifest_hash": "a".repeat(64),
			"level_id": "pl-test",
			"slot": 1,
			"expected_current_slot": 1,
			"expected_highest_completed_slot": 0,
			"board_hash": "b".repeat(64),
			"expected_progress_hash": AtomicRequest.hash_value(domain)
		},
		"progress_candidate": candidate,
		"economy_commands":
		[{"operation": "grant", "reason": "level_complete", "amounts": {"coins": 1}}],
		"delta": {"stars": 1}
	}
	var begun: Dictionary = owner.begin_transaction(request)
	assert_eq(begun.error, OK)
	assert_eq(owner.complete_tutorial(), ERR_BUSY)
	assert_eq(owner.onboarding_snapshot().step, 0)
	assert_eq(owner.abort_transaction(begun.transaction), OK)
	assert_eq(owner.complete_tutorial(), OK)
