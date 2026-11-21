class_name IslandHome
extends ScreenScaffold
## The illustrated campaign map uses the saved slot as its single Play destination.

const ISLANDS_PER_PAGE: int = 4

var _artwork: CampaignIslands
var _slot: int
var _nav: Node
var _play: PrimaryButton
var _status: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _previous: SecondaryButton
var _next: SecondaryButton
var _page_label: Label
var _page: int
var _page_count: int
var _captions: Array[Label] = []
var _names: Array[Label] = []
var _status_key: String = ""


func configure_islands(artwork: CampaignIslands, slot: int, nav: Node) -> void:
	_artwork = artwork
	_slot = slot
	_nav = nav


func _ready() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Tokens.ISLAND_SKY, Tokens.Palette.BG])
	var sky: GradientTexture2D = GradientTexture2D.new()
	sky.gradient = gradient
	sky.fill_to = Vector2.DOWN
	background = sky
	hide_background_in_high_contrast = true
	super._ready()
	_build_header()
	_scroll = ScrollContainer.new()
	_scroll.name = "Islands"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "IslandMap"
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", Tokens.Space.M)
	_grid.add_theme_constant_override("v_separation", Tokens.Space.M)
	_scroll.add_child(_grid)
	_build_pager()
	_status = _label(body, &"Caption")
	_play = PrimaryButton.new()
	_play.name = "Play"
	_play.text_key = "home.main.play"
	_play.pressed.connect(_continue_campaign)
	var complete: bool = _slot > _artwork.islands.back().last
	if complete:
		_status_key = "home.main.complete"
	_play.visible = not complete
	_play.disabled = complete
	bottom = _play
	var last_slot: int = _artwork.islands.back().last
	var index: int = _artwork.index_for_slot(clampi(_slot, 1, last_slot))
	_show_page(floori(float(index) / ISLANDS_PER_PAGE))


func _build_header() -> void:
	var leading: Array[Control] = []
	if _nav.home_unlocked():
		var journey: IconButton = IconButton.new()
		journey.configure_icon(preload("res://assets/icons/route.svg"), "home.nav.journey")
		journey.pressed.connect(_open_journey)
		leading.append(journey)
	var settings: IconButton = IconButton.new()
	settings.name = "Settings"
	settings.configure_icon(preload("res://assets/icons/settings.svg"), "home.nav.settings")
	settings.disabled = not _nav.settings_available()
	settings.pressed.connect(_open_settings)
	top_bar = TopBar.new()
	top_bar.configure(leading, "home.islands.title", [settings])


func _build_pager() -> void:
	_page_count = ceili(float(_artwork.islands.size()) / ISLANDS_PER_PAGE)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.Space.S)
	body.add_child(row)
	_previous = SecondaryButton.new()
	_previous.name = "PreviousIslandPage"
	_previous.text_key = "home.islands.previous"
	_previous.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_previous.pressed.connect(_change_page.bind(-1))
	row.add_child(_previous)
	_page_label = _label(row, &"Caption")
	_page_label.name = "IslandPage"
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_next = SecondaryButton.new()
	_next.name = "NextIslandPage"
	_next.text_key = "home.islands.next"
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(_change_page.bind(1))
	row.add_child(_next)
	row.visible = _page_count > 1


func _change_page(direction: int) -> void:
	var page: int = clampi(_page + direction, 0, _page_count - 1)
	if page != _page:
		_show_page(page)


func _show_page(page: int) -> void:
	_page = page
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_names.clear()
	_captions.clear()
	var first: int = _page * ISLANDS_PER_PAGE
	for index: int in range(first, mini(first + ISLANDS_PER_PAGE, _artwork.islands.size())):
		_add_island(_artwork.islands[index])
	_scroll.scroll_vertical = 0
	_previous.disabled = _page == 0
	_next.disabled = _page + 1 == _page_count
	_refresh_copy()


func _add_island(island: CampaignIslands.Island) -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_grid.add_child(column)
	var marker: TextureRect = CatalogSurface.icon(island.theme.marker)
	marker.custom_minimum_size = Vector2(0, Tokens.ISLAND_MARKER_HEIGHT)
	marker.self_modulate.a = Tokens.ISLAND_LOCKED_OPACITY if _slot < island.first else 1.0
	column.add_child(marker)
	_names.append(_label(column, &"Subtitle"))
	var span: Label = _label(column, &"Caption")
	span.name = "IslandRange"
	_captions.append(_label(column, &"Caption"))


func _label(parent: Control, variation: StringName) -> Label:
	var label: Label = CatalogSurface.label(variation)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _refresh_copy() -> void:
	_page_label.text = tr("home.islands.page") % [_page + 1, _page_count]
	for index: int in _names.size():
		var island: CampaignIslands.Island = _artwork.islands[_page * ISLANDS_PER_PAGE + index]
		_names[index].text = tr(island.theme.name_key)
		var span: Label = _grid.get_child(index).get_node("IslandRange") as Label
		span.text = tr("home.islands.range") % [island.first, island.last]
		if _slot < island.first:
			_captions[index].text = tr("home.islands.locked")
		elif _slot <= island.last:
			_captions[index].text = tr("home.main.level_n") % _slot
		else:
			_captions[index].text = tr("home.islands.complete")
	_status.text = tr(_status_key) if not _status_key.is_empty() else ""
	_status.visible = not _status_key.is_empty()


func _continue_campaign() -> void:
	if not _play.disabled and _nav.go_to_level(_slot) != OK:
		_status_key = "home.main.route_failed"
		_refresh_copy()


func _open_journey() -> void:
	_nav.go_to_screen(_nav.Screen.JOURNEY)


func _open_settings() -> void:
	_nav.go_to_screen(_nav.Screen.SETTINGS)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(_play):
		_refresh_copy()
