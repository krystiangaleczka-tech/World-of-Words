class_name CatalogSurface
extends RefCounted
## Internal catalog construction: callers supply tokens, children remain passive.


static func panel(
	owner: Control,
	padding: int = Tokens.Space.M,
	radius: int = Tokens.Radius.M,
	elevation: StringName = &"LOW"
) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = owner.get_theme_color(&"SURFACE", &"Palette")
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	box.shadow_size = owner.get_theme_constant(elevation, &"Elevation")
	box.shadow_offset.y = owner.get_theme_constant(
		StringName(str(elevation) + "_OFFSET_Y"), &"Elevation"
	)
	box.shadow_color = owner.get_theme_color(StringName(str(elevation) + "_COLOR"), &"Elevation")
	return box


static func label(variation: StringName = &"Body") -> Label:
	var item: Label = Label.new()
	item.theme_type_variation = variation
	item.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item


static func icon(texture: Texture2D, side: int = Tokens.Space.L) -> TextureRect:
	var item: TextureRect = TextureRect.new()
	item.texture = texture
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.custom_minimum_size = Vector2.ONE * side
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item


static func bounds(owner: Control) -> Rect2:
	return owner.get_transform().affine_inverse() * parent_bounds(owner)


static func parent_bounds(owner: Control) -> Rect2:
	var parent: Control = owner.get_parent_control()
	var inverse: Transform2D = Transform2D.IDENTITY
	if parent != null:
		inverse = parent.get_global_transform_with_canvas().affine_inverse()
	var ancestor: Node = owner.get_parent()
	while ancestor != null:
		if ancestor is ScreenScaffold and (ancestor as ScreenScaffold).body != null:
			var body: Control = (ancestor as ScreenScaffold).body
			return (
				inverse * (body.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, body.size))
			)
		ancestor = ancestor.get_parent()
	return Rect2(Vector2.ZERO, parent.size if parent != null else owner.get_viewport_rect().size)


static func bounds_owner(owner: Control) -> Control:
	var ancestor: Node = owner
	while ancestor != null:
		if ancestor is ScreenScaffold and (ancestor as ScreenScaffold).body != null:
			return (ancestor as ScreenScaffold).body
		ancestor = ancestor.get_parent()
	return owner.get_parent_control()
