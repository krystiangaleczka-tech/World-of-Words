extends ScreenScaffold
## Real wheel under a passive hand; Gallery alone owns this temporary teaching preview.

var wheel: LetterWheelView
var hand: TutorialHand
var caption: Label
var _stage: Control
var _replay: TextButton
var _hide: TextButton
var _catalog: LocaleCatalog = LocaleCatalog.new()


func _ready() -> void:
	super._ready()
	_catalog.register_all()
	caption = CatalogSurface.label(&"Caption")
	body.add_child(caption)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.Space.S)
	body.add_child(row)
	_replay = TextButton.new()
	_replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replay.text_key = "gallery.tutorial.replay"
	row.add_child(_replay)
	_hide = TextButton.new()
	_hide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hide.text_key = "gallery.tutorial.hide"
	row.add_child(_hide)
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size.y = Tokens.Layout.WHEEL_MIN + Tokens.Space.XL * 2
	body.add_child(_stage)
	wheel = LetterWheelView.new()
	wheel.size = Vector2.ONE * Tokens.Layout.WHEEL_MIN
	_stage.add_child(wheel)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 326
	wheel.set_letters(PackedStringArray(["K", "O", "T"]), rng)
	hand = TutorialHand.new()
	hand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(hand)
	_connect()
	_layout()
	_copy()


func _connect() -> void:
	if not _stage.resized.is_connected(_layout):
		_stage.resized.connect(_layout)
		_replay.pressed.connect(_play)
		_hide.pressed.connect(hand.hide_for_touch)
		wheel.gui_input.connect(_touch)


func _layout() -> void:
	wheel.size = Vector2.ONE * Tokens.Layout.WHEEL_MIN
	wheel.position = (_stage.size - wheel.size) / 2
	var path: PackedVector2Array = PackedVector2Array()
	for index: int in range(3):
		path.append(wheel.position + wheel.tile_position(index))
	hand.configure(path)


func _play() -> void:
	hand.play()


func _touch(event: InputEvent) -> void:
	if (
		(event is InputEventScreenTouch and event.pressed)
		or (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		)
	):
		hand.hide_for_touch()


func _copy() -> void:
	if caption != null:
		caption.text = tr("gallery.tutorial.caption")


func _enter_tree() -> void:
	super._enter_tree()
	_catalog.register_all()
	if _stage != null:
		_connect()


func _exit_tree() -> void:
	super._exit_tree()
	if _stage != null and _stage.resized.is_connected(_layout):
		_stage.resized.disconnect(_layout)
		_replay.pressed.disconnect(_play)
		_hide.pressed.disconnect(hand.hide_for_touch)
		wheel.gui_input.disconnect(_touch)
	_catalog.unregister()


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_copy()
