class_name Card
extends CatalogAction
## @api Caller-owned passive body; card and footer emit intent only.

signal action_requested
@export var title_key: String:
	get:
		return text_key
	set(next):
		text_key = next
@export var action_key: String = "":
	set(next):
		action_key = next
		_refresh_copy()
@export var locked_label_key: String = "ui.badge.locked":
	set(next):
		locked_label_key = next
		_refresh_copy()
@export var media: Texture2D:
	set(next):
		media = next
		_refresh_media()
@export var tappable: bool = false:
	set(next):
		tappable = next
		_refresh_available()
@export var locked: bool = false:
	set(next):
		locked = next
		_refresh_available()
		_refresh_media()
var _body: Control
var _body_slot: VBoxContainer
var _media: TextureRect
var _locked_label: Label
var _lock: Badge
var _action: PrimaryButton
var _material: ShaderMaterial


func _build_content() -> void:
	_media = CatalogSurface.icon(null, Tokens.Touch.MIN_TARGET)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://ui/components/card_media.gdshader")
	_media.material = _material
	column.add_child(_media)
	super._build_content()
	_title_label.theme_type_variation = &"Subtitle"
	_body_slot = VBoxContainer.new()
	_body_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_body_slot)
	_lock = Badge.new()
	_lock.kind = &"lock"
	_lock.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_lock)
	_locked_label = CatalogSurface.label(&"Caption")
	column.add_child(_locked_label)
	_action = PrimaryButton.new()
	column.add_child(_action)
	_action.pressed.connect(_on_action)
	_mount_body()
	_refresh_media()


func _enter_tree() -> void:
	super._enter_tree()
	if _body_slot != null:
		_mount_body()
		if not _action.pressed.is_connected(_on_action):
			_action.pressed.connect(_on_action)


## @api Reject interactive body trees and invalid ownership before detaching prior content.
func configure_body(content: Control) -> Error:
	if content == null or content == self or content.is_ancestor_of(self) or not _passive(content):
		return ERR_INVALID_PARAMETER
	if content.get_parent() != null and content != _body:
		return ERR_ALREADY_IN_USE
	_detach_body()
	_body = content
	_mount_body()
	return OK


func _passive(node: Node) -> bool:
	if node is BaseButton or node is Range or node is LineEdit or node is TextEdit:
		return false
	if (
		node is Control
		and (
			node.focus_mode != Control.FOCUS_NONE
			or node.mouse_filter != Control.MOUSE_FILTER_IGNORE
		)
	):
		return false
	for child: Node in node.get_children():
		if not _passive(child):
			return false
	return true


func _detach_body() -> void:
	if is_instance_valid(_body) and _body.get_parent() == _body_slot:
		_body_slot.remove_child(_body)


func _mount_body() -> void:
	if _body_slot != null and is_instance_valid(_body) and _body.get_parent() == null:
		_body_slot.add_child(_body)


func _refresh_copy() -> void:
	super._refresh_copy()
	if _action != null:
		_action.text_key = action_key
		_action.visible = not action_key.is_empty()
		_lock.text_key = "ui.badge.locked"
		_locked_label.text = tr(locked_label_key) if not locked_label_key.is_empty() else ""


func _refresh_media() -> void:
	if _media != null:
		_media.texture = media
		_media.visible = media != null
		_material.set_shader_parameter("desaturated", locked or disabled)


func _refresh_available() -> void:
	focus_mode = Control.FOCUS_ALL if tappable and not locked else Control.FOCUS_NONE
	button_mask = MOUSE_BUTTON_MASK_LEFT if tappable and not locked else 0
	set_process_shortcut_input(tappable and not locked and not disabled and not loading)
	if _action != null:
		_action.disabled = disabled or loading or locked
		_action.visible = not action_key.is_empty() and not locked
		_lock.visible = locked
		_locked_label.visible = locked and not locked_label_key.is_empty()
		_body_slot.visible = not locked
		_refresh_media()


func _input(event: InputEvent) -> void:
	super._input(event)
	if (not tappable or locked) and event is InputEventKey and has_focus():
		release_focus()


func _gui_input(_event: InputEvent) -> void:
	if not tappable or locked:
		accept_event()
		set_pressed_no_signal(false)


func _on_action() -> void:
	if not disabled and not loading and not locked:
		action_requested.emit()


func _exit_tree() -> void:
	_detach_body()
	if _action.pressed.is_connected(_on_action):
		_action.pressed.disconnect(_on_action)
	super._exit_tree()


func _refresh_theme() -> void:
	super._refresh_theme()
	if _media != null:
		_media.modulate = _palette(&"TEXT_MUTED" if disabled else &"TEXT")
