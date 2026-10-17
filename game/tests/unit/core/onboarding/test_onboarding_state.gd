extends GutTest


func test_closed_validation_and_deep_copy() -> void:
	for value: Dictionary in [
		{},
		{"step": 0},
		{"step": -1, "seen": []},
		{"step": 1.5, "seen": []},
		{"step": true, "seen": []},
		{"step": INF, "seen": []},
		{"step": 0, "seen": ["a", "a"]},
		{"step": 0, "seen": [""]},
		{"step": 0, "seen": [" hint"]},
		{"step": 0, "seen": [1]},
		{"step": 0, "seen": [], "extra": true}
	]:
		assert_null(OnboardingState.from_dict(value))
	var source: Dictionary = {"step": 0, "seen": ["legacy"]}
	var state: OnboardingState = OnboardingState.from_dict(source)
	source.seen.clear()
	var copy: Dictionary = state.snapshot()
	copy.seen.clear()
	assert_eq(state.snapshot().seen, ["legacy"])
	assert_false(state.tutorial_complete())


func test_tutorial_monotonic_and_unknown_history_preserved() -> void:
	var state: OnboardingState = OnboardingState.from_dict({"step": 0, "seen": ["old"]})
	assert_null(state.after_coach(&"hint"))
	var taught: OnboardingState = state.after_tutorial()
	assert_true(taught.tutorial_complete())
	assert_false(state.tutorial_complete())
	assert_eq(taught.snapshot().step, 1)
	assert_eq(taught.snapshot().seen, ["old"])
	assert_eq_deep(taught.after_tutorial().snapshot(), taught.snapshot())
	var historic: OnboardingState = OnboardingState.from_dict({"step": 100, "seen": ["old"]})
	assert_eq(historic.after_tutorial().snapshot().step, 100)
	assert_eq(historic.after_coach(&"shuffle").snapshot().step, 100)


func test_once_flags_and_out_of_order_coaches() -> void:
	var state: OnboardingState = OnboardingState.from_dict({"step": 1, "seen": []})
	assert_null(state.after_coach(&"tutorial"))
	assert_null(state.after_coach(&"unknown"))
	state = state.after_coach(&"reveal")
	assert_eq(state.snapshot().step, 6)
	state = state.after_coach(&"shuffle")
	assert_eq(state.snapshot().step, 6)
	assert_true(state.has_seen(&"shuffle"))
	assert_eq(state.snapshot().seen, ["reveal", "shuffle"])
	assert_eq_deep(state.after_coach(&"shuffle").snapshot(), state.snapshot())


func test_inconsistent_legacy_seen_flag_is_never_shown_or_counted_again() -> void:
	var state: OnboardingState = OnboardingState.from_dict({"step": 1, "seen": ["reveal"]})
	assert_eq_deep(state.after_coach(&"reveal").snapshot(), state.snapshot())
	assert_null(OnboardingState.from_dict({"step": 9007199254740992.0, "seen": []}))
