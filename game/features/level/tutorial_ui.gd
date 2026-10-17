class_name LevelTutorialUI
extends Node
## Caller-owned lesson. Save owns durable completion; the catalog owns motion/input policy.

var hand: TutorialHand
var caption: Label
var pending: bool = false
var _host: LevelScreen
var _save: Node
var _accepted: bool = false
var _touched: bool = false
var _active: bool = false


func mount(host: LevelScreen, save: Node, area: Control) -> void:
	_host = host
	_save = save
	caption = CatalogSurface.label(&"Caption")
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.body.add_child(caption)
	host.body.move_child(caption, area.get_index())
	hand = TutorialHand.new()
	area.add_child(hand)
	_active = host.controller.get_board() != null and host.progress.current_slot() == 1
	_connect()
	_reconcile()
	layout()


func _reconcile() -> void:
	if not _active:
		_hide()
		return
	if int(_save.onboarding_snapshot().get("step", 0)) >= 1 or _accepted:
		_accepted = true
		_hide()
		return
	# Found board words are hint-derived too. Only eligible bonus history proves a solve.
	var board: BoardState = _host.controller.get_board()
	for word: String in board.bonus_words():
		if word in board.get_level().bonus_words():
			_commit()
			return
	caption.text = tr("level.tutorial.connect")
	caption.visible = true


func _connect() -> void:
	if not _host.controller.player_word_committed.is_connected(_commit):
		_host.controller.player_word_committed.connect(_commit)
		_host.wheel.gui_input.connect(_touch)
		_host.controller.state_changed.connect(_report_pending)


func _commit() -> void:
	if not _active or _accepted:
		return
	_accepted = true
	_hide()
	var error: Error = _save.complete_tutorial()
	pending = error != OK
	if pending:
		_host.show_paid_status("level.state.persistence_failed")


func _report_pending() -> void:
	if pending:
		_host.show_paid_status("level.state.persistence_failed")


func retry() -> Error:
	if not pending:
		return OK
	# The named command retries this exact action, never another owner's pending coach.
	var error: Error = _save.complete_tutorial()
	pending = error != OK
	if not pending:
		_host.show_paid_status("")
	return error


func _hide() -> void:
	caption.visible = false
	hand.cancel()


func _touch(event: InputEvent) -> void:
	if (
		(event is InputEventScreenTouch and event.pressed and not event.canceled)
		or (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		)
	):
		_touched = true
		hand.hide_for_touch()


func layout() -> void:
	if not is_instance_valid(hand) or not _active or _accepted or not is_inside_tree():
		return
	var level: LevelData = _host.controller.get_board().get_level()
	if level.word_count() == 0:
		return
	var used: PackedInt32Array = PackedInt32Array()
	var path: PackedVector2Array = PackedVector2Array()
	var letters: PackedStringArray = level.get_letters()
	var target: String = level.word(0)
	for character: String in target:
		for index: int in letters.size():
			if letters[index] == character and index not in used:
				used.append(index)
				path.append(_host.wheel.position + _host.wheel.tile_position(index))
				break
	hand.configure(path)


func _enter_tree() -> void:
	if is_instance_valid(_host):
		_resume.call_deferred()


func _resume() -> void:
	if not is_inside_tree() or not _host.is_inside_tree():
		return
	_connect()
	_reconcile()
	layout()
	if _active and not _accepted and not _touched:
		hand.play()


func _exit_tree() -> void:
	if is_instance_valid(hand):
		hand.cancel()
	if is_instance_valid(_host) and is_instance_valid(_host.controller):
		if _host.controller.player_word_committed.is_connected(_commit):
			_host.controller.player_word_committed.disconnect(_commit)
			_host.controller.state_changed.disconnect(_report_pending)
		if _host.wheel.gui_input.is_connected(_touch):
			_host.wheel.gui_input.disconnect(_touch)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(caption):
		caption.text = tr("level.tutorial.connect")
