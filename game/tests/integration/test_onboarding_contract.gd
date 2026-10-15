extends GutTest

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")


class MemoryStorage:
	extends SaveStorage
	var document: Dictionary = SaveSchema.fresh(
		"12345678-1234-4234-8234-123456789abc", "2026-10-02T12:00:00Z", "0.1.0"
	)
	var fail: bool = false
	var writes: int = 0

	func read_document(_suffix: String = "") -> Dictionary:
		return document.duplicate(true)

	func has_any_file() -> bool:
		return true

	func commit(text: String, _rotate: bool) -> Error:
		writes += 1
		if fail:
			return ERR_FILE_CANT_WRITE
		document = JSON.parse_string(text)
		return OK


class Target:
	extends Control
	var highlighted: bool = false


var _steps: Array[int] = []


func before_each() -> void:
	_steps.clear()


func _record(step: int) -> void:
	_steps.append(step)


func _save(storage: MemoryStorage) -> SAVE_SCRIPT:
	var save: SAVE_SCRIPT = SAVE_SCRIPT.new()
	add_child_autofree(save)
	save.initialize(Clock.new())
	save.configure(storage)
	assert_eq(save.load(), OK)
	return save


func _state(save: SAVE_SCRIPT) -> OnboardingState:
	var bus: EVENTS_SCRIPT = EVENTS_SCRIPT.new()
	add_child_autofree(bus)
	bus.onboarding_step_reached.connect(_record)
	var state: OnboardingState = OnboardingState.new()
	state.configure(save, bus)
	return state


func test_unconfigured_state_fails_closed() -> void:
	var state: OnboardingState = OnboardingState.new()
	assert_false(state.tutorial_complete())
	assert_eq(state.tutorial_shown(), ERR_UNCONFIGURED)
	assert_false(state.can_coach(&"shuffle", true, false))
	assert_eq(state.begin_coach(&"shuffle", true, false), ERR_UNAVAILABLE)


func test_tutorial_completes_only_on_player_solved_level_or_bonus_word() -> void:
	var storage: MemoryStorage = MemoryStorage.new()
	var state: OnboardingState = _state(_save(storage))
	assert_eq(state.tutorial_shown(), OK)
	assert_eq(state.tutorial_shown(), OK)
	assert_eq(_steps, [OnboardingState.STEP_TUTORIAL_SHOWN])
	var writes: int = storage.writes
	for kind: AttemptResult.Kind in [AttemptResult.Kind.INVALID, AttemptResult.Kind.ALREADY_FOUND]:
		assert_eq(state.complete_tutorial(kind, true), ERR_INVALID_PARAMETER)
	assert_eq(state.complete_tutorial(AttemptResult.Kind.LEVEL, false), ERR_INVALID_PARAMETER)
	assert_eq(storage.writes, writes)
	assert_false(state.tutorial_complete())
	assert_eq(state.complete_tutorial(AttemptResult.Kind.BONUS, true), OK)
	assert_true(state.tutorial_complete())
	assert_eq(state.complete_tutorial(AttemptResult.Kind.LEVEL, true), OK)
	assert_eq(_steps, [OnboardingState.STEP_TUTORIAL_SHOWN, OnboardingState.STEP_TUTORIAL_COMPLETE])
	assert_eq(int(storage.document["meta"]["onboarding_step"]), 2)


func test_failed_write_keeps_old_state_and_retry_emits_once() -> void:
	var storage: MemoryStorage = MemoryStorage.new()
	var save: SAVE_SCRIPT = _save(storage)
	var state: OnboardingState = _state(save)
	storage.fail = true
	assert_eq(state.complete_tutorial(AttemptResult.Kind.LEVEL, true), ERR_FILE_CANT_WRITE)
	assert_false(state.tutorial_complete())
	assert_eq(state.begin_coach(&"shuffle", true, false), ERR_FILE_CANT_WRITE)
	assert_false(state.coach_seen(&"shuffle"))
	assert_eq(state.active_coach(), &"")
	assert_eq(_steps.size(), 0)
	storage.fail = false
	assert_eq(state.complete_tutorial(AttemptResult.Kind.LEVEL, true), OK)
	assert_eq(_steps, [OnboardingState.STEP_TUTORIAL_COMPLETE])


func test_coach_marks_are_once_per_feature_and_survive_restart() -> void:
	var storage: MemoryStorage = MemoryStorage.new()
	var state: OnboardingState = _state(_save(storage))
	assert_false(state.can_coach(&"shuffle", false, false))
	assert_false(state.can_coach(&"shuffle", true, true))
	assert_false(state.can_coach(&"unknown", true, false))
	assert_eq(state.begin_coach(&"shuffle", true, false), OK)
	assert_eq(state.active_coach(), &"shuffle")
	assert_false(state.can_coach(&"hint", true, false))
	state.end_coach(&"shuffle")
	assert_eq(state.begin_coach(&"shuffle", true, false), ERR_UNAVAILABLE)
	assert_eq(state.begin_coach(&"hint", true, false), OK)
	assert_eq(_steps, [OnboardingState.coach_step(&"shuffle"), OnboardingState.coach_step(&"hint")])
	var restarted: OnboardingState = _state(_save(storage))
	assert_true(restarted.coach_seen(&"shuffle"))
	assert_true(restarted.coach_seen(&"hint"))
	assert_false(restarted.coach_seen(&"reveal"))


func test_step_ids_and_caption_keys() -> void:
	assert_eq(OnboardingState.coach_step(&"shuffle"), 3)
	assert_eq(OnboardingState.coach_step(&"reveal"), 7)
	assert_eq(OnboardingState.coach_step(&"daily"), 0)
	assert_eq(OnboardingState.caption_key(&"bonus"), "onboarding.coach.bonus")
	assert_eq(OnboardingState.caption_key(&"daily"), "")


func test_save_meta_accessors_validate_and_copy() -> void:
	var save: SAVE_SCRIPT = _save(MemoryStorage.new())
	assert_eq(save.mark_coach_seen(&""), ERR_INVALID_PARAMETER)
	assert_eq(save.reach_onboarding_step(-1), ERR_INVALID_PARAMETER)
	var meta: Dictionary = save.onboarding_meta()
	meta["coach_marks_seen"].append("forged")
	meta["onboarding_step"] = 9
	assert_eq_deep(save.onboarding_meta(), {"coach_marks_seen": [], "onboarding_step": 0})


func test_coach_mark_highlights_and_any_tap_dismisses() -> void:
	var mark: CoachMark = CoachMark.new()
	var target: Target = Target.new()
	var caption: Label = Label.new()
	for node: Node in [mark, target, caption]:
		add_child_autofree(node)
	caption.visible = false
	watch_signals(mark)
	assert_eq(mark.show_mark(&"unknown", target, caption), ERR_INVALID_PARAMETER)
	assert_eq(mark.show_mark(&"hint", Control.new(), caption), ERR_INVALID_PARAMETER)
	assert_eq(mark.show_mark(&"hint", target, caption), OK)
	assert_eq(mark.show_mark(&"hint", target, caption), ERR_BUSY)
	assert_true(target.highlighted)
	assert_true(caption.visible)
	assert_eq(caption.text, "onboarding.coach.hint")
	var tap: InputEventScreenTouch = InputEventScreenTouch.new()
	tap.pressed = true
	mark._input(tap)
	assert_false(mark.is_showing())
	assert_false(target.highlighted)
	assert_false(caption.visible)
	assert_signal_emitted_with_parameters(mark, "finished", [&"hint"])
	mark.dismiss()
	assert_signal_emit_count(mark, "finished", 1)


func test_coach_mark_ends_after_double_toast_hold() -> void:
	var mark: CoachMark = CoachMark.new()
	var target: Target = Target.new()
	var caption: Label = Label.new()
	for node: Node in [mark, target, caption]:
		add_child_autofree(node)
	assert_eq(mark.show_mark(&"bonus", target, caption), OK)
	var hold: float = Tokens.Motion.TOAST_HOLD * 2 / 1000.0
	mark._process(hold - 0.01)
	assert_true(mark.is_showing())
	var release: InputEventScreenTouch = InputEventScreenTouch.new()
	release.pressed = false
	mark._input(release)
	assert_true(mark.is_showing())
	mark._process(0.02)
	assert_false(mark.is_showing())
	assert_false(target.highlighted)
