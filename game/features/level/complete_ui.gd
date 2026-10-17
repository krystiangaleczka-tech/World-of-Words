class_name LevelCompleteUI
extends Node
## Receipt-derived completion presentation; providers and Economy own settlement.

var coins: CurrencyPill
var stars: CurrencyPill
var number: Label
var postcard: LocationPostcard
var progress_bar: CatalogProgressBar
var credits: Label
var double_button: SecondaryButton
var message: Label
var _host: LevelScreen
var _save: Node
var _economy: Node
var _config: Node
var _content: Node
var _service: Node
var _nav: Node
var _language: String
var _lineage: int = -1
var _slot: int
var _base: int = 0
var _extra: int = 0
var _reason: StringName
var _reward: Callable
var _presented: bool = false
var _attempt: bool = false
var _doubled: bool = false
var _requesting: bool = false
var _message_key: String = ""
var _postcard_group: VBoxContainer
var _pieces: int
var _total: int


func configure(service: Node) -> void:
	_service = service


func mount(
	host: LevelScreen, save: Node, economy: Node, config: Node, content: Node, slot: int, nav: Node
) -> void:
	_host = host
	_save = save
	_economy = economy
	_config = config
	_content = content
	_slot = slot
	_nav = nav
	host.completion_title.remove_theme_font_size_override("font_size")
	host.completion_title.theme_type_variation = &"Title"
	host.completion_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.completion_layer.add_theme_constant_override("separation", Tokens.Space.L)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", Tokens.Space.L)
	host.completion_layer.add_child(column)
	host.completion_layer.move_child.call_deferred(column, 1)
	number = CatalogSurface.label(&"Display")
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(number)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Tokens.Space.L)
	column.add_child(row)
	stars = CurrencyPill.new()
	stars.kind = &"stars"
	row.add_child(stars)
	coins = CurrencyPill.new()
	row.add_child(coins)
	_postcard_group = VBoxContainer.new()
	_postcard_group.add_theme_constant_override("separation", Tokens.Space.L)
	_postcard_group.visible = false
	column.add_child(_postcard_group)
	postcard = LocationPostcard.new()
	postcard.visible = false
	_postcard_group.add_child(postcard)
	progress_bar = CatalogProgressBar.new()
	_postcard_group.add_child(progress_bar)
	credits = CatalogSurface.label(&"Caption")
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_postcard_group.add_child(credits)
	double_button = SecondaryButton.new()
	double_button.text_key = "level.complete.double"
	double_button.configure_badge(&"ad")
	host.completion_layer.add_child(double_button)
	double_button.pressed.connect(_double)
	message = CatalogSurface.label(&"Caption")
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.completion_layer.add_child(message)
	_connect()
	_present()


func _connect() -> void:
	if not _host.completion_layer.visibility_changed.is_connected(_present):
		_host.completion_layer.visibility_changed.connect(_present, CONNECT_DEFERRED)
	if is_instance_valid(_service) and not _service.shop_changed.is_connected(_refresh):
		_service.shop_changed.connect(_refresh, CONNECT_DEFERRED)
	if (
		is_instance_valid(_nav)
		and _nav.has_signal("campaign_continue_failed")
		and not _nav.is_connected("campaign_continue_failed", _continue_failed)
	):
		_nav.connect("campaign_continue_failed", _continue_failed)


func _present() -> void:
	if (
		not is_inside_tree()
		or not _host.completion_layer.is_visible_in_tree()
		or not _host.controller.is_complete()
	):
		return
	if not _presented:
		var view: Dictionary = _save.committed_view()
		if view.error != OK or not _host.paid_bindings_ready():
			return
		var language: String = view.sections.settings.language
		_language = language
		_lineage = int(view.lineage)
		for receipt: Dictionary in view.sections.meta.atomic.processed.values():
			if (
				receipt.language != language
				or int(receipt.slot) != _slot
				or receipt.delta.get("stars", 0) != 1
			):
				continue
			for grant: Dictionary in receipt.notifications:
				if grant.operation == "grant" and grant.reason == "level_complete":
					_base = int(grant.amounts.get("coins", 0))
			stars.set_value(int(receipt.delta.stars))
			_presented = true
			break
		if not _presented:
			return
		_extra = _base * maxi(_config.get_int(&"economy.reward.double_multiplier") - 1, 0)
		_reason = StringName("rewarded_double:%s:%d" % [language, _slot])
		_reward = _economy.grant.bind(_reason, {"coins": _extra})
		coins.set_value(_base)
		var location: Dictionary = _content.location_for_slot(_slot)
		_total = _config.get_int(&"meta.postcard.pieces")
		var state: Dictionary = view.sections.progress.by_lang[language]
		_postcard_group.visible = (
			_slot > 1
			and (
				"journey" in state.unlocked
				or "journey" in view.sections.progress.unlocked
				or int(state.current_slot) >= _config.get_int(&"unlocks.journey_slot")
			)
		)
		_pieces = clampi(int(state.location_pieces.get(location.get("id", ""), 0)), 0, _total)
		progress_bar.set_value(float(_pieces) / maxi(_total, 1))
		var path: String = "res://content".path_join(language).path_join(
			str(location.get("postcard", ""))
		)
		if not str(location.get("postcard", "")).is_empty() and ResourceLoader.exists(path):
			var image: Texture2D = load(path) as Texture2D
			postcard.visible = postcard.configure(image, _total, _pieces, &"thumb") == OK
	_refresh()


func busy() -> bool:
	return (
		_requesting
		or (
			is_instance_valid(_service)
			and _service.rewarded_state() in [&"busy", &"pending_reward"]
		)
	)


func _double() -> void:
	if (
		not is_inside_tree()
		or not _presented
		or _doubled
		or _requesting
		or double_button.disabled
		or not double_button.is_visible_in_tree()
		or _host.completion_is_continuing()
	):
		return
	if not _owners_ready():
		return
	_attempt = true
	_requesting = true
	double_button.disabled = true
	var error: Error = _service.request_rewarded(&"double_reward", _reward)
	_requesting = false
	if error != OK and _service.rewarded_state() != &"pending_reward":
		_attempt = false
		_message_key = "level.complete.no_ad"
	_refresh()


func _owners_ready() -> bool:
	if (
		not is_instance_valid(_service)
		or not _service.matches_tool_owners(_save, _economy, _config)
		or not _host.paid_bindings_ready()
	):
		return false
	var view: Dictionary = _save.committed_view()
	return (
		view.error == OK
		and int(view.lineage) == _lineage
		and view.sections.settings.language == _language
		and _host.progress.highest_completed_slot() == _slot
	)


func _refresh() -> void:
	if not is_inside_tree() or _host == null:
		return
	var valid: bool = _owners_ready()
	var state: StringName = _service.rewarded_state() if valid else &"unavailable"
	if _attempt and state not in [&"busy", &"pending_reward"]:
		for entry: Dictionary in _economy.journal():
			if (
				entry.operation == "grant"
				and entry.reason == str(_reason)
				and entry.amounts == {"coins": _extra}
			):
				_doubled = true
				coins.set_value(_base + _extra)
				break
		_attempt = false
		_message_key = "" if _doubled else "level.complete.no_ad"
	double_button.visible = (
		_presented
		and not _doubled
		and _extra > 0
		and _slot >= _config.get_int(&"unlocks.double_reward_slot")
		and _config.get_bool(&"ads.rewarded.double.enabled")
	)
	double_button.set_busy(state == &"busy")
	double_button.disabled = not valid or state not in [&"ready", &"pending_reward"] or _requesting
	double_button.text_key = (
		"level.tool.retry" if state == &"pending_reward" else "level.complete.double"
	)
	number.text = tr("level.hud.level_n") % _slot
	credits.text = tr("level.complete.pieces") % [_pieces, _total]
	if not postcard.visible:
		credits.text += "\n" + tr("journey.location.missing_art")
	var key: String = "level.hint.reward_retry" if state == &"pending_reward" else _message_key
	if double_button.visible and state == &"unavailable":
		key = "level.complete.no_ad"
	message.text = tr(key) if not key.is_empty() else ""
	message.visible = not key.is_empty()
	if _presented:
		for pill: CurrencyPill in [coins, stars]:
			pill.custom_minimum_size.x = (
				Tokens.Touch.MIN_TARGET
				+ Tokens.Space.S
				+ (
					pill
					. get_theme_font("font")
					. get_string_size(
						str(pill.value),
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						pill.get_theme_font_size("font_size")
					)
					. x
				)
			)
		_host.set_completion_reward_busy(busy())


func _continue_failed(_error: Error) -> void:
	_host.retry_continuation()


func _enter_tree() -> void:
	if _host != null:
		_resume.call_deferred()


func _resume() -> void:
	if is_inside_tree():
		_connect()
		_present()


func _exit_tree() -> void:
	if _host == null:
		return
	if _host.completion_layer.visibility_changed.is_connected(_present):
		_host.completion_layer.visibility_changed.disconnect(_present)
	if is_instance_valid(_service) and _service.shop_changed.is_connected(_refresh):
		_service.shop_changed.disconnect(_refresh)
	if is_instance_valid(_nav) and _nav.is_connected("campaign_continue_failed", _continue_failed):
		_nav.disconnect("campaign_continue_failed", _continue_failed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _host != null:
		_refresh()
