class_name LevelP2Hud
extends Node
## Opt-in presentation only; owners retain all wallet/progress mutations.

signal navigation_requested(target: StringName)
signal shop_requested
signal powerup_requested(kind: StringName)

const ECONOMY: Script = preload("res://services/economy.gd")
const CONFIG: Script = preload("res://services/config.gd")
const SAVE: Script = preload("res://services/save.gd")
const REQUIRED_KEYS: PackedStringArray = [
	"unlocks.shuffle_slot",
	"unlocks.hint_slot",
	"unlocks.reveal_slot",
	"unlocks.journey_slot",
	"unlocks.bonus_meter_slot",
	"economy.price.hint",
	"economy.price.reveal",
	"bonus.chest.words_required"
]
var bar: TopBar
var home: IconButton
var settings: IconButton
var coins: CurrencyPill
var number: Label
var meter: BonusMeter
var reveal: HintButton
var hint: HintButton
var shuffle: IconButton
var _meter_width: float = 0.0
var _economy: ECONOMY
var _config: CONFIG
var _save: SAVE
var _bus: Node
var _slot: int
var _host: ScreenScaffold
var _area: Control
var _can_act: Callable
var _controls: Array[Control] = []


func configure(economy: ECONOMY, config: CONFIG) -> Error:
	if not is_instance_valid(economy) or not economy.is_ready() or not is_instance_valid(config):
		return ERR_UNCONFIGURED
	for key: String in REQUIRED_KEYS:
		if not config.has_key(StringName(key)):
			return ERR_UNCONFIGURED
	_economy = economy
	_config = config
	return OK


func mount(
	host: ScreenScaffold,
	area: Control,
	save: SAVE,
	bus: Node,
	slot: int,
	hint_control: HintButton,
	shuffle_control: IconButton,
	can_act: Callable
) -> void:
	_host = host
	_area = area
	_save = save
	_bus = bus
	_slot = slot
	_can_act = can_act
	bar = TopBar.new()
	home = IconButton.new()
	home.configure_icon(preload("res://assets/icons/house.svg"), "home.nav.journey")
	settings = IconButton.new()
	settings.configure_icon(preload("res://assets/icons/settings.svg"), "home.nav.settings")
	coins = CurrencyPill.new()
	coins.action_enabled = true
	number = CatalogSurface.label(&"Subtitle")
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	_controls = [home, settings, coins, number]
	meter = BonusMeter.new()
	meter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_area.add_child(meter)
	hint = hint_control
	shuffle = shuffle_control
	hint.reparent(area)
	shuffle.reparent(area)
	shuffle.configure_icon(preload("res://assets/icons/shuffle.svg"), "level.hud.shuffle")
	reveal = HintButton.new()
	area.add_child(reveal)
	reveal.configure(&"reveal", 0, _config.get_int(&"economy.price.reveal"))
	hint.configure(&"hint", 0, _config.get_int(&"economy.price.hint"))
	home.pressed.connect(_navigate.bind(&"home"))
	settings.pressed.connect(_navigate.bind(&"settings"))
	coins.action_requested.connect(_shop)
	reveal.activated.connect(_powerup)
	_host.top_bar = bar
	_connect_bus()
	refresh()


func _navigate(target: StringName) -> void:
	var control: Control = home if target == &"home" else settings
	if control.is_visible_in_tree():
		navigation_requested.emit(target)


func _shop(_kind: StringName) -> void:
	if coins.is_visible_in_tree() and bindings_ready():
		shop_requested.emit()


func _powerup(kind: StringName) -> void:
	if reveal.is_visible_in_tree() and _can_act.call():
		powerup_requested.emit(kind)


func _unlocked(feature: String) -> bool:
	if _slot == 1:
		return false
	var view: Dictionary = _save.committed_view()
	var language: String = view.sections.settings.language
	var state: Dictionary = view.sections.progress.by_lang.get(language, {})
	if feature in state.get("unlocked", []) or feature in view.sections.progress.unlocked:
		return true
	return (
		int(state.get("current_slot", 0))
		>= _config.get_int(StringName("unlocks." + feature + "_slot"))
	)


func bindings_ready() -> bool:
	return (
		is_instance_valid(_economy)
		and _economy.is_ready()
		and is_instance_valid(_save)
		and _economy.atomic_save_matches(_save)
	)


func refresh() -> void:
	if not is_instance_valid(bar) or not is_instance_valid(_save):
		return
	if not bindings_ready():
		bar.visible = false
		for control: Control in [meter, hint, reveal, shuffle]:
			control.visible = false
		return
	bar.visible = true
	var wallet: Dictionary = _economy.snapshot()
	number.text = tr("level.hud.level_n") % _slot
	var leading: Array[Control] = []
	var trailing: Array[Control] = []
	if _unlocked("journey"):
		leading.append(home)
	leading.append(number)
	if _unlocked("hint"):
		trailing.append(coins)
	if _slot != 1:
		trailing.append(settings)
	bar.configure(leading, "", trailing)
	if coins.value != wallet.coins or coins.text.is_empty():
		coins.set_value(wallet.coins)
	coins.custom_minimum_size.x = (
		Tokens.Touch.MIN_TARGET
		+ Tokens.Space.S
		+ (
			coins
			. get_theme_font("font")
			. get_string_size(
				str(wallet.coins),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				coins.get_theme_font_size("font_size")
			)
			. x
		)
	)
	meter.visible = _unlocked("bonus_meter")
	var target: int = _config.get_int(&"bonus.chest.words_required")
	meter.configure(wallet.bonus_counter, target)
	_meter_width = (
		(
			meter
			. get_theme_font(&"NUMERIC", &"Type")
			. get_string_size(
				str(wallet.bonus_counter) + " / " + str(target),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				meter.get_theme_font_size(&"NUMERIC", &"Type")
			)
			. x
		)
		+ Tokens.Space.M
		+ Tokens.Space.M
	)
	hint.visible = _unlocked("hint")
	reveal.visible = _unlocked("reveal")
	shuffle.visible = _unlocked("shuffle")
	var hint_price: int = _config.get_int(&"economy.price.hint")
	var reveal_price: int = _config.get_int(&"economy.price.reveal")
	if hint.count != wallet.items.hint or hint.price != hint_price:
		hint.set_amounts(wallet.items.hint, hint_price)
	if reveal.count != wallet.items.reveal or reveal.price != reveal_price:
		reveal.set_amounts(wallet.items.reveal, reveal_price)
	reveal.disabled = not _can_act.call()


func layout(available: Vector2, wheel_rect: Rect2, board_rect: Rect2) -> void:
	var left: float = (available.x - minf(available.x, Tokens.Layout.MAX_CONTENT_WIDTH)) / 2
	var right: float = available.x - left
	meter.position = Vector2(left, board_rect.end.y + Tokens.Space.S)
	meter.size = Vector2(
		maxf(_meter_width, meter.get_combined_minimum_size().x), meter.get_combined_minimum_size().y
	)
	for button: Control in [shuffle, hint, reveal]:
		button.size = button.get_combined_minimum_size()
	shuffle.position = Vector2(left, wheel_rect.end.y - shuffle.size.y)
	hint.position = Vector2(right - hint.size.x, wheel_rect.end.y - hint.size.y)
	reveal.position = Vector2(right - reveal.size.x, wheel_rect.position.y)


func _wallet_changed(
	_op: StringName, _reason: StringName, _amounts: Dictionary, _wallet: Dictionary
) -> void:
	refresh()


func _connect_bus() -> void:
	if is_instance_valid(_bus) and not _bus.economy_changed.is_connected(_wallet_changed):
		_bus.economy_changed.connect(_wallet_changed)


func _enter_tree() -> void:
	if is_instance_valid(bar):
		_connect_bus()
		refresh.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(_bus) and _bus.economy_changed.is_connected(_wallet_changed):
		_bus.economy_changed.disconnect(_wallet_changed)


func dispose() -> void:
	for control: Control in _controls:
		if is_instance_valid(control) and control.get_parent() == null:
			control.free()
	_controls.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh()
