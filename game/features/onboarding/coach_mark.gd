class_name CoachMark
extends Node
## @api Coach mark = the target's existing highlighted state plus one inline caption.
## Any tap or Motion.TOAST_HOLD x 2 ends it. It never consumes input, adds no overlay or scene.

signal finished(feature: StringName)

const HOLD_SECONDS: float = Tokens.Motion.TOAST_HOLD * 2 / 1000.0

var _feature: StringName = &""
var _target: Control
var _caption: Label
var _elapsed: float = 0.0


func _ready() -> void:
	set_process(is_showing())
	set_process_input(is_showing())


## @api Highlight a target exposing `highlighted` and show the caption key beside it.
func show_mark(feature: StringName, target: Control, caption: Label) -> Error:
	if is_showing():
		return ERR_BUSY
	var key: String = OnboardingState.caption_key(feature)
	if key.is_empty() or target == null or caption == null or not "highlighted" in target:
		return ERR_INVALID_PARAMETER
	_feature = feature
	_target = target
	_caption = caption
	_elapsed = 0.0
	_target.set("highlighted", true)
	_caption.text = key
	_caption.visible = true
	set_process(true)
	set_process_input(true)
	return OK


## @api Whether a coach mark is showing.
func is_showing() -> bool:
	return not _feature.is_empty()


## @api End the coach mark; safe to call repeatedly. Emits finished once.
func dismiss() -> void:
	if not is_showing():
		return
	var feature: StringName = _feature
	if is_instance_valid(_target):
		_target.set("highlighted", false)
	if is_instance_valid(_caption):
		_caption.visible = false
	_feature = &""
	_target = null
	_caption = null
	set_process(false)
	set_process_input(false)
	finished.emit(feature)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= HOLD_SECONDS:
		dismiss()


func _input(event: InputEvent) -> void:
	var tap: bool = event is InputEventScreenTouch or event is InputEventMouseButton
	if tap and event.is_pressed():
		dismiss()
