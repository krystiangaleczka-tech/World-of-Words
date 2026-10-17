class_name FeatureCoaches
extends Node
## Caller-owned presentation protocol, not a component or a gameplay authority.

signal changed
const SAVE: Script = preload("res://services/save.gd")
const FEATURES: PackedStringArray = ["shuffle", "bonus", "hint", "journey", "reveal"]
var _level: LevelScreen
var _config: Node
var _guard: Callable
var _slot: int
var _targets: Dictionary[StringName, ActionButton] = {}
var _captions: Dictionary[StringName, Label] = {}
var _save: Node
var _eligible: Callable
var _blocked: Callable
var _lineage: int
var _queue: Array[Dictionary] = []
var _pending: Dictionary = {}
var _active: Dictionary = {}
var _busy: bool = false
var _dispatch: bool = false
var _hold: Timer
var _catalog: LocaleCatalog = LocaleCatalog.new()


func configure(save: Node, events: Node, eligible: Callable, blocked: Callable) -> Error:
	if is_inside_tree() or _save != null:
		return ERR_BUSY
	if not save is SAVE or not eligible.is_valid() or not blocked.is_valid():
		return ERR_UNCONFIGURED
	var error: Error = save.configure_onboarding(events)
	if error != OK:
		return error
	_save = save
	_lineage = int(save.committed_view().lineage)
	_eligible = eligible
	_blocked = blocked
	return OK


func _ready() -> void:
	_hold = Timer.new()
	_hold.one_shot = true
	add_child(_hold)
	_hold.timeout.connect(dismiss)


func _live(request: Dictionary) -> bool:
	return (
		is_instance_valid(_save)
		and int(_save.committed_view().get("lineage", -1)) == _lineage
		and is_instance_valid(request.target)
		and is_instance_valid(request.caption)
		and request.target.is_visible_in_tree()
		and request.caption.is_inside_tree()
		and request.target.get_parent().is_ancestor_of(request.caption)
		and request.target.get_viewport() == request.caption.get_viewport()
		and _eligible.is_valid()
		and _eligible.call(request.feature, request.target)
	)


func _is_blocked() -> bool:
	return get_tree().paused or not _blocked.is_valid() or _blocked.call()


func _seen(feature: StringName) -> bool:
	return str(feature) in _save.onboarding_snapshot().get("seen", [])


func _guard_request(feature: StringName, target: Control, caption: Label) -> Error:
	if _busy:
		return ERR_BUSY
	if _save == null or not is_inside_tree() or _hold == null:
		return ERR_UNCONFIGURED
	if str(feature) not in FEATURES or not target is ActionButton or not is_instance_valid(caption):
		return ERR_INVALID_PARAMETER
	return OK


func show(feature: StringName, target: Control, caption: Label) -> Error:
	var error: Error = _guard_request(feature, target, caption)
	if error != OK:
		return error
	if active_feature() == feature or _seen(feature):
		return OK
	for request: Dictionary in _queue:
		if request.feature == feature:
			return OK
	var request: Dictionary = {"feature": feature, "target": target, "caption": caption}
	error = _validate_request(request)
	if error != OK:
		return error
	if not _pending.is_empty():
		return ERR_BUSY
	_queue.append(request)
	return _advance()


func _validate_request(request: Dictionary) -> Error:
	if (
		not _live(request)
		or request.target.highlighted
		or request.caption.visible
		or request.caption.mouse_filter != Control.MOUSE_FILTER_IGNORE
	):
		return ERR_INVALID_PARAMETER
	if int(_save.onboarding_snapshot().get("step", 0)) < 1:
		return ERR_UNAVAILABLE
	return OK


func _advance() -> Error:
	if _busy or not _pending.is_empty() or not _active.is_empty() or _dispatch:
		return OK
	while not _queue.is_empty():
		var request: Dictionary = _queue[0]
		if _validate_request(request) != OK or _seen(request.feature):
			_queue.pop_front()
			continue
		if _is_blocked():
			return OK
		_queue.pop_front()
		return _claim(request, true)
	return OK


func _claim(request: Dictionary, paint: bool) -> Error:
	_busy = true
	_pending = request
	var error: Error = _save.mark_coach_seen(request.feature)
	if error == OK:
		_pending = {}
		if paint and is_inside_tree() and _validate_request(request) == OK and not _is_blocked():
			_active = request
			request.caption.text = tr("onboarding.coach." + str(request.feature))
			request.target.highlighted = true
			request.caption.visible = true
			_hold.start(float(Tokens.Motion.TOAST_HOLD * 2) / 1000.0)
			changed.emit()
	_busy = false
	return error


func retry() -> Error:
	if _busy:
		return ERR_BUSY
	if _pending.is_empty():
		return OK
	var request: Dictionary = _pending
	if _seen(request.feature):
		_pending = {}
		return OK
	if _validate_request(request) != OK or _is_blocked():
		return ERR_BUSY
	return _claim(request, true)


func prepare_navigation() -> Error:
	if _busy:
		return ERR_BUSY
	return OK if _pending.is_empty() else _claim(_pending, false)


func active_feature() -> StringName:
	return _active.get("feature", &"")


func dismiss() -> void:
	if _busy:
		return
	_clear()
	if not _dispatch:
		refresh.call_deferred()


func _clear() -> void:
	if _hold != null:
		_hold.stop()
	if _active.is_empty():
		return
	var previous: Dictionary = _active
	_active = {}
	if is_instance_valid(previous.target):
		previous.target.highlighted = false
	if is_instance_valid(previous.caption):
		previous.caption.visible = false
	changed.emit()


func refresh() -> void:
	if not is_inside_tree() or _busy:
		return
	if not _active.is_empty() and (not _live(_active) or _is_blocked()):
		_clear()
	_advance()


func _input(event: InputEvent) -> void:
	if not (
		(event is InputEventScreenTouch and event.pressed and not event.canceled)
		or (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		)
	):
		return
	_dispatch = true
	_clear()
	_release_dispatch.call_deferred()


func _release_dispatch() -> void:
	_dispatch = false
	refresh()


func _enter_tree() -> void:
	_catalog.register_all()
	if _hold != null and not _hold.timeout.is_connected(dismiss):
		_hold.timeout.connect(dismiss)
	if _level != null and not _targets.is_empty():
		_resume_level.call_deferred()


func _exit_tree() -> void:
	_disconnect_level()
	_clear()
	if _hold != null and _hold.timeout.is_connected(dismiss):
		_hold.timeout.disconnect(dismiss)
	_queue.clear()
	_dispatch = false
	_catalog.unregister()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _active.is_empty():
		_active.caption.text = tr("onboarding.coach." + str(active_feature()))
	if (
		what in [NOTIFICATION_TRANSLATION_CHANGED, Control.NOTIFICATION_THEME_CHANGED]
		and _level != null
	):
		layout_level.call_deferred()


func configure_level(
	host: LevelScreen, save: Node, config: Node, bus: Node, slot: int, guard: Callable
) -> Error:
	if not guard.is_valid() or not save.is_loaded():
		return ERR_UNCONFIGURED
	var view: Dictionary = save.committed_view()
	var language: String = view.sections.settings.language
	var state: Dictionary = view.sections.progress.by_lang.get(language, {})
	if slot != int(state.get("current_slot", 0)):
		return ERR_UNCONFIGURED
	_level = host
	_config = config
	_slot = slot
	_guard = guard
	return configure(save, bus, _level_eligible, _level_blocked)


func mount_level(area: Control) -> void:
	_targets = {
		&"shuffle": _level.shuffle_button,
		&"bonus": _level.p2_hud.meter,
		&"hint": _level.hint_button,
		&"reveal": _level.p2_hud.reveal
	}
	for feature: StringName in _targets:
		var label: Label = CatalogSurface.label(&"Caption")
		label.text = tr("onboarding.coach." + str(feature))
		label.visible = false
		area.add_child(label)
		_captions[feature] = label
	_resume_level()


func _level_eligible(feature: StringName, target: Control) -> bool:
	if (
		not is_instance_valid(_level)
		or _targets.get(feature) != target
		or not _level.p2_hud.bindings_ready()
		or _level.controller.get_board() == null
	):
		return false
	var state: Dictionary = _save.committed_view().sections.progress.by_lang.get(
		_save.committed_view().sections.settings.language, {}
	)
	var key: StringName = StringName(
		"unlocks." + ("bonus_meter" if feature == &"bonus" else str(feature)) + "_slot"
	)
	if int(state.get("current_slot", 0)) != _slot or _slot < _config.get_int(key):
		return false
	if feature == &"bonus":
		var checkpoint: Variant = state.get("level_state")
		var level: LevelData = _level.controller.get_board().get_level()
		if not checkpoint is Dictionary or checkpoint.get("level_id") != level.get_id():
			return false
		for word: String in checkpoint.get("bonus_words", []):
			if word in level.bonus_words():
				return true
		return false
	return true


func _level_blocked() -> bool:
	return (
		_guard.call()
		or get_tree().paused
		or _level.controller.is_complete()
		or _level.completion_layer.visible
		or _level.wheel.is_dragging()
		or _level.wheel.is_locked()
		or (
			_level.paid_tools_ui != null
			and (
				_level.controller.paid_locked()
				or _level.paid_tools_ui.modal_open()
				or _level.paid_tools_ui.reward_busy()
			)
		)
		or (_level.stuck_offer != null and _level.stuck_offer.caption.visible)
	)


func refresh_level(_result: AttemptResult = null) -> void:
	if not is_inside_tree() or _targets.is_empty():
		return
	for feature: StringName in _targets:
		if _level_eligible(feature, _targets[feature]):
			show(feature, _targets[feature], _captions[feature])
	refresh()
	layout_level()


func layout_level() -> void:
	if not is_inside_tree() or _targets.is_empty():
		return
	var area: Control = _level.wheel.get_parent()
	var wheel_rect: Rect2 = _level.wheel.get_rect()
	for feature: StringName in _targets:
		var label: Label = _captions[feature]
		var rect: Rect2 = _targets[feature].get_rect()
		if feature == &"bonus":
			label.position = Vector2(rect.end.x + Tokens.Space.S, rect.position.y)
			label.size.x = maxf(Tokens.Touch.MIN_TARGET, area.size.x - label.position.x)
		else:
			var right: bool = feature != &"shuffle"
			label.size.x = maxf(Tokens.Touch.MIN_TARGET, wheel_rect.position.x - Tokens.Space.S)
			label.position.x = wheel_rect.end.x + Tokens.Space.S if right else 0
			label.size.y = label.get_minimum_size().y
			label.position.y = (
				rect.end.y + Tokens.Space.S
				if feature == &"reveal"
				else rect.position.y - label.size.y - Tokens.Space.S
			)
		label.size.y = label.get_minimum_size().y


func _resume_level() -> void:
	if not is_inside_tree():
		return
	if not _level.controller.state_changed.is_connected(refresh_level):
		_level.controller.state_changed.connect(refresh_level, CONNECT_DEFERRED)
		_level.controller.result_ready.connect(refresh_level, CONNECT_DEFERRED)
		_level.wheel.resized.connect(layout_level, CONNECT_DEFERRED)
	for label: Label in _captions.values():
		if not label.minimum_size_changed.is_connected(layout_level):
			label.minimum_size_changed.connect(layout_level, CONNECT_DEFERRED)
	refresh_level.call_deferred()


func _disconnect_level() -> void:
	for label: Label in _captions.values():
		if is_instance_valid(label) and label.minimum_size_changed.is_connected(layout_level):
			label.minimum_size_changed.disconnect(layout_level)
	if (
		is_instance_valid(_level)
		and is_instance_valid(_level.controller)
		and _level.controller.state_changed.is_connected(refresh_level)
	):
		_level.controller.state_changed.disconnect(refresh_level)
		_level.controller.result_ready.disconnect(refresh_level)
		_level.wheel.resized.disconnect(layout_level)
