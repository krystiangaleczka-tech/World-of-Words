class_name LevelBonusUI
extends Node
## Presentation of already committed bonus progress. Never credits or redeems.

var caption: Label
var summary: Label
var burst: RewardBurst
var _host: LevelScreen
var _economy: Node
var _save: Node
var _area: Control
var _chests: int = 0
var _coins: int = 0
var _presented: bool = false


func mount(host: LevelScreen, economy: Node, save: Node) -> void:
	_host = host
	_economy = economy
	_save = save
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.p2_hud.meter.disabled = true
	_area = Control.new()
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.custom_minimum_size.y = Tokens.Touch.MIN_TARGET
	_area.visible = false
	host.completion_layer.add_child(_area)
	host.completion_layer.move_child.call_deferred(_area, 1)
	burst = RewardBurst.new()
	_area.add_child(burst)
	summary = CatalogSurface.label(&"Caption")
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.visible = false
	host.completion_layer.add_child(summary)
	host.completion_layer.move_child.call_deferred(summary, 2)
	_connect()
	_refresh()


func _connect() -> void:
	if not is_instance_valid(_economy):
		return
	if not _economy.bonus_chest_redeemed.is_connected(_settled):
		_economy.bonus_chest_redeemed.connect(_settled)
	if not _host.controller.state_changed.is_connected(_refresh):
		_host.controller.state_changed.connect(_refresh)
	if not _host.completion_layer.visibility_changed.is_connected(_present):
		_host.completion_layer.visibility_changed.connect(_present, CONNECT_DEFERRED)
	if not _area.resized.is_connected(_present):
		_area.resized.connect(_present, CONNECT_DEFERRED)


func _settled(chests: int, coins: int) -> void:
	var board: BoardState = _host.controller.get_board()
	if (
		_presented
		or chests < 1
		or coins < 0
		or board == null
		or not _save.receipt_publishing()
		or not _host.paid_bindings_ready()
		or _host.progress.highest_completed_slot() != board.get_level().get_slot()
	):
		return
	_chests = chests
	_coins = coins
	_present.call_deferred()


func _refresh() -> void:
	if not is_inside_tree():
		return
	caption.text = tr("level.bonus.at_complete")
	caption.visible = (
		_host.p2_hud.meter.visible
		and _host.paid_bindings_ready()
		and not _host.controller.is_complete()
	)
	summary.text = tr("level.bonus.reward") % [_chests, _coins]


func _present() -> void:
	if (
		not is_inside_tree()
		or not _host.completion_layer.is_visible_in_tree()
		or not _host.controller.is_complete()
	):
		return
	_host.board_view.get_parent().visible = false
	_host.completion_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_host.completion_layer.alignment = BoxContainer.ALIGNMENT_CENTER
	if _presented or _chests < 1:
		return
	_area.visible = true
	summary.visible = true
	_refresh()
	if _area.size.x <= 0:
		return
	_presented = true
	burst.play(&"chest", _chests, Vector2(_area.size.x / 2, Tokens.Space.XL / 2.0))


func _enter_tree() -> void:
	if _host != null:
		_resume.call_deferred()


func _resume() -> void:
	if not is_inside_tree():
		return
	_connect()
	_refresh()
	_present()


func _exit_tree() -> void:
	if _host == null:
		return
	burst.cancel()
	if is_instance_valid(_economy) and _economy.bonus_chest_redeemed.is_connected(_settled):
		_economy.bonus_chest_redeemed.disconnect(_settled)
	if _host.controller.state_changed.is_connected(_refresh):
		_host.controller.state_changed.disconnect(_refresh)
	if _host.completion_layer.visibility_changed.is_connected(_present):
		_host.completion_layer.visibility_changed.disconnect(_present)
	if _area.resized.is_connected(_present):
		_area.resized.disconnect(_present)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _host != null:
		_refresh()
