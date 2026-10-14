class_name HomeScreen
extends ScreenScaffold
## Committed presentation only; campaign and wallet owners retain all mutation authority.

var _save: Node
var _content: Node
var _config: Node
var _nav: Node
var _art_loader: Callable
var _catalog: LocaleCatalog = LocaleCatalog.new()
var _slot_messages: Array[Translation] = []
var _title: Label
var _postcard: LocationPostcard
var _pieces: Label
var _panel: StatePanel
var _play: PrimaryButton
var _coins: CurrencyPill
var _settings: IconButton
var _journey: NavTab
var _slot: int = 0
var _location: Dictionary = {}
var _revealed: int = 0
var _total: int = 0


## @api Inject the mounted Nav's actual service owners; no initialization or mutation.
func configure(
	save: Node, content: Node, config: Node, nav: Node, art_loader: Callable = Callable()
) -> void:
	assert(not is_inside_tree())
	_save = save
	_content = content
	_config = config
	_nav = nav
	_art_loader = art_loader


func _ready() -> void:
	super._ready()
	_catalog.register_all()
	var bar: TopBar = TopBar.new()
	_coins = CurrencyPill.new()
	_coins.name = "Coins"
	_settings = IconButton.new()
	_settings.name = "Settings"
	_settings.configure_icon(preload("res://assets/icons/settings.svg"), "home.nav.settings")
	bar.configure([_coins], "", [_settings])
	top_bar = bar
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Content"
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", Tokens.Space.L)
	body.add_child(column)
	_title = CatalogSurface.label(&"Title")
	_title.name = "LocationTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_postcard = LocationPostcard.new()
	_postcard.name = "Postcard"
	_panel = StatePanel.new()
	_panel.name = "State"
	_pieces = CatalogSurface.label(&"Caption")
	_pieces.name = "Pieces"
	_pieces.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play = PrimaryButton.new()
	_play.name = "Play"
	_play.text_key = "home.main.play"
	for child: Control in [_title, _postcard, _panel, _pieces, _play]:
		column.add_child(child)
	_journey = NavTab.new()
	_journey.name = "Journey"
	_journey.configure(preload("res://assets/icons/route.svg"), "home.nav.journey")
	bottom = _journey
	_play.pressed.connect(_on_play)
	_settings.pressed.connect(_on_settings)
	_journey.pressed.connect(_on_journey)
	refresh()


## @api Refresh one copied committed snapshot. No dirty reads, rewards or writes.
# gdlint: disable=max-returns
func refresh() -> Error:
	if _play == null:
		return ERR_UNCONFIGURED
	_play.disabled = true
	_coins.action_enabled = false
	_settings.disabled = not ResourceLoader.exists("res://features/settings/settings.tscn")
	_journey.implemented = ResourceLoader.exists("res://features/journey/journey.tscn")
	_journey.disabled = false
	if not is_instance_valid(_save) or not is_instance_valid(_content):
		return _data_error(ERR_UNCONFIGURED)
	var view: Dictionary = _save.call("committed_view")
	if view.get("error") != OK or not _content.call("is_loaded"):
		return _data_error(ERR_UNAVAILABLE)
	var language: String = view.sections.settings.language
	if language != _content.call("get_language") or not is_instance_valid(_config):
		return _data_error(ERR_UNAVAILABLE)
	if not _config.call("has_key", &"meta.postcard.pieces"):
		return _data_error(ERR_UNCONFIGURED)
	var state: Dictionary = view.sections.progress.by_lang.get(language, {})
	var mode: String = "hc" if view.sections.settings.high_contrast else "default"
	var sizes: Array[String] = ["100", "115", "130"]
	theme = (
		load(
			(
				"res://ui/theme/generated/theme_%s_%s.tres"
				% [mode, sizes[view.sections.settings.text_scale]]
			)
		)
		as Theme
	)
	_slot = int(state.get("current_slot", 1))
	# Numeric balances occupy one native button line inside the fixed-height TopBar.
	_coins.autowrap_mode = TextServer.AUTOWRAP_OFF
	_coins.expand_icon = false
	_coins.value = int(view.sections.economy.coins)
	_total = _config.call("get_int", &"meta.postcard.pieces")
	if _total < 1 or _total > LocationPostcard.MAX_PIECES:
		return _data_error(ERR_INVALID_DATA)
	_location = _content.call("location_for_slot", _slot)
	_revealed = clampi(
		int(state.get("location_pieces", {}).get(_location.get("id", ""), 0)), 0, _total
	)
	if state.get("postcards", []).has(_location.get("id", "")):
		_revealed = _total
	_bind_slot_copy()
	_refresh_labels()
	if _slot > int(_content.call("slot_count")) or _content.call("level_for_slot", _slot) == null:
		return _data_error(ERR_FILE_NOT_FOUND)
	var path: String = str(_location.get("postcard", ""))
	var image: Texture2D = null
	if _art_loader.is_valid():
		image = _art_loader.call(path) as Texture2D
	elif not path.is_empty() and ResourceLoader.exists("res://assets/" + path):
		image = load("res://assets/" + path) as Texture2D
	_postcard.visible = image != null
	_panel.visible = image == null
	_pieces.visible = image == null
	background = image
	if image != null:
		var error: Error = _postcard.configure(image, _total, _revealed)
		if error != OK:
			return _data_error(error)
	else:
		_panel.configure(&"empty", "home.postcard.unavailable", "home.postcard.pending")
	_play.disabled = false
	return OK


# gdlint: enable=max-returns


func _data_error(error: Error) -> Error:
	background = null
	_postcard.visible = false
	_pieces.visible = false
	_panel.visible = true
	_panel.configure(&"error", "home.state.error", "home.state.try_again")
	_play.disabled = true
	_title.text = tr("home.main.title")
	return error


func _bind_slot_copy() -> void:
	_clear_slot_copy()
	var key: StringName = StringName("home.main.level_n_" + str(get_instance_id()))
	for language: String in ["pl", "en"]:
		var source: Translation = (
			load("res://locale/home." + language + ".translation") as Translation
		)
		var message: Translation = Translation.new()
		message.set_locale(language)
		message.add_message(key, String(source.get_message(&"home.main.level_n")) % str(_slot))
		_slot_messages.append(message)
		TranslationServer.add_translation(message)
	_play.sublabel_key = str(key)


func _clear_slot_copy() -> void:
	for message: Translation in _slot_messages:
		TranslationServer.remove_translation(message)
	_slot_messages.clear()


func _refresh_labels() -> void:
	var key: String = str(_location.get("name_key", ""))
	var title: String = tr(key) if not key.is_empty() else ""
	_title.text = title if not title.is_empty() and title != key else tr("home.main.title")
	_pieces.text = tr("home.postcard.progress") % [str(_revealed), str(_total)]


func _on_play() -> void:
	if _play.disabled or refresh() != OK:
		return
	_request_route(&"go_to_level", _slot)


func _on_settings() -> void:
	if not _settings.disabled:
		_request_route(&"go_to_screen", Nav.Screen.SETTINGS)


func _on_journey() -> void:
	if _journey.implemented and not _journey.disabled:
		_request_route(&"go_to_screen", Nav.Screen.JOURNEY)


func _request_route(method: StringName, destination: int) -> void:
	if not is_instance_valid(_nav):
		_data_error(ERR_UNCONFIGURED)
		return
	_play.disabled = true
	_settings.disabled = true
	_journey.disabled = true
	var error: Error = _nav.call(method, destination)
	if error != OK:
		refresh()
		_panel.visible = true
		_panel.configure(&"error", "home.state.error", "home.state.try_again")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _title != null:
		_refresh_labels()


func _exit_tree() -> void:
	if _play != null:
		_play.pressed.disconnect(_on_play)
		_settings.pressed.disconnect(_on_settings)
		_journey.pressed.disconnect(_on_journey)
	_clear_slot_copy()
	_catalog.unregister()
	super._exit_tree()
