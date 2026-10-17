class_name LevelPaidTools
extends Node
## Caller-owned paid presentation. Services alone authorize debit, rewards and persistence.

const MONETIZATION: Script = preload("res://services/monetization.gd")
const SAVE: Script = preload("res://services/save.gd")
const ECONOMY: Script = preload("res://services/economy.gd")
const CONFIG: Script = preload("res://services/config.gd")
var sheet: ShopSheet
var retry: TextButton
var watch_ad: SecondaryButton
var get_coins: SecondaryButton
var not_now: TextButton
var message: Label
var _save: SAVE
var _economy: ECONOMY
var _config: CONFIG
var _service: MONETIZATION
var _ios: bool
var _host: LevelScreen
var _controller: LevelController
var _options: VBoxContainer
var _offline: StatePanel
var _timer: Timer
var _frame_tree: SceneTree
var _retry_kind: StringName = &"hint"
var _reward_call: Callable
var _reward_attempt: bool = false
var _reward_seen_busy: bool = false
var _reward_before: int
var _reward_message: String = ""
var _shop_ready: bool = false
var _catalog: LocaleCatalog = LocaleCatalog.new()


func configure(save: SAVE, economy: ECONOMY, config: CONFIG, service: Node, ios: bool) -> Error:
	if (
		service != null
		and (not service is MONETIZATION or not service.matches_tool_owners(save, economy, config))
	):
		return ERR_INVALID_PARAMETER
	_save = save
	_economy = economy
	_config = config
	_service = service
	_ios = ios
	return OK


func mount(host: LevelScreen, controller: LevelController) -> void:
	_host = host
	_controller = controller
	retry = TextButton.new()
	retry.text_key = "level.tool.retry"
	host.body.add_child(retry)
	retry.pressed.connect(_retry)
	sheet = ShopSheet.new()
	host.add_child(sheet)
	_shop_ready = is_instance_valid(_service) and sheet.configure(_service, _ios) == OK
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", Tokens.Space.M)
	watch_ad = SecondaryButton.new()
	watch_ad.text_key = "level.hint.sheet_watch_ad"
	watch_ad.configure_badge(&"ad")
	_options.add_child(watch_ad)
	message = CatalogSurface.label(&"Caption")
	_options.add_child(message)
	get_coins = SecondaryButton.new()
	get_coins.text_key = "level.hint.get_coins"
	_options.add_child(get_coins)
	not_now = TextButton.new()
	not_now.text_key = "level.hint.not_now"
	_options.add_child(not_now)
	_offline = StatePanel.new()
	_offline.configure(&"offline", "shop.offline.title", "shop.state.offline")
	watch_ad.pressed.connect(_reward)
	get_coins.pressed.connect(open_shop)
	not_now.pressed.connect(func() -> void: sheet.close())
	sheet.dismissed.connect(_dismissed)
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_unlock)
	_connect()
	_refresh()


func use_tool(kind: StringName) -> void:
	if not is_inside_tree() or _host.wheel.is_dragging() or modal_open():
		return
	if not _host.paid_bindings_ready() and not _controller.paid_pending():
		_host.show_paid_status("level.tool.unavailable")
		return
	_retry_kind = kind
	var result: Dictionary = _controller.use_paid_tool(kind)
	if result.state == "unaffordable" and not _economy.atomic_has_pending():
		_reward_message = ""
		if is_instance_valid(_service) and _service.matches_tool_owners(_save, _economy, _config):
			_service.begin_shop_visit()
		_refresh_options()
		sheet.open_alternative(_options, "level.hint.options")
	elif result.error != OK and result.state != "busy":
		_host.show_paid_status(
			(
				"level.state.persistence_failed"
				if _controller.paid_pending()
				else "level.tool.unavailable"
			)
		)
	_refresh()


func _retry() -> void:
	use_tool(_retry_kind)


func open_shop() -> void:
	if _controller.paid_locked() or reward_busy():
		return
	if _shop_ready and _service.matches_tool_owners(_save, _economy, _config):
		sheet.open_shop_content()
	else:
		sheet.open_alternative(_offline, "shop.sheet.title")
	_refresh()


func modal_open() -> bool:
	return is_instance_valid(sheet) and sheet.state != &"closed"


func reward_busy() -> bool:
	return is_instance_valid(_service) and _service.rewarded_state() in [&"busy", &"pending_reward"]


func _reward() -> void:
	if _service == null or not _service.matches_tool_owners(_save, _economy, _config):
		return
	if not _reward_attempt:
		_reward_before = _economy.snapshot().items.hint
		_reward_call = _economy.grant.bind(
			&"rewarded_hint", {"hint": _config.get_int(&"economy.reward.rewarded_hint")}
		)
		_reward_attempt = true
		_reward_seen_busy = false
	var error: Error = _service.request_rewarded(&"hint", _reward_call)
	if error != OK and _service.rewarded_state() != &"pending_reward":
		_reward_attempt = false
		_reward_message = "level.hint.ad_unavailable"
	_refresh()


func _refresh_options() -> void:
	if not is_instance_valid(watch_ad):
		return
	var state: StringName = (
		_service.rewarded_state()
		if is_instance_valid(_service) and _service.matches_tool_owners(_save, _economy, _config)
		else &"unavailable"
	)
	if state == &"ready" and not _config.get_bool(&"ads.rewarded.hint.enabled"):
		state = &"unavailable"
	if _reward_attempt and state == &"busy":
		_reward_seen_busy = true
	if _reward_attempt and _reward_seen_busy and state not in [&"busy", &"pending_reward"]:
		_reward_message = (
			"level.hint.reward_added"
			if _economy.snapshot().items.hint > _reward_before
			else "level.hint.ad_unavailable" if state == &"unavailable" else "level.hint.no_reward"
		)
		_reward_attempt = false
		if _reward_message == "level.hint.reward_added":
			sheet.toast.show_message(
				"level.hint.reward_added", &"success", HintButton.GLYPHS[&"hint"], watch_ad
			)
	var pending: bool = _reward_attempt and state == &"pending_reward"
	watch_ad.loading = state == &"busy"
	watch_ad.disabled = state != &"ready" and not pending
	watch_ad.text_key = "level.tool.retry" if pending else "level.hint.sheet_watch_ad"
	watch_ad.configure_badge(&"" if pending else &"ad")
	get_coins.disabled = state == &"busy" or pending
	not_now.disabled = state == &"busy" or pending
	if _options.get_parent() != null:
		sheet.busy = state == &"busy" or pending
	var key: String = (
		"level.hint.ad_unavailable" if state == &"unavailable" else "level.hint.reward_info"
	)
	if pending:
		key = "level.hint.reward_retry"
	elif not _reward_message.is_empty():
		key = _reward_message
	message.text = tr(key)


func _paid(kind: StringName, cells: Array[Vector2i]) -> void:
	var completed_word: bool = _host.board_view.cell_node(cells[0]).state == GridCell.State.FILLED
	for cell: Vector2i in cells:
		_host.board_view.cell_node(cell).state = GridCell.State.EMPTY
	if kind == &"hint" and not completed_word:
		_host.board_view.reveal_cell(cells[0], true)
	else:
		_host.board_view.reveal_word(cells)
	if Tokens.reduced_motion:
		_frame_tree = get_tree()
		_frame_tree.process_frame.connect(_unlock, CONNECT_ONE_SHOT)
	else:
		_timer.start(
			(
				Tokens.dur(Tokens.Motion.BASE) * 2
				+ maxf(0, cells.size() - 1) * Tokens.dur(Tokens.Motion.STAGGER) * 2
			)
		)
	_refresh()


func _unlock() -> void:
	_frame_tree = null
	if is_instance_valid(_controller):
		_controller.release_paid_feedback()
	_refresh()


func _refresh() -> void:
	if not is_inside_tree() or _host == null or _controller == null:
		return
	_refresh_options()
	retry.visible = _controller.paid_pending()
	_host.wheel.set_locked(
		(
			_controller.get_board() == null
			or _controller.paid_locked()
			or modal_open()
			or _controller.is_complete()
		)
	)
	_host.refresh_paid_hud()


func _dismissed(_reason: StringName) -> void:
	_refresh.call_deferred()


func _connect() -> void:
	if not _controller.paid_tool_committed.is_connected(_paid):
		_controller.paid_tool_committed.connect(_paid)
	if is_instance_valid(_service) and not _service.shop_changed.is_connected(_refresh):
		_service.shop_changed.connect(_refresh)


func _enter_tree() -> void:
	_catalog.register_all()
	if _controller != null:
		_resume.call_deferred()


func _resume() -> void:
	if not is_inside_tree():
		return
	_connect()
	_refresh()


func _exit_tree() -> void:
	if _frame_tree != null and _frame_tree.process_frame.is_connected(_unlock):
		_frame_tree.process_frame.disconnect(_unlock)
	_frame_tree = null
	if _controller != null:
		_controller.release_paid_feedback()
		if _controller.paid_tool_committed.is_connected(_paid):
			_controller.paid_tool_committed.disconnect(_paid)
	if _timer != null:
		_timer.stop()
	if is_instance_valid(_service) and _service.shop_changed.is_connected(_refresh):
		_service.shop_changed.disconnect(_refresh)
	_catalog.unregister()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_options()
	elif what == NOTIFICATION_PREDELETE:
		for control: Control in [_options, _offline]:
			if is_instance_valid(control) and control.get_parent() == null:
				control.free()
