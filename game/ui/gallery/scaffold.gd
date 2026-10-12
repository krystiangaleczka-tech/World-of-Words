extends ScreenScaffold
## Catalog entry: asymmetric passive slots, cover art and optional footer.

var _status: Label


func _ready() -> void:
	super._ready()
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray(
		[get_theme_color(&"BG", &"Palette"), get_theme_color(&"SURFACE_ALT", &"Palette")]
	)
	var art: GradientTexture2D = GradientTexture2D.new()
	art.gradient = gradient
	background = art
	top_bar = TopBar.new()
	top_bar.transparent = false
	top_bar.configure(
		[_icon("house")], "gallery.scaffold.title", [_icon("coins"), _icon("settings")]
	)
	var caption: Label = _label("gallery.scaffold.body")
	caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_child(caption)
	_status = _label("")
	_status.name = "FitStatus"
	body.add_child(_status)
	bottom = _label("gallery.scaffold.footer")
	bottom.custom_minimum_size.y = Tokens.Touch.MIN_TARGET
	top_bar.fits_changed.connect(_on_fit)
	resized.connect(_refresh_fit)
	call_deferred("_refresh_fit")


func _icon(name_value: String) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/icons/%s.svg" % name_value) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * Tokens.Type.SUBTITLE
	icon.modulate = get_theme_color(&"PRIMARY", &"Palette")
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _label(key: String) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = tr(key) if not key.is_empty() else ""
	label.theme_type_variation = &"Body"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _on_fit(_value: bool) -> void:
	_refresh_fit()


func _refresh_fit() -> void:
	if _status != null:
		_status.text = "" if top_bar.fits else tr("gallery.scaffold.overflow")


func _exit_tree() -> void:
	if top_bar != null and top_bar.fits_changed.is_connected(_on_fit):
		top_bar.fits_changed.disconnect(_on_fit)
	if resized.is_connected(_refresh_fit):
		resized.disconnect(_refresh_fit)
	super._exit_tree()
