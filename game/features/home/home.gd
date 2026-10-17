extends ScreenScaffold
## Returning-player presentation. Reads durable values; Nav owns transitions and persistence.

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")

var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _config: CONFIG_SCRIPT
var _nav: Node
var _art_resolver: Callable
var _catalog: LocaleCatalog = LocaleCatalog.new()
var _surface: PanelContainer
var _title: Label
var _progress: Label
var _progress_bar: CatalogProgressBar
var _next: Label
var _status: Label
var _play: PrimaryButton
var _postcard: LocationPostcard
var _empty: StatePanel
var _coins: CurrencyPill
var _settings: IconButton
var _journey: NavTab
var _slot: int = 0
var _location_key: String = "home.main.location"
var _pieces: int = 0
var _total: int = 0
var _status_key: String = ""


## @api Nav supplies its service identities before mounting; art is an optional preview seam.
func configure(
	save: SAVE_SCRIPT,
	content: CONTENT_SCRIPT,
	config: CONFIG_SCRIPT,
	nav: Node,
	art_resolver: Callable = Callable()
) -> void:
	assert(not is_inside_tree())
	_save = save
	_content = content
	_config = config
	_nav = nav
	_art_resolver = art_resolver


func _enter_tree() -> void:
	super._enter_tree()
	_catalog.register_all()
	if _title != null:
		call_deferred("refresh")


func _ready() -> void:
	if _nav == null:
		_save = Save
		_content = Content
		_config = Config
		_nav = Nav
	super._ready()
	_coins = CurrencyPill.new()
	_coins.name = "Coins"
	_settings = IconButton.new()
	_settings.name = "Settings"
	_settings.configure_icon(preload("res://assets/icons/settings.svg"), "home.nav.settings")
	_settings.pressed.connect(_open_settings)
	top_bar = TopBar.new()
	top_bar.configure([_coins], "", [_settings])
	_coins.autowrap_mode = TextServer.AUTOWRAP_OFF
	_coins.expand_icon = false
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Content"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", Tokens.Space.L)
	_surface = PanelContainer.new()
	_surface.name = "ReadingSurface"
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_surface)
	_surface.add_child(column)
	_refresh_surface()
	_title = _label(column, "Location", &"Title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_postcard = LocationPostcard.new()
	_postcard.name = "Postcard"
	column.add_child(_postcard)
	_empty = StatePanel.new()
	_empty.name = "MissingArt"
	_empty.configure(&"empty", "home.art.title", "home.art.body")
	column.add_child(_empty)
	_progress_bar = CatalogProgressBar.new()
	_progress_bar.name = "PostcardProgress"
	column.add_child(_progress_bar)
	_progress = _label(column, "Progress", &"Caption")
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next = _label(column, "NextLevel", &"Caption")
	_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play = PrimaryButton.new()
	_play.name = "Play"
	_play.text_key = "home.main.play"
	_play.pressed.connect(_continue_campaign)
	column.add_child(_play)
	_status = _label(column, "Status", &"Caption")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_journey = NavTab.new()
	_journey.name = "Journey"
	_journey.configure(preload("res://assets/icons/route.svg"), "home.nav.journey")
	_journey.pressed.connect(_open_journey)
	bottom = _journey
	refresh()


func _label(parent: Node, node_name: String, variation: StringName) -> Label:
	var label: Label = CatalogSurface.label(variation)
	label.name = node_name
	parent.add_child(label)
	return label


## @api Re-read committed values without advancing or writing any owner.
func refresh() -> void:
	if _title == null:
		return
	_slot = 0
	_pieces = 0
	_total = 0
	_location_key = "home.main.location"
	_status_key = "home.main.unavailable"
	background = null
	_postcard.hide()
	_empty.show()
	_coins.set_value(0, false)
	if (
		is_instance_valid(_save)
		and _save.is_loaded()
		and is_instance_valid(_content)
		and is_instance_valid(_config)
		and _config.has_key(&"meta.postcard.pieces")
	):
		var view: Dictionary = _save.committed_view()
		if view.error == OK and _content.is_loaded():
			var language: String = str(view.sections.settings.language)
			if language == _content.get_language():
				var state: Dictionary = view.sections.progress.by_lang.get(language, {})
				_slot = int(state.get("current_slot", 1))
				_coins.set_value(int(view.sections.economy.coins), false)
				_present_location(state)
	_play.disabled = _slot < 1 or _slot > _content_count()
	_settings.disabled = not ResourceLoader.exists("res://features/settings/settings.tscn")
	_journey.implemented = ResourceLoader.exists("res://features/journey/journey.tscn")
	_refresh_copy()


func _content_count() -> int:
	return _content.slot_count() if is_instance_valid(_content) else 0


func _present_location(state: Dictionary) -> void:
	_status_key = "home.main.complete" if _slot > _content.slot_count() else ""
	var location: Dictionary = _content.location_for_slot(clampi(_slot, 1, _content.slot_count()))
	if location.is_empty():
		return
	if not str(location.name_key).is_empty():
		_location_key = location.name_key
	if is_instance_valid(_config) and _config.has_key(&"meta.postcard.pieces"):
		_total = _config.get_int(&"meta.postcard.pieces")
	_pieces = clampi(int(state.get("location_pieces", {}).get(location.id, 0)), 0, _total)
	var image: Texture2D
	if _art_resolver.is_valid():
		image = _art_resolver.call(location.duplicate(true)) as Texture2D
	elif not str(location.postcard).is_empty():
		var path: String = "res://content".path_join(_content.get_language()).path_join(
			location.postcard
		)
		if ResourceLoader.exists(path):
			image = load(path) as Texture2D
	if image != null and _postcard.configure(image, _total, _pieces) == OK:
		background = image
		_postcard.show()
		_empty.hide()


func _continue_campaign() -> void:
	refresh()
	if _play.disabled:
		return
	var error: Error = _nav.go_to_level(_slot) if is_instance_valid(_nav) else ERR_UNCONFIGURED
	if error != OK:
		_status_key = "home.main.route_failed"
		_refresh_copy()


func _open_settings() -> void:
	if not _settings.disabled:
		_nav.go_to_screen(_nav.Screen.SETTINGS)


func _open_journey() -> void:
	if _journey.implemented:
		_nav.go_to_screen(_nav.Screen.JOURNEY)


func _refresh_copy() -> void:
	if _title == null:
		return
	_title.text = tr(_location_key)
	_progress.text = tr("home.main.progress") % [_pieces, _total]
	_progress.visible = _total > 0 and not _postcard.visible
	# Completion is stated once: by the postcard stamp or the Progress caption.
	_progress_bar.visible = _total > 0 and _pieces < _total
	_progress_bar.set_value(float(_pieces) / _total if _total > 0 else 0.0, false)
	_next.text = tr("home.main.level_n") % _slot
	_next.visible = _slot > 0 and _slot <= _content_count()
	_status.text = tr(_status_key) if not _status_key.is_empty() else ""
	_status.visible = not _status_key.is_empty()
	if _settings.disabled:
		_settings.tooltip_text = tr("home.nav.unavailable")
		_settings.accessibility_description = "home.nav.unavailable"


func _refresh_surface() -> void:
	if is_instance_valid(_surface):
		_surface.add_theme_stylebox_override(
			"panel", CatalogSurface.panel(self, Tokens.Space.S, Tokens.Radius.M, &"NONE")
		)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_surface()


func _exit_tree() -> void:
	_catalog.unregister()
	super._exit_tree()
