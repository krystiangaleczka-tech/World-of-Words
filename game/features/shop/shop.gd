class_name ShopSheet
extends Sheet
## Explicit caller-mounted view. No Save, provider, grant or navigation ownership.

const SERVICE: Script = preload("res://services/monetization.gd")
const REMOVE: String = "nc.remove_forced_ads.v1"
const COINS: String = "c.coins_s.v1"
const STATES: Dictionary = {
	&"purchasing": "shop.state.loading",
	&"pending": "shop.state.pending",
	&"settling": "shop.state.retry",
	&"completed": "shop.state.success",
	&"cancelled": "shop.state.cancelled",
	&"failed": "shop.state.failed",
	&"unknown": "shop.state.unknown"
}
var balance: CurrencyPill
var remove_card: Card
var coins_card: Card
var free_card: Card
var restore_button: TextButton
var offline_panel: StatePanel
var reward_burst: RewardBurst
var toast: Toast
var status_label: Label
var _had_snapshot: bool = false
var _last_coins: int = 0
var _last_owned: bool = false
var _service: SERVICE
var _ios: bool = false
var _column: VBoxContainer
var _coin_amount: Label
var _free_amount: Label
var _owned_bodies: Array[Control] = []
var _message_key: String = ""
var _restore_failure_revision: int = -1


func configure(service: SERVICE, ios: bool) -> Error:
	if not is_instance_valid(service) or service.shop_snapshot().is_empty():
		return ERR_UNCONFIGURED
	if state != &"closed" and _service != service:
		return ERR_BUSY
	_disconnect_service()
	_service = service
	_ios = ios
	_connect_service()
	_refresh()
	return OK


func _enter_tree() -> void:
	super._enter_tree()
	_connect_service()
	_refresh()


func _ready() -> void:
	title_key = "shop.sheet.title"
	super._ready()
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", Tokens.Space.M)
	balance = CurrencyPill.new()
	balance.name = "Balance"
	balance.action_enabled = false
	balance.size_flags_horizontal = Control.SIZE_SHRINK_END
	_column.add_child(balance)
	offline_panel = StatePanel.new()
	offline_panel.configure(
		&"offline", "shop.offline.title", "shop.state.offline", "shop.action.retry"
	)
	_column.add_child(offline_panel)
	offline_panel.action_requested.connect(_retry_prices)
	remove_card = _card("RemoveAds", "shop.remove_forced_ads.title", "shop.remove_forced_ads.body")
	coins_card = _card("CoinPack", "shop.coins_pack.title", "")
	_coin_amount = CatalogSurface.label(&"Numeric")
	_owned_bodies.append(_coin_amount)
	coins_card.configure_body(_coin_amount)
	free_card = _card("FreeCoins", "shop.free_coins.title", "shop.free_coins.body")
	_free_amount = CatalogSurface.label(&"Numeric")
	_owned_bodies.append(_free_amount)
	free_card.configure_body(_free_amount)
	restore_button = TextButton.new()
	restore_button.text_key = "shop.sheet.restore"
	_column.add_child(restore_button)
	status_label = CatalogSurface.label(&"Caption")
	_column.add_child(status_label)
	configure_content(_column)
	reward_burst = RewardBurst.new()
	add_child(reward_burst)
	toast = Toast.new()
	add_child(toast)
	dismissed.connect(_clear_feedback)
	remove_card.action_requested.connect(_buy.bind(REMOVE))
	coins_card.action_requested.connect(_buy.bind(COINS))
	free_card.action_requested.connect(_reward)
	restore_button.pressed.connect(_restore)
	_refresh()


func _card(node_name: String, title: String, subtitle: String) -> Card:
	var card: Card = Card.new()
	card.name = node_name
	card.title_key = title
	card.sublabel_key = subtitle
	_column.add_child(card)
	return card


func open() -> Error:
	if not is_instance_valid(_service):
		return ERR_UNCONFIGURED
	var error: Error = super.open()
	if error == OK:
		_message_key = ""
		_service.begin_shop_visit()
		var requested: Error = _service.request_products()
		if requested not in [OK, ERR_BUSY]:
			_message_key = "shop.state.offline"
		_refresh()
	return error


## @api Caller-owned alternatives replace this Sheet's content, without a nested modal.
func open_alternative(content: Control, title: String) -> Error:
	if busy:
		return ERR_BUSY
	var error: Error = configure_content(content)
	if error != OK:
		return error
	title_key = title
	return super.open()


## @api Restore the actual provider-backed catalog within this same Sheet.
func open_shop_content() -> Error:
	if busy or not is_instance_valid(_service):
		return ERR_BUSY if busy else ERR_UNCONFIGURED
	title_key = "shop.sheet.title"
	var error: Error = configure_content(_column)
	return open() if error == OK else error


func _refresh() -> void:
	if not is_instance_valid(remove_card):
		return
	var snapshot: Dictionary = _service.shop_snapshot() if is_instance_valid(_service) else {}
	if snapshot.is_empty():
		balance.visible = false
		for card: Card in [remove_card, coins_card, free_card]:
			card.disabled = true
		status_label.text = tr("shop.state.offline")
		return
	balance.visible = true
	if not _had_snapshot or balance.value != snapshot.coins:
		balance.set_value(snapshot.coins, state != &"closed")
	if _had_snapshot and state != &"closed":
		if snapshot.coins > _last_coins:
			reward_burst.play(
				&"coins",
				snapshot.coins - _last_coins,
				get_global_transform().affine_inverse() * balance.get_global_rect().get_center()
			)
			toast.show_message("shop.coins.added", &"success", null, balance)
		elif snapshot.owned and not _last_owned:
			toast.show_message("shop.purchase.thanks", &"success", null, balance)
	_had_snapshot = true
	_last_coins = snapshot.coins
	_last_owned = snapshot.owned
	offline_panel.visible = snapshot.catalog_state == &"unavailable"
	remove_card.visible = not offline_panel.visible
	coins_card.visible = not offline_panel.visible
	# Reserve numeric content beside the expandable native icon.
	balance.custom_minimum_size.x = (
		Tokens.Touch.MIN_TARGET
		+ Tokens.Space.S
		+ (
			balance
			. get_theme_font("font")
			. get_string_size(
				str(snapshot.coins),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				balance.get_theme_font_size("font_size")
			)
			. x
		)
	)
	_coin_amount.text = str(snapshot.coin_amount)
	_free_amount.text = str(snapshot.reward_amount)
	var active: bool = snapshot.purchase_state == &"purchasing" or snapshot.reward_state == &"busy"
	busy = active
	_product_card(remove_card, REMOVE, snapshot, active)
	_product_card(coins_card, COINS, snapshot, active)
	var reward: StringName = snapshot.reward_state
	var retry: bool = reward == &"pending_reward"
	free_card.configure_action(
		&"secondary",
		"shop.action.retry" if retry else "shop.free_coins.watch",
		"",
		&"" if retry else &"ad"
	)
	free_card.loading = reward == &"busy"
	free_card.disabled = (not retry and (active or snapshot.capped or reward != &"ready"))
	free_card.sublabel_key = (
		"shop.state.retry"
		if retry
		else (
			"shop.free_coins.capped"
			if snapshot.capped
			else (
				"shop.free_coins.unavailable"
				if reward == &"unavailable"
				else "shop.free_coins.body"
			)
		)
	)
	restore_button.visible = _ios
	restore_button.disabled = active or snapshot.catalog_state == &"loading"
	if (
		_message_key == "shop.restore.requested"
		and snapshot.failure_revision > _restore_failure_revision
	):
		_message_key = ""
	var key: String = _message_key
	if key.is_empty():
		key = STATES.get(snapshot.purchase_state, "")
	if key.is_empty() and snapshot.catalog_state != &"ready":
		key = "shop.state.loading" if snapshot.catalog_state == &"loading" else "shop.state.offline"
	status_label.text = tr(key) if not key.is_empty() else ""
	status_label.visible = (
		not key.is_empty() and not (offline_panel.visible and key == "shop.state.offline")
	)


func _product_card(card: Card, id: String, snapshot: Dictionary, active: bool) -> void:
	var product: Dictionary = snapshot.products[id]
	var owned: bool = id == REMOVE and snapshot.owned
	var recovery: bool = product.state in [&"pending", &"unknown", &"settling"]
	var variant: StringName = (
		&"primary"
		if (id == REMOVE and not snapshot.owned) or (id == COINS and snapshot.owned)
		else &"secondary"
	)
	if owned:
		card.configure_action(&"none", "")
		card.sublabel_key = "shop.state.owned"
	else:
		card.configure_action(
			variant,
			"shop.action.retry" if recovery else "shop.action.buy",
			"" if recovery else product.get("price", "")
		)
		card.sublabel_key = STATES.get(
			product.state, "shop.remove_forced_ads.body" if id == REMOVE else ""
		)
	if not owned and not recovery and not product.has("price"):
		card.sublabel_key = "shop.state.offline"
	card.loading = (
		not owned and (product.state == &"purchasing" or snapshot.catalog_state == &"loading")
	)
	card.disabled = (
		owned or active or (not recovery and (not product.has("price") or snapshot.reward_pending))
	)


func _buy(id: String) -> void:
	var snapshot: Dictionary = _service.shop_snapshot()
	if snapshot.is_empty():
		return
	var recovery: bool = snapshot.products[id].state in [&"pending", &"unknown", &"settling"]
	_result(_service.process_unfinished_transactions() if recovery else _service.purchase(id))


func _clear_feedback(_reason: StringName) -> void:
	reward_burst.cancel()
	toast.hide_message()


func _retry_prices() -> void:
	_result(_service.request_products())


func _reward() -> void:
	_result(_service.request_shop_reward())


func _restore() -> void:
	_restore_failure_revision = _service.shop_snapshot().failure_revision
	var error: Error = _service.restore_purchases()
	_message_key = (
		"shop.restore.requested"
		if error == OK and _service.shop_snapshot().failure_revision == _restore_failure_revision
		else "shop.state.failed"
	)
	_refresh()


func _result(error: Error) -> void:
	_message_key = (
		"" if error == OK else "shop.state.pending" if error == ERR_BUSY else "shop.state.failed"
	)
	_refresh()


func _connect_service() -> void:
	if (
		is_inside_tree()
		and is_instance_valid(_service)
		and not _service.shop_changed.is_connected(_refresh)
	):
		_service.shop_changed.connect(_refresh)


func _disconnect_service() -> void:
	if is_instance_valid(_service) and _service.shop_changed.is_connected(_refresh):
		_service.shop_changed.disconnect(_refresh)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()
	elif what == NOTIFICATION_PREDELETE:
		for body: Control in _owned_bodies:
			if is_instance_valid(body):
				body.free()
		if is_instance_valid(_column):
			_column.free()


func _exit_tree() -> void:
	_disconnect_service()
	super._exit_tree()
