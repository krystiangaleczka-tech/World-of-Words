extends ScreenScaffold
## Selected postcard presentation. Credits are committed inputs, never awarded here.

const SAVE_SCRIPT: Script = preload("res://services/save.gd")
const CONTENT_SCRIPT: Script = preload("res://services/content.gd")
const CONFIG_SCRIPT: Script = preload("res://services/config.gd")
var _save: SAVE_SCRIPT
var _content: CONTENT_SCRIPT
var _config: CONFIG_SCRIPT
var _nav: Node
var _slot: int = 0
var _reveal_pending: bool = false
var _art_resolver: Callable
var _catalog: LocaleCatalog = LocaleCatalog.new()
var _card: LocationPostcard
var _missing: StatePanel
var _title: Label
var _fact: Label
var _credits: Label
var _complete: Label
var _status: Label
var _continue: PrimaryButton
var _stars: CurrencyPill
var _surface: PanelContainer
var _overlay: Control
var _burst: RewardBurst
var _name_key: String = "postcard.main.location"
var _fact_key: String = ""
var _status_key: String = ""
var _pieces: int = 0
var _total: int = 0
var _next: int = 0


## @api Selected campaign slot identifies location only; reveal is one-shot presentation intent.
func configure(
	save: SAVE_SCRIPT,
	content: CONTENT_SCRIPT,
	config: CONFIG_SCRIPT,
	nav: Node,
	slot: int,
	reveal_latest: bool = false
) -> void:
	assert(not is_inside_tree())
	_save = save
	_content = content
	_config = config
	_nav = nav
	_slot = slot
	_reveal_pending = reveal_latest


## @api Optional pre-mount texture seam for deterministic previews and tests.
func configure_art(resolver: Callable) -> void:
	assert(not is_inside_tree())
	_art_resolver = resolver


func _enter_tree() -> void:
	super._enter_tree()
	_catalog.register_all()
	if _card != null:
		call_deferred("refresh")


func _ready() -> void:
	super._ready()
	var back: IconButton = IconButton.new()
	back.name = "Back"
	back.configure_icon(preload("res://assets/icons/arrow-left.svg"), "postcard.main.back")
	back.pressed.connect(_go_back)
	_stars = CurrencyPill.new()
	_stars.name = "Stars"
	_stars.kind = &"stars"
	top_bar = TopBar.new()
	top_bar.configure([back], "", [_stars])
	_stars.autowrap_mode = TextServer.AUTOWRAP_OFF
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Content"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_surface = PanelContainer.new()
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_surface)
	_refresh_surface()
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.Space.L)
	_surface.add_child(column)
	_card = LocationPostcard.new()
	_card.name = "Postcard"
	column.add_child(_card)
	_missing = StatePanel.new()
	_missing.name = "MissingArt"
	_missing.configure(&"empty", "postcard.art.title", "postcard.art.body")
	column.add_child(_missing)
	_title = _label(column, "Location", &"Title")
	_fact = _label(column, "Fact", &"Body")
	_credits = _label(column, "Credits", &"Caption")
	_complete = _label(column, "Complete", &"Subtitle")
	_continue = PrimaryButton.new()
	_continue.name = "Continue"
	_continue.text_key = "postcard.main.continue"
	_continue.pressed.connect(_continue_campaign)
	column.add_child(_continue)
	_status = _label(column, "Status", &"Caption")
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_burst = RewardBurst.new()
	_burst.name = "RevealFeedback"
	_overlay.add_child(_burst)
	refresh()
	if is_instance_valid(_nav) and _nav.mounted_screen() == self:
		_nav.transition_finished.connect(_transition_finished)
	else:
		call_deferred("_present_reveal")
	set_process(false)


func _label(parent: Node, node_name: String, variation: StringName) -> Label:
	var label: Label = CatalogSurface.label(variation)
	label.name = node_name
	parent.add_child(label)
	return label


## @api Re-read current campaign and selected location; refreshing never repeats reveal feedback.
func refresh() -> void:
	if _card == null:
		return
	_next = 0
	_total = 0
	_pieces = 0
	_name_key = "postcard.main.location"
	_fact_key = ""
	_status_key = "postcard.main.unavailable"
	_stars.set_value(0, false)
	_card.hide()
	_missing.show()
	var context: Dictionary = _context()
	if not context.is_empty():
		var location: Dictionary = context.location
		_total = _config.get_int(&"meta.postcard.pieces")
		_pieces = clampi(
			int(context.progress.get("location_pieces", {}).get(location.id, 0)), 0, _total
		)
		_next = int(context.progress.get("current_slot", 1))
		_stars.set_value(int(context.progress.get("stars", 0)), false)
		_name_key = (
			location.name_key if not str(location.name_key).is_empty() else "postcard.main.location"
		)
		_fact_key = "location.%s.fact" % location.id
		_status_key = "postcard.main.terminal" if _next > _content.slot_count() else ""
		var image: Texture2D = _image(location)
		if image != null:
			var shown: int = _pieces - 1 if _reveal_pending and _pieces > 0 else _pieces
			if _card.configure(image, _total, shown) == OK:
				_card.show()
				_missing.hide()
	_continue.disabled = (
		_next < 1 or _next > (_content.slot_count() if is_instance_valid(_content) else 0)
	)
	_refresh_copy()


func _context() -> Dictionary:
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
	var state: Dictionary = view.sections.progress.by_lang.get(
		str(view.sections.settings.language), SaveSchema.LANGUAGE_STATE
	)
	var location: Dictionary = _content.location_for_slot(_slot)
	if location.is_empty() or int(state.get("current_slot", 1)) < int(location.first):
		return {}
	return {"location": location, "progress": state}


func _image(location: Dictionary) -> Texture2D:
	if _art_resolver.is_valid():
		return _art_resolver.call(location.duplicate(true)) as Texture2D
	if str(location.postcard).is_empty():
		return null
	var path: String = "res://content".path_join(_content.get_language()).path_join(
		location.postcard
	)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _transition_finished() -> void:
	call_deferred("_present_reveal")


func _present_reveal() -> void:
	if not is_inside_tree() or not _reveal_pending:
		return
	_reveal_pending = false
	if _card.visible and _pieces > 0:
		_card.reveal_next()
		var origin: Vector2 = (
			_overlay.get_global_transform().affine_inverse() * _card.get_global_rect().get_center()
		)
		_burst.play(&"postcard_piece", 1, origin)
		set_process(_card.state == &"revealing")
	_update_complete()


func _process(_delta: float) -> void:
	if _card.state != &"revealing":
		_update_complete()
		set_process(false)


func _update_complete() -> void:
	_complete.visible = (
		_total > 0 and _pieces == _total and (not _card.visible or _card.state == &"complete")
	)


func _continue_campaign() -> void:
	refresh()
	if _continue.disabled:
		return
	if not is_instance_valid(_nav) or _nav.go_to_level(_next) != OK:
		_status_key = "postcard.main.route_failed"
		_refresh_copy()


func _go_back() -> void:
	if is_instance_valid(_nav) and _nav.handle_back() != OK:
		_status_key = "postcard.main.route_failed"
		_refresh_copy()


func _refresh_copy() -> void:
	if _title == null:
		return
	_title.text = tr(_name_key)
	var fact: String = tr(_fact_key) if not _fact_key.is_empty() else ""
	var missing: bool = fact.is_empty() or fact == _fact_key
	if (
		TranslationServer.pseudolocalization_enabled
		and fact == TranslationServer.pseudolocalize(_fact_key)
	):
		missing = true
	_fact.text = tr("postcard.main.fact_pending") if missing else fact
	_credits.text = tr("postcard.main.credits") % [_pieces, _total]
	_credits.visible = _total > 0 and not _card.visible
	_complete.text = tr("postcard.main.complete")
	_update_complete()
	_status.text = tr(_status_key) if not _status_key.is_empty() else ""
	_status.visible = not _status_key.is_empty()


func _refresh_surface() -> void:
	if is_instance_valid(_surface):
		_surface.add_theme_stylebox_override("panel", CatalogSurface.panel(self))


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_surface()


func _exit_tree() -> void:
	_reveal_pending = false
	set_process(false)
	if is_instance_valid(_nav) and _nav.transition_finished.is_connected(_transition_finished):
		_nav.transition_finished.disconnect(_transition_finished)
	if is_instance_valid(_burst):
		_burst.cancel()
	_catalog.unregister()
	super._exit_tree()
