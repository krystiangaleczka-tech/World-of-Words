class_name GalleryShell
extends Control
## @api Debug gallery tooling. One owner per process; no saved settings.

const SIZES: Dictionary[StringName, Vector2i] = {
	&"COMPACT": Vector2i(1080, 1920),
	&"REGULAR": Vector2i(1080, 2340),
	&"TABLET": Vector2i(1440, 1920)
}
const LANGUAGES: Array[StringName] = [&"PL", &"EN", &"PSEUDO"]
const PERCENTS: Array[int] = [100, 115, 130]
const PAGES: Dictionary[StringName, String] = {
	&"Samples": "res://ui/gallery/samples.gd",
	&"Controls": "res://ui/gallery/controls.tscn",
	&"Wheel": "res://ui/gallery/wheel.tscn",
	&"Board": "res://ui/gallery/board.tscn",
	&"Debug": "res://ui/gallery/debug_components.tscn",
	&"Scaffold": "res://ui/gallery/scaffold.tscn",
	&"Actions": "res://ui/gallery/actions.tscn",
	&"Icons": "res://ui/gallery/icons.tscn",
	&"Currency": "res://ui/gallery/currency.tscn",
	&"Powerups": "res://ui/gallery/powerups.tscn",
	&"SettingsControls": "res://ui/gallery/settings_controls.tscn",
	&"Content": "res://ui/gallery/content.tscn",
	&"Overlays": "res://ui/gallery/overlays.tscn"
}
const PSEUDO: String = "internationalization/pseudolocalization/"
const OPTIONS: Dictionary[String, Variant] = {
	"use_pseudolocalization": false,
	"expansion_ratio": 0.35,
	"replace_with_accents": true,
	"double_vowels": false
}

var _layout: StringName = &"REGULAR"
var _language: StringName = &"PL"
var _hc: bool = false
var _percent: int = 100
var _reduced: bool = false
var _insets: bool = false
var _page: StringName = &"Samples"
var _catalog: LocaleCatalog = LocaleCatalog.new()
var _previous_locale: String
var _previous_pseudo: bool
var _previous_reduced: bool
var _previous_settings: Dictionary[String, Variant] = {}
var _viewport: SubViewport
var _screen: ScreenScaffold
var _display: SubViewportContainer
var _host: Control
var _note: Label
var _choices: Array[OptionButton] = []
var _toggles: Array[CheckButton] = []
var _signals: Array[Signal] = []


func _enter_tree() -> void:
	_previous_locale = TranslationServer.get_locale()
	_previous_pseudo = TranslationServer.pseudolocalization_enabled
	_previous_reduced = Tokens.reduced_motion
	for key: String in OPTIONS:
		var path: String = PSEUDO + key
		_previous_settings[path] = (
			ProjectSettings.get_setting(path) if ProjectSettings.has_setting(path) else null
		)
		ProjectSettings.set_setting(path, OPTIONS[key])
	TranslationServer.reload_pseudolocalization()
	_catalog.register_all()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Tokens.Palette.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column: VBoxContainer = VBoxContainer.new()
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	for values: Array in [SIZES.keys(), LANGUAGES, PERCENTS, PAGES.keys()]:
		var choice: OptionButton = OptionButton.new()
		choice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.add_theme_font_size_override("font_size", Tokens.Type.CAPTION)
		row.add_child(choice)
		for value: Variant in values:
			choice.add_item(str(value))
		_choices.append(choice)
		choice.item_selected.connect(_on_change)
		_signals.append(choice.item_selected)
	var toggles_column: VBoxContainer = VBoxContainer.new()
	column.add_child(toggles_column)
	for key: String in ["contrast", "motion", "insets"]:
		var toggle: CheckButton = CheckButton.new()
		toggle.name = key
		toggle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.add_theme_font_size_override("font_size", Tokens.Type.CAPTION)
		for state: String in [
			"font_color",
			"font_hover_color",
			"font_pressed_color",
			"font_hover_pressed_color",
			"font_focus_color"
		]:
			toggle.add_theme_color_override(state, Tokens.Palette.TEXT)
		toggles_column.add_child(toggle)
		_toggles.append(toggle)
		toggle.toggled.connect(_on_change)
		_signals.append(toggle.toggled)
	var note: Label = Label.new()
	_note = note
	note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	note.name = "ProvisionalNote"
	note.text = tr("gallery.shell.provisional")
	note.theme_type_variation = &"Caption"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	_host = Control.new()
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_host.clip_contents = true
	column.add_child(_host)
	_display = SubViewportContainer.new()
	_host.add_child(_display)
	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_display.add_child(_viewport)
	_host.resized.connect(_fit)
	_apply()


## @api Invalid input preserves the current configuration atomically.
func configure(
	layout: StringName,
	language: StringName,
	high_contrast: bool,
	text_percent: int,
	reduced: bool,
	insets: bool,
	page: StringName = &"Samples"
) -> Error:
	if (
		not SIZES.has(layout)
		or language not in LANGUAGES
		or text_percent not in PERCENTS
		or not PAGES.has(page)
	):
		return ERR_INVALID_PARAMETER
	_layout = layout
	_language = language
	_hc = high_contrast
	_percent = text_percent
	_reduced = reduced
	_insets = insets
	_page = page
	if is_node_ready():
		_apply()
	return OK


func preview_viewport() -> SubViewport:
	return _viewport


func preview_screen() -> ScreenScaffold:
	return _screen


func _on_change(_value: Variant) -> void:
	configure(
		StringName(_choices[0].get_item_text(_choices[0].selected)),
		LANGUAGES[_choices[1].selected],
		_toggles[0].button_pressed,
		PERCENTS[_choices[2].selected],
		_toggles[1].button_pressed,
		_toggles[2].button_pressed,
		PAGES.keys()[_choices[3].selected]
	)


func _apply() -> void:
	TranslationServer.pseudolocalization_enabled = _language == &"PSEUDO"
	TranslationServer.set_locale("pl" if _language == &"PL" else "en")
	for i: int in PAGES.size():
		_choices[3].set_item_text(i, tr("gallery.page." + str(PAGES.keys()[i]).to_lower()))
	Tokens.reduced_motion = _reduced
	_choices[0].select(SIZES.keys().find(_layout))
	_choices[1].select(LANGUAGES.find(_language))
	_choices[2].select(PERCENTS.find(_percent))
	_choices[3].select(PAGES.keys().find(_page))
	for i: int in _toggles.size():
		_toggles[i].text = tr("gallery.shell." + _toggles[i].name)
		_toggles[i].set_pressed_no_signal([_hc, _reduced, _insets][i])
	_note.text = tr("gallery.shell.provisional")
	if is_instance_valid(_screen):
		_viewport.remove_child(_screen)
		_screen.queue_free()
	var path: String = PAGES[_page]
	_screen = (
		(
			(load(path) as GDScript).new() as ScreenScaffold
			if _page == &"Samples"
			else (load(path) as PackedScene).instantiate()
		)
		as ScreenScaffold
	)
	_screen.theme = (
		load("res://ui/theme/generated/theme_%s_%d.tres" % ["hc" if _hc else "default", _percent])
		as Theme
	)
	# Nonzero negative sentinel prevents the scaffold from reading the desktop safe area.
	_screen.debug_insets = Rect2(Vector2.ONE * -1, Vector2.ONE * -1)
	if _insets:
		_screen.debug_insets = Rect2(Vector2.ONE * Tokens.Space.M, Vector2.ONE * Tokens.Space.L)
	_viewport.size = SIZES[_layout]
	_screen.size = Vector2(_viewport.size)
	_viewport.add_child(_screen)
	(_screen.get_child(0) as ColorRect).color = _screen.theme.get_color(&"BG", &"Palette")
	_fit()


func _fit() -> void:
	if _host == null or _viewport == null:
		return
	var dimensions: Vector2 = Vector2(_viewport.size)
	var ratio: float = minf(_host.size.x / dimensions.x, _host.size.y / dimensions.y)
	_display.size = dimensions
	_display.scale = Vector2.ONE * maxf(ratio, 0)
	_display.position = (_host.size - dimensions * ratio) / 2.0


func _exit_tree() -> void:
	for connected: Signal in _signals:
		if connected.is_connected(_on_change):
			connected.disconnect(_on_change)
	if is_instance_valid(_host) and _host.resized.is_connected(_fit):
		_host.resized.disconnect(_fit)
	_catalog.unregister()
	for path: String in _previous_settings:
		ProjectSettings.set_setting(path, _previous_settings[path])
	TranslationServer.reload_pseudolocalization()
	TranslationServer.pseudolocalization_enabled = _previous_pseudo
	TranslationServer.set_locale(_previous_locale)
	Tokens.reduced_motion = _previous_reduced
