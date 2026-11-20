class_name IslandHome
extends ScreenScaffold
## The illustrated campaign map uses the saved slot as its single Play destination.

var _artwork: CampaignIslands
var _slot: int
var _nav: Node
var _play: PrimaryButton
var _status: Label
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
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Islands"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.name = "IslandMap"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", Tokens.Space.M)
	grid.add_theme_constant_override("v_separation", Tokens.Space.M)
	scroll.add_child(grid)
	for island: CampaignIslands.Island in _artwork.islands:
		_add_island(grid, island)
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
	_refresh_copy()


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


func _add_island(grid: GridContainer, island: CampaignIslands.Island) -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	grid.add_child(column)
	var marker: TextureRect = CatalogSurface.icon(load(island.marker_path) as Texture2D)
	marker.custom_minimum_size = Vector2(0, Tokens.ISLAND_MARKER_HEIGHT)
	marker.self_modulate.a = Tokens.ISLAND_LOCKED_OPACITY if _slot < island.first else 1.0
	column.add_child(marker)
	_names.append(_label(column, &"Subtitle"))
	_captions.append(_label(column, &"Caption"))


func _label(parent: Control, variation: StringName) -> Label:
	var label: Label = CatalogSurface.label(variation)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _refresh_copy() -> void:
	for index: int in _artwork.islands.size():
		var island: CampaignIslands.Island = _artwork.islands[index]
		_names[index].text = tr(island.name_key)
		if _slot < island.first:
			_captions[index].text = tr("home.islands.unlocks") % island.first
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
