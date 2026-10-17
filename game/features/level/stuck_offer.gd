class_name LevelStuckOffer
extends Node
## Per-active-level offer composition; no wallet, board or navigation mutation.

var caption: Label
var _space: Control
var _found_count: int = 0
var _host: LevelScreen
var _config: Node
var _clock: Clock
var _idle: Timer
var _hold: Timer
var _last_word_msec: int
var _invalid: int = 0
var _shown: bool = false
var _suspended: bool = false


func mount(host: LevelScreen, config: Node, clock: Clock = null) -> void:
	_host = host
	_config = config
	_clock = clock if clock != null else Clock.new()
	caption = CatalogSurface.label(&"Caption")
	caption.name = "StuckOffer"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = tr("level.hint.offer")
	caption.visible = false
	_space = Control.new()
	_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.body.add_child(_space)
	_space.add_child(caption)
	_space.resized.connect(_layout_caption)
	caption.minimum_size_changed.connect(_layout_caption, CONNECT_DEFERRED)
	_layout_caption()
	_idle = Timer.new()
	_hold = Timer.new()
	for timer: Timer in [_idle, _hold]:
		timer.one_shot = true
		add_child(timer)
	_idle.timeout.connect(refresh)
	_hold.timeout.connect(_hide)
	_resume()


func _resume() -> void:
	if not is_inside_tree():
		return
	_last_word_msec = _clock.monotonic_msec()
	if not _host.controller.result_ready.is_connected(_result):
		_host.controller.result_ready.connect(_result)
	if not _host.controller.state_changed.is_connected(_state_changed):
		_host.controller.state_changed.connect(_state_changed)
	_found_count = _word_count()
	refresh()


func _word_count() -> int:
	var board: BoardState = _host.controller.get_board()
	return board.found_words().size() + board.bonus_words().size() if board != null else 0


func _state_changed() -> void:
	var count: int = _word_count()
	if count > _found_count:
		_invalid = 0
		_last_word_msec = _clock.monotonic_msec()
		_hide()
	_found_count = count
	refresh.call_deferred()


func _layout_caption() -> void:
	caption.size.x = _space.size.x
	var height: float = caption.get_minimum_size().y
	_space.custom_minimum_size.y = height
	caption.size.y = height


func _result(result: AttemptResult) -> void:
	if result.kind == AttemptResult.Kind.INVALID:
		_invalid += 1
	else:
		_invalid = 0
		if result.kind in [AttemptResult.Kind.LEVEL, AttemptResult.Kind.BONUS]:
			_last_word_msec = _clock.monotonic_msec()
		_hide()
	refresh.call_deferred()


## @api Recheck a due offer after an input/service boundary; no per-frame polling.
func refresh() -> void:
	if not is_inside_tree() or _idle == null:
		return
	_idle.stop()
	if _suspended or get_tree().paused or not _host.can_offer_hint():
		_hide()
		return
	if _shown:
		return
	if _invalid >= _config.get_int(&"hint.offer_invalid_streak"):
		_show(&"invalid_streak")
		return
	var remaining: float = (
		float(_config.get_int(&"hint.offer_idle_seconds"))
		- float(_clock.monotonic_msec() - _last_word_msec) / 1000.0
	)
	if remaining <= 0:
		_show(&"idle")
	else:
		_idle.start(remaining)


func _show(trigger: StringName) -> void:
	_shown = true
	caption.visible = true
	_host.hint_button.highlighted = true
	_hold.start(float(Tokens.Motion.TOAST_HOLD) / 1000.0)
	_host.stuck_offer_shown.emit(trigger)


func _hide() -> void:
	if _hold == null:
		return
	_hold.stop()
	if caption.visible:
		_host.hint_button.highlighted = false
	caption.visible = false


func _enter_tree() -> void:
	if _host != null:
		_last_word_msec = _clock.monotonic_msec()
		_resume.call_deferred()


func _exit_tree() -> void:
	if _idle != null:
		_idle.stop()
	_hide()
	if is_instance_valid(_host) and _host.controller.result_ready.is_connected(_result):
		_host.controller.result_ready.disconnect(_result)
	if is_instance_valid(_host) and _host.controller.state_changed.is_connected(_state_changed):
		_host.controller.state_changed.disconnect(_state_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and caption != null:
		caption.text = tr("level.hint.offer")
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_suspended = true
		refresh()
	elif (
		what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]
		and _clock != null
	):
		_suspended = false
		_last_word_msec = _clock.monotonic_msec()
		refresh()
