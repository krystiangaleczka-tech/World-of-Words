extends ScreenScaffold

var _bursts: Array[RewardBurst] = []
var _stage: Control
var _animated: LocationPostcard


func _ready() -> void:
	super._ready()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", Tokens.Space.M)
	scroll.add_child(column)
	var row: GridContainer = GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", Tokens.Space.S)
	row.add_theme_constant_override("v_separation", Tokens.Space.S)
	column.add_child(row)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.custom_minimum_size.y = Tokens.Touch.MIN_TARGET * 2
	column.add_child(_stage)
	_stage.resized.connect(_replay)
	for kind: StringName in RewardBurst.GLYPHS:
		var button: TextButton = TextButton.new()
		button.text_key = RewardBurst.KEYS[kind]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		var burst: RewardBurst = RewardBurst.new()
		_stage.add_child(burst)
		_bursts.append(burst)
		button.pressed.connect(_play.bind(burst, kind))
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Tokens.Palette.PRIMARY, Tokens.Palette.BONUS])
	var image: GradientTexture2D = GradientTexture2D.new()
	var width: int = Tokens.Touch.MIN_TARGET * 3
	var height: int = Tokens.Touch.MIN_TARGET * 2
	image.width = width
	image.height = height
	image.gradient = gradient
	for preset: StringName in [&"thumb", &"full"]:
		for count: int in [0, 2, 4]:
			var card: LocationPostcard = LocationPostcard.new()
			card.name = "postcard_%s_%d" % [preset, count]
			card.configure(image, 4, count, preset)
			column.add_child(card)
	_animated = LocationPostcard.new()
	_animated.name = "postcard_animated"
	_animated.configure(image, 5, 0)
	column.add_child(_animated)
	var replay: TextButton = TextButton.new()
	replay.text_key = "gallery.rewards.replay"
	column.add_child(replay)
	replay.pressed.connect(_replay)
	var reveal: TextButton = TextButton.new()
	reveal.text_key = "gallery.rewards.reveal"
	column.add_child(reveal)
	reveal.pressed.connect(_animated.reveal_next)
	_replay()


func _play(burst: RewardBurst, kind: StringName) -> void:
	burst.play(kind, 25 if kind == &"coins" else (0 if kind == &"chest" else 1), _stage_center())


func _replay() -> void:
	if _animated == null:
		return
	for index: int in _bursts.size():
		var kind: StringName = RewardBurst.GLYPHS.keys()[index]
		var origin: Vector2 = Vector2(
			_stage.size.x * (index + 0.5) / _bursts.size(), _stage.size.y / 2
		)
		_bursts[index].play(
			kind, 25 if kind == &"coins" else (0 if kind == &"chest" else 1), origin
		)
	_animated.configure(_animated.texture, 5, 0)
	_animated.reveal_next()


func _stage_center() -> Vector2:
	return _stage.size / 2


func _exit_tree() -> void:
	if _stage != null and _stage.resized.is_connected(_replay):
		_stage.resized.disconnect(_replay)
