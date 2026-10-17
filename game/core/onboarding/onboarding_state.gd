class_name OnboardingState
extends RefCounted
## Immutable teaching history; presentation and persistence belong to callers.

const STEPS: Dictionary[StringName, int] = {
	&"tutorial": 1, &"shuffle": 2, &"bonus": 3, &"hint": 4, &"journey": 5, &"reveal": 6
}
var _step: int = 0
var _seen: Array[String] = []


static func from_dict(value: Dictionary) -> OnboardingState:
	if value.size() != 2 or not value.has("step") or not value.has("seen"):
		return null
	if (
		not (value.step is int or value.step is float)
		or not is_finite(float(value.step))
		or value.step < 0
		or value.step > ProgressSnapshot.MAX_SAFE_COUNT
		or int(value.step) > ProgressSnapshot.MAX_SAFE_COUNT
		or floorf(float(value.step)) != float(value.step)
	):
		return null
	if not ProgressSnapshot.valid_ids(value.seen):
		return null
	var state: OnboardingState = OnboardingState.new()
	state._step = int(value.step)
	state._seen.assign(value.seen)
	return state


func snapshot() -> Dictionary:
	return {"step": _step, "seen": _seen.duplicate()}


func tutorial_complete() -> bool:
	return _step >= STEPS[&"tutorial"]


func has_seen(feature: StringName) -> bool:
	return str(feature) in _seen


func after_tutorial() -> OnboardingState:
	var next: Dictionary = snapshot()
	next.step = maxi(_step, STEPS[&"tutorial"])
	return from_dict(next)


func after_coach(feature: StringName) -> OnboardingState:
	if not tutorial_complete() or feature == &"tutorial" or not STEPS.has(feature):
		return null
	if has_seen(feature):
		return from_dict(snapshot())
	var next: Dictionary = snapshot()
	next.seen.append(str(feature))
	next.step = maxi(_step, STEPS[feature])
	return from_dict(next)
