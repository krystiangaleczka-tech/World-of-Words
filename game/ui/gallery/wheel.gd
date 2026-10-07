extends ScreenScaffold
## Provisional catalog gallery: minimum and maximum supported tile counts.

var _bindings: Dictionary[LetterWheelView, Callable] = {}
var _shuffle_button: IconButton
var _shuffle_action: Callable


func _ready() -> void:
	super._ready()
	var shuffle_wheel: LetterWheelView
	for letters: PackedStringArray in [
		PackedStringArray(["K", "O", "T"]),
		PackedStringArray(["K", "O", "L", "O", "R", "O", "W", "O"])
	]:
		var preview: WordPreview = WordPreview.new()
		body.add_child(preview)
		var wheel: LetterWheelView = LetterWheelView.new()
		shuffle_wheel = wheel
		wheel.custom_minimum_size = Vector2.ONE * Tokens.Layout.WHEEL_MIN
		body.add_child(wheel)
		wheel.set_letters(letters)
		var on_chain: Callable = _on_chain.bind(letters, preview)
		_bindings[wheel] = on_chain
		wheel.chain_changed.connect(on_chain)
	for kinds: Array in [
		[AttemptResult.Kind.LEVEL, AttemptResult.Kind.BONUS],
		[AttemptResult.Kind.ALREADY_FOUND, AttemptResult.Kind.INVALID]
	]:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.Space.M)
		body.add_child(row)
		for kind: AttemptResult.Kind in kinds:
			var sample: WordPreview = WordPreview.new()
			sample.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# Configure before mounting so catalog samples remain readable without a fade.
			sample.show_result(AttemptResult.new(kind, "KOT"))
			row.add_child(sample)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 108
	_shuffle_button = IconButton.new()
	_shuffle_button.text_key = "level.hud.shuffle"
	body.add_child(_shuffle_button)
	_shuffle_action = _on_shuffle.bind(shuffle_wheel, rng)
	_shuffle_button.pressed.connect(_shuffle_action)


func _on_shuffle(wheel: LetterWheelView, rng: RandomNumberGenerator) -> void:
	wheel.shuffle(rng)


func _on_chain(indices: PackedInt32Array, letters: PackedStringArray, preview: WordPreview) -> void:
	var word: String = ""
	for index: int in indices:
		word += letters[index]
	preview.set_building(word)


func _exit_tree() -> void:
	if is_instance_valid(_shuffle_button) and _shuffle_button.pressed.is_connected(_shuffle_action):
		_shuffle_button.pressed.disconnect(_shuffle_action)
	for wheel: LetterWheelView in _bindings:
		if is_instance_valid(wheel) and wheel.chain_changed.is_connected(_bindings[wheel]):
			wheel.chain_changed.disconnect(_bindings[wheel])
	_bindings.clear()
