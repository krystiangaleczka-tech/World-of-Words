class_name RewardBurst
extends Control
## @api Passive presentation only. Origin is local to a non-container overlay parent.

signal finished(kind: StringName, amount: int)
const GLYPHS: Dictionary[StringName, Texture2D] = {
	&"coins": preload("res://assets/icons/coins.svg"),
	&"stars": preload("res://assets/icons/star.svg"),
	&"chest": preload("res://assets/icons/gift.svg"),
	&"postcard_piece": preload("res://assets/icons/map-pinned.svg")
}
const KEYS: Dictionary[StringName, String] = {
	&"coins": "ui.reward.coins",
	&"stars": "ui.reward.stars",
	&"chest": "ui.reward.chest",
	&"postcard_piece": "ui.reward.piece"
}
var state: StringName:
	get:
		return &"playing" if _active else (&"static" if visible else &"idle")
var _kind: StringName = &"coins"
var _amount: int = 0
var _active: bool = false
var _icon: TextureRect
var _label: Label
var _particles: CPUParticles2D
var _motion: Tween
var _catalog: LocaleCatalog = LocaleCatalog.new()


func _enter_tree() -> void:
	_catalog.register_all()
	if _icon != null:
		_refresh_copy()
		_refresh_theme()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = CatalogSurface.icon(GLYPHS[_kind], Tokens.Space.XL)
	add_child(_icon)
	_label = CatalogSurface.label(&"Numeric")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.explosiveness = 1
	_particles.amount = Tokens.Reward.PARTICLE_COUNT
	_particles.lifetime = maxf(Tokens.dur(Tokens.Motion.SLOW), Tokens.dur(Tokens.Motion.FAST))
	_particles.direction = Vector2.UP
	_particles.spread = Tokens.Reward.SPREAD_DEGREES
	_particles.initial_velocity_min = Tokens.Reward.SPEED_MIN
	_particles.initial_velocity_max = Tokens.Reward.SPEED_MAX
	_particles.gravity = Vector2.ZERO
	var dot: GradientTexture2D = GradientTexture2D.new()
	dot.width = Tokens.Space.XS
	dot.height = Tokens.Space.XS
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Tokens.Palette.ON_PRIMARY, Tokens.Palette.ON_PRIMARY])
	dot.gradient = gradient
	_particles.texture = dot
	add_child(_particles)
	_refresh_copy()
	_refresh_theme()
	visible = false
	set_process(false)


## @api Invalid requests preserve the running presentation; completion never grants currency.
func play(variant: StringName, amount: int, origin: Vector2) -> Error:
	if not GLYPHS.has(variant) or amount < 0 or not origin.is_finite():
		return ERR_INVALID_PARAMETER
	if not is_inside_tree() or not is_node_ready():
		return ERR_UNCONFIGURED
	if get_parent() is Container:
		return ERR_INVALID_PARAMETER
	cancel()
	_kind = variant
	_amount = amount
	position = origin
	_active = true
	visible = true
	_icon.texture = GLYPHS[variant]
	_refresh_copy()
	_refresh_theme()
	if Tokens.reduced_motion:
		_complete(true)
		return OK
	_particles.lifetime = Tokens.dur(Tokens.Motion.SLOW)
	_particles.visible = true
	_particles.restart()
	_particles.emitting = true
	_icon.scale = Vector2.ZERO
	_motion = create_tween().set_parallel(true)
	(
		_motion
		. tween_property(_icon, "scale", Vector2.ONE, Tokens.dur(Tokens.Motion.FAST))
		. set_trans(Tokens.Ease.SPRING.x)
		. set_ease(Tokens.Ease.SPRING.y)
	)
	_motion.tween_interval(Tokens.dur(Tokens.Motion.SLOW))
	_motion.chain().tween_callback(_complete.bind(false))
	set_process(true)
	return OK


func cancel() -> void:
	_stop_work()
	_active = false
	visible = false


func _stop_work() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	if _particles != null:
		_particles.emitting = false
		_particles.visible = false
	if _icon != null:
		_icon.scale = Vector2.ONE
	set_process(false)


func _complete(keep_visible: bool) -> void:
	if not _active:
		return
	var variant: StringName = _kind
	var amount: int = _amount
	_stop_work()
	_active = false
	visible = keep_visible
	finished.emit(variant, amount)


func _refresh_copy() -> void:
	accessibility_name = KEYS[_kind]
	accessibility_description = str(_amount)
	if _label != null:
		_label.text = "+" + str(_amount)
		_label.visible = _amount > 0
		_icon.position = Vector2(-Tokens.Space.XL / 2.0, -Tokens.Space.XL / 2.0)
		_icon.size = Vector2.ONE * Tokens.Space.XL
		_icon.pivot_offset = _icon.size / 2
		_label.size = Vector2(
			maxf(Tokens.Touch.MIN_TARGET, _label.get_combined_minimum_size().x),
			_label.get_combined_minimum_size().y
		)
		_label.position = Vector2(-_label.size.x / 2, Tokens.Space.XL / 2.0 + Tokens.Space.XS)


func _refresh_theme() -> void:
	if _icon == null:
		return
	var ink: Color = get_theme_color(&"COIN" if _kind == &"coins" else &"BONUS", &"Palette")
	_icon.modulate = ink
	if _particles != null:
		_particles.color = ink


func _process(_delta: float) -> void:
	if Tokens.reduced_motion and _active:
		_complete(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_copy()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh_theme()


func _exit_tree() -> void:
	cancel()
	_catalog.unregister()
