class_name OnboardingState
extends RefCounted
## @api Once-only tutorial and coach-mark progress. Save owns persistence in its meta section;
## every newly durable step emits Events.onboarding_step_reached exactly once.

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const EVENTS_SCRIPT: Script = preload("res://services/events.gd")
const FEATURES: Array[StringName] = [&"shuffle", &"bonus", &"hint", &"journey", &"reveal"]
const STEP_TUTORIAL_SHOWN: int = 1
const STEP_TUTORIAL_COMPLETE: int = 2
const FIRST_COACH_STEP: int = 3

var _save: SAVE_SCRIPT
var _events: EVENTS_SCRIPT
var _active: StringName = &""


## @api Step id of a coach mark (3.. in FEATURES order); 0 for unknown features.
static func coach_step(feature: StringName) -> int:
	var index: int = FEATURES.find(feature)
	return FIRST_COACH_STEP + index if index >= 0 else 0


## @api Translation key of the inline caption; empty for unknown features.
static func caption_key(feature: StringName) -> String:
	return "onboarding.coach.%s" % feature if feature in FEATURES else ""


## @api Inject Save and the event bus; no reads, writes or signals.
func configure(save: SAVE_SCRIPT, events: EVENTS_SCRIPT) -> void:
	_save = save
	_events = events
	_active = &""


## @api Teaching is permanently complete once step 2 is durable.
func tutorial_complete() -> bool:
	return _step() >= STEP_TUTORIAL_COMPLETE


## @api The hand first plays; later calls and reopen are no-ops.
func tutorial_shown() -> Error:
	return _reach(STEP_TUTORIAL_SHOWN)


## @api Only an accepted LEVEL/BONUS word solved by the player completes teaching.
## Hint, debug, invalid, already-found and cancelled attempts are rejected without a write.
func complete_tutorial(kind: AttemptResult.Kind, player_solved: bool) -> Error:
	if not player_solved or kind not in [AttemptResult.Kind.LEVEL, AttemptResult.Kind.BONUS]:
		return ERR_INVALID_PARAMETER
	return _reach(STEP_TUTORIAL_COMPLETE)


## @api Durable once-per-feature flag.
func coach_seen(feature: StringName) -> bool:
	if not _ready():
		return false
	return str(feature) in _save.onboarding_meta()["coach_marks_seen"]


## @api Eligible: known and unseen feature, visible target, no consent/completion feedback (busy)
## and no other coach mark showing. Callers queue an ineligible coach for the next moment.
func can_coach(feature: StringName, target_visible: bool, busy: bool) -> bool:
	return (
		_ready()
		and feature in FEATURES
		and not coach_seen(feature)
		and target_visible
		and not busy
		and _active.is_empty()
	)


## @api Persist the flag first, then emit the step. On failure nothing is shown or emitted.
func begin_coach(feature: StringName, target_visible: bool, busy: bool) -> Error:
	if not can_coach(feature, target_visible, busy):
		return ERR_UNAVAILABLE
	var error: Error = _save.mark_coach_seen(feature)
	if error != OK:
		return error
	_active = feature
	_events.onboarding_step_reached.emit(coach_step(feature))
	return OK


## @api Release the single coach slot after CoachMark.finished.
func end_coach(feature: StringName) -> void:
	if _active == feature:
		_active = &""


## @api The coach mark currently showing, or empty.
func active_coach() -> StringName:
	return _active


func _ready() -> bool:
	return is_instance_valid(_save) and is_instance_valid(_events) and _save.is_loaded()


func _step() -> int:
	return int(_save.onboarding_meta()["onboarding_step"]) if _ready() else 0


func _reach(step: int) -> Error:
	if not _ready():
		return ERR_UNCONFIGURED
	if _step() >= step:
		return OK
	var error: Error = _save.reach_onboarding_step(step)
	if error == OK:
		_events.onboarding_step_reached.emit(step)
	return error
