extends SceneTree
## Native-only capture of the public GalleryShell preview matrix.

const GALLERY: GDScript = preload("res://ui/gallery/gallery.gd")
const LANGUAGES: Array[StringName] = [&"PL", &"PSEUDO"]
const STATES: Dictionary[String, int] = {"default100": 100, "hc130": 130}
const SETTLE_FRAMES: int = 4

var _output: String
var _gallery: GalleryShell
var _images: Array[Dictionary] = []


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--output":
		_fail("Expected --output DIRECTORY")
		return
	_output = args[1]
	if DisplayServer.get_name().to_lower() != "x11":
		_fail("Native X11 rendering is required")
		return
	_gallery = GALLERY.new() as GalleryShell
	root.add_child(_gallery)
	for page: StringName in GALLERY.PAGES:
		for layout: StringName in GALLERY.SIZES:
			for language: StringName in LANGUAGES:
				for state: String in STATES:
					var error: Error = _gallery.configure(
						layout, language, state == "hc130", STATES[state], true, false, page
					)
					if error != OK:
						_fail("Gallery configuration failed: %d" % error)
						return
					for frame: int in SETTLE_FRAMES:
						await process_frame
					RenderingServer.force_draw(false)
					if not _save_preview(page, layout, language, state):
						return
	var manifest: Dictionary = {
		"schema": 1,
		"engine": Engine.get_version_info()["string"],
		"display": DisplayServer.get_name().to_lower(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"pages": GALLERY.PAGES.keys(),
		"images": _images
	}
	var file: FileAccess = FileAccess.open(_output.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write manifest")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	print("Gallery screenshots: %d" % _images.size())
	root.remove_child(_gallery)
	_gallery.free()
	quit(0)


func _save_preview(
	page: StringName, layout: StringName, language: StringName, state: String
) -> bool:
	var viewport: SubViewport = _gallery.preview_viewport()
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != GALLERY.SIZES[layout]:
		_fail("Missing or incorrect preview dimensions")
		return false
	var sample: Image = image.duplicate() as Image
	sample.resize(64, 64, Image.INTERPOLATE_NEAREST)
	var first: Color = sample.get_pixel(0, 0)
	var varied: bool = false
	for y: int in sample.get_height():
		for x: int in sample.get_width():
			if sample.get_pixel(x, y) != first:
				varied = true
	if not varied:
		_fail("Uniform preview: %s" % page)
		return false
	var filename: String = "%s_%s_%s_%s.png" % [str(page).to_lower(), layout, language, state]
	var error: Error = image.save_png(_output.path_join(filename))
	if error != OK:
		_fail("Cannot write preview: %d" % error)
		return false
	_images.append(
		{
			"page": page,
			"layout": layout,
			"locale": language,
			"state": state,
			"width": image.get_width(),
			"height": image.get_height(),
			"file": filename
		}
	)
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
