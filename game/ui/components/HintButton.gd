class_name HintButton
extends IconButton
## @api P1 labelled action remains until explicit final count/price configuration.

signal activated(kind: StringName)
const GLYPHS: Dictionary[StringName, Texture2D] = {
	&"hint": preload("res://assets/icons/lightbulb.svg"),
	&"reveal": preload("res://assets/icons/sparkles.svg")
}
var kind: StringName:
	get:
		return _kind_value
var count: int:
	get:
		return _count
var price: int:
	get:
		return _price
var catalog_mode: bool:
	get:
		return _catalog_mode
var _kind_value: StringName = &"hint"
var _count: int = 0
var _price: int = 0
var _catalog_mode: bool = false
var _footer: HBoxContainer
var _badge: Badge
var _price_row: HBoxContainer
var _price_label: Label
var _coin: TextureRect
var _footer_height: float = 0
var _layout_guard: bool = false
var _pop: Tween
var _catalog: LocaleCatalog = LocaleCatalog.new()


func _init() -> void:
	text_key = "level.hud.hint"


## @api Final presentation opts in explicitly; invalid request preserves P1/final state atomically.
func configure(variant: StringName, amount: int, cost: int) -> Error:
	if not GLYPHS.has(variant) or amount < 0 or cost < 0:
		return ERR_INVALID_PARAMETER
	_stop_pop()
	_catalog_mode = true
	_kind_value = variant
	_count = amount
	_price = cost
	a11y_label_key = "ui.hint.hint" if variant == &"hint" else "ui.hint.reveal"
	if loading:
		_saved_icon = GLYPHS[variant]
		icon = _spinner_texture()
	else:
		icon = GLYPHS[variant]
	_refresh_copy()
	_refresh_theme()
	return OK


## @api Exact caller balances; count changes may pop, but never spend or reveal.
func set_amounts(amount: int, cost: int, animate: bool = true) -> Error:
	if not _catalog_mode:
		return ERR_UNCONFIGURED
	if amount < 0 or cost < 0:
		return ERR_INVALID_PARAMETER
	var changed: bool = _count != amount
	_stop_pop()
	_count = amount
	_price = cost
	_refresh_copy()
	if changed and animate and _count > 0 and is_node_ready() and not Tokens.reduced_motion:
		_badge.pivot_offset = _badge.size / 2
		var half_fast: float = Tokens.dur(Tokens.Motion.FAST) / 2.0
		_pop = create_tween().set_trans(Tokens.Ease.SPRING.x).set_ease(Tokens.Ease.SPRING.y)
		_pop.tween_property(_badge, "scale", Vector2.ONE / Tokens.Action.PRESS_SCALE, half_fast)
		_pop.tween_property(_badge, "scale", Vector2.ONE, half_fast)
		_pop.tween_callback(_stop_pop)
		set_process(true)
	return OK


func _enter_tree() -> void:
	_catalog.register_all()
	super._enter_tree()
	if _footer != null:
		_connect_footer()


func _ready() -> void:
	_footer = HBoxContainer.new()
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_footer)
	_badge = Badge.new()
	_footer.add_child(_badge)
	_price_row = HBoxContainer.new()
	_price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price_row.add_theme_constant_override("separation", Tokens.Space.XS)
	_footer.add_child(_price_row)
	_coin = CatalogSurface.icon(preload("res://assets/icons/coins.svg"))
	_price_row.add_child(_coin)
	_price_label = CatalogSurface.label(&"Numeric")
	_price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_price_row.add_child(_price_label)
	super._ready()
	_connect_footer()
	_refresh_copy()
	_layout_copy()


func _refresh_copy() -> void:
	super._refresh_copy()
	if _footer == null:
		return
	_footer.visible = _catalog_mode
	if not _catalog_mode:
		return
	_badge.text = str(_count)
	_badge.visible = _count > 0
	_price_label.text = str(_price)
	_price_row.visible = _count == 0
	accessibility_description = str(_count if _count > 0 else _price)
	_layout_copy()


func _layout_copy() -> void:
	super._layout_copy()
	if _footer == null or _layout_guard:
		return
	_layout_guard = true
	var minimum: Vector2 = _footer.get_combined_minimum_size() if _catalog_mode else Vector2.ZERO
	_footer.position = Vector2(Tokens.Space.S, maxf(size.y - Tokens.Space.S - minimum.y, 0))
	_footer.size = Vector2(maxf(size.x - Tokens.Space.S * 2, 1), minimum.y)
	if _catalog_mode:
		var width: float = maxf(Tokens.Touch.MIN_TARGET, minimum.x + Tokens.Space.S * 2)
		var height: float = maxf(
			Tokens.Touch.MIN_TARGET, Tokens.Space.S * 3 + Tokens.Space.XL + minimum.y
		)
		custom_minimum_size = Vector2(width, height)
	if not is_equal_approx(_footer_height, minimum.y):
		_footer_height = minimum.y
		_refresh_theme()
	_layout_guard = false


func _refresh_theme() -> void:
	if not is_node_ready() or _refreshing or _sublabel == null:
		return
	super._refresh_theme()
	if not _catalog_mode:
		return
	_refreshing = true
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = get_theme_stylebox(state).duplicate() as StyleBoxFlat
		box.content_margin_bottom += _footer_height + Tokens.Space.XS
		add_theme_stylebox_override(state, box)
	_coin.modulate = _palette(&"COIN")
	_price_label.add_theme_color_override(
		"font_color", _palette(&"TEXT_MUTED" if disabled else &"TEXT")
	)
	_refreshing = false


func _check_disabled() -> void:
	super._check_disabled()
	if _catalog_mode and _price_label != null:
		var foreground: Color = _palette(&"TEXT_MUTED" if disabled else &"TEXT")
		if _price_label.get_theme_color("font_color") != foreground:
			_price_label.add_theme_color_override("font_color", foreground)


func _connect_footer() -> void:
	if not _footer.minimum_size_changed.is_connected(_layout_copy):
		_footer.minimum_size_changed.connect(_layout_copy)
	if not pressed.is_connected(_on_activated):
		pressed.connect(_on_activated)


func _on_activated() -> void:
	if _catalog_mode and not disabled and not loading:
		activated.emit(kind)


func _stop_pop() -> void:
	if _pop != null:
		_pop.kill()
		_pop = null
	if _badge != null:
		_badge.scale = Vector2.ONE


func _process(delta: float) -> void:
	super._process(delta)
	if Tokens.reduced_motion:
		_stop_pop()
	elif _pop != null and _pop.is_running():
		set_process(true)


func _exit_tree() -> void:
	_stop_pop()
	if _footer != null and _footer.minimum_size_changed.is_connected(_layout_copy):
		_footer.minimum_size_changed.disconnect(_layout_copy)
	if pressed.is_connected(_on_activated):
		pressed.disconnect(_on_activated)
	_catalog.unregister()
	super._exit_tree()


func _draw() -> void:
	if not _catalog_mode or not loading:
		super._draw()
		return
	var center: Vector2 = Vector2(size.x / 2, (size.y - _footer_height - Tokens.Space.S) / 2)
	draw_arc(
		center,
		Tokens.Space.S,
		_angle,
		_angle + TAU * (1.0 - 1.0 / Tokens.Space.XS),
		Tokens.Space.M,
		_palette(&"TEXT_MUTED"),
		Tokens.Action.OUTLINE_WIDTH,
		true
	)
