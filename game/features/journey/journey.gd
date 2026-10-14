extends ScreenScaffold
## One-region, read-only journey. Campaign completion and postcard credits stay independent.

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _config: CONFIG_SCRIPT
var _nav: Node
var _art_resolver: Callable
var _catalog: LocaleCatalog = LocaleCatalog.new()
var _list: VBoxContainer
var _empty: StatePanel
var _heading: Label
var _summary: Label
var _stars: CurrencyPill
var _rows: Array[Dictionary] = []
var _region_complete: bool = false
var _back_error: bool = false


## @api Nav supplies its current service identities; previews may inject an art resolver.
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
	if _list != null:
		if not top_bar.fits_changed.is_connected(_refresh_heading):
			top_bar.fits_changed.connect(_refresh_heading)
		call_deferred("refresh")


func _ready() -> void:
	if _nav == null:
		_save = Save
		_content = Content
		_config = Config
		_nav = Nav
	super._ready()
	var back: IconButton = IconButton.new()
	back.name = "Back"
	back.configure_icon(preload("res://assets/icons/arrow-left.svg"), "journey.main.back")
	back.pressed.connect(_go_back)
	_stars = CurrencyPill.new()
	_stars.name = "Stars"
	_stars.kind = &"stars"
	top_bar = TopBar.new()
	top_bar.configure([back], "journey.main.title", [_stars])
	_stars.autowrap_mode = TextServer.AUTOWRAP_OFF
	_heading = CatalogSurface.label(&"Title")
	_heading.name = "RegionTitle"
	body.add_child(_heading)
	top_bar.fits_changed.connect(_refresh_heading)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Locations"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "LocationList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Tokens.Space.M)
	scroll.add_child(_list)
	_empty = StatePanel.new()
	_empty.name = "Unavailable"
	_empty.configure(&"unavailable", "journey.main.unavailable", "journey.main.retry")
	body.add_child(_empty)
	_summary = CatalogSurface.label(&"Caption")
	_summary.name = "Summary"
	body.add_child(_summary)
	refresh()


## @api Refresh durable presentation only; no Save writes or campaign pack loads.
func refresh() -> void:
	if _list == null:
		return
	_clear_rows()
	_empty.show()
	_region_complete = false
	_back_error = false
	_stars.set_value(0, false)
	top_bar.title_key = "journey.main.title"
	var state: Dictionary = _state()
	if not state.is_empty():
		var slot: int = int(state.get("current_slot", 1))
		var region: Dictionary = _content.region_for_slot(clampi(slot, 1, _content.slot_count()))
		if not region.is_empty() and _populate(region, state):
			_stars.set_value(int(state.get("stars", 0)), false)
			_region_complete = int(state.get("highest_completed_slot", 0)) >= int(region.last)
			top_bar.title_key = (
				region.name_key if not str(region.name_key).is_empty() else "journey.main.title"
			)
			_empty.hide()
	(_list.get_parent() as Control).visible = not _empty.visible
	_refresh_copy()


func _state() -> Dictionary:
	if (
		not is_instance_valid(_save)
		or not _save.is_loaded()
		or not is_instance_valid(_content)
		or not _content.is_loaded()
		or not is_instance_valid(_config)
		or not _config.has_key(&"meta.postcard.pieces")
	):
		return {}
	var total: int = _config.get_int(&"meta.postcard.pieces")
	if total < 1 or total > LocationPostcard.MAX_PIECES:
		return {}
	var view: Dictionary = _save.committed_view()
	if view.error != OK or view.sections.settings.language != _content.get_language():
		return {}
	return (
		view
		. sections
		. progress
		. by_lang
		. get(str(view.sections.settings.language), SaveSchema.LANGUAGE_STATE)
		. duplicate(true)
	)


func _populate(region: Dictionary, state: Dictionary) -> bool:
	var slot: int = int(region.first)
	while slot <= int(region.last):
		var location: Dictionary = _content.location_for_slot(slot)
		if (
			location.is_empty()
			or int(location.first) != slot
			or int(location.last) < slot
			or int(location.last) > int(region.last)
		):
			_clear_rows()
			return false
		_add_location(location, state)
		slot = int(location.last) + 1
	return not _rows.is_empty()


func _add_location(location: Dictionary, state: Dictionary) -> void:
	var first: int = int(location.first)
	var count: int = int(location.last) - first + 1
	var done: int = clampi(int(state.get("highest_completed_slot", 0)) - first + 1, 0, count)
	var locked: bool = int(state.get("current_slot", 1)) < first
	var total: int = _config.get_int(&"meta.postcard.pieces")
	var pieces: int = clampi(int(state.get("location_pieces", {}).get(location.id, 0)), 0, total)
	var card: Card = Card.new()
	card.name = "Location_" + str(location.id)
	card.title_key = (
		location.name_key if not str(location.name_key).is_empty() else "journey.location.title"
	)
	card.sublabel_key = (
		"journey.location.locked"
		if locked
		else ("journey.location.complete" if done == count else "journey.location.current")
	)
	card.disabled = locked
	card.highlighted = not locked and done < count
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.Space.S)
	var badge: Badge = Badge.new()
	badge.kind = &"lock"
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = locked
	column.add_child(badge)
	var image: Texture2D = _image(location)
	if image != null:
		var postcard: LocationPostcard = LocationPostcard.new()
		postcard.name = "Postcard"
		postcard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		postcard.configure(image, total, pieces, &"thumb")
		column.add_child(postcard)
	else:
		var missing: Label = CatalogSurface.label(&"Caption")
		missing.text = tr("journey.location.missing_art")
		missing.name = "MissingArt"
		column.add_child(missing)
	var progress: CatalogProgressBar = CatalogProgressBar.new()
	progress.name = "PieceProgress"
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.set_value(float(pieces) / total, false)
	column.add_child(progress)
	var credits: Label = CatalogSurface.label(&"Caption")
	credits.name = "Pieces"
	column.add_child(credits)
	var completed: Label = CatalogSurface.label(&"Caption")
	completed.name = "CompletedLevels"
	column.add_child(completed)
	var note: Label = CatalogSurface.label(&"Caption")
	note.name = "Availability"
	column.add_child(note)
	assert(card.configure_body(column) == OK)
	_list.add_child(card)
	_rows.append(
		{
			"card": card,
			"body": column,
			"credits": credits,
			"completed": completed,
			"note": note,
			"first": first,
			"count": count,
			"done": done,
			"pieces": pieces,
			"total": total,
			"locked": locked
		}
	)


func _image(location: Dictionary) -> Texture2D:
	if _art_resolver.is_valid():
		return _art_resolver.call(location.duplicate(true)) as Texture2D
	if str(location.postcard).is_empty():
		return null
	var path: String = "res://content".path_join(_content.get_language()).path_join(
		location.postcard
	)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _refresh_copy() -> void:
	if _summary == null:
		return
	_summary.text = (
		tr("journey.main.back_failed")
		if _back_error
		else (tr("journey.region.complete") if _region_complete else "")
	)
	_summary.visible = not _summary.text.is_empty()
	_refresh_heading(top_bar.fits)
	for row: Dictionary in _rows:
		row.credits.text = tr("journey.location.pieces") % [row.pieces, row.total]
		row.completed.text = (
			(
				tr("journey.location.completed_range")
				% [row.first, row.first + row.done - 1, row.done, row.count]
			)
			if row.done > 0
			else tr("journey.location.completed_none") % row.count
		)
		row.note.text = (
			tr("journey.location.unlock") % row.first
			if row.locked
			else tr("journey.location.postcard_soon")
		)
		var missing: Label = row.body.get_node_or_null("MissingArt")
		if missing != null:
			missing.text = tr("journey.location.missing_art")


func _go_back() -> void:
	if is_instance_valid(_nav):
		_back_error = _nav.handle_back() != OK
		_refresh_copy()


func _refresh_heading(fits: bool) -> void:
	if _heading != null:
		_heading.text = tr(top_bar.title_key)
		_heading.visible = not fits


func _clear_rows() -> void:
	var previous: Array[Dictionary] = _rows
	_rows = []
	for row: Dictionary in previous:
		_list.remove_child(row.card)
		row.card.free()
		row.body.free()


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()


func _exit_tree() -> void:
	if top_bar != null and top_bar.fits_changed.is_connected(_refresh_heading):
		top_bar.fits_changed.disconnect(_refresh_heading)
	_clear_rows()
	_catalog.unregister()
	super._exit_tree()
