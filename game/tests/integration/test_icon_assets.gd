extends GutTest

const ROOT: String = "res://assets/icons/"
const NAMES: PackedStringArray = [
	"house",
	"settings",
	"arrow-left",
	"shuffle",
	"lightbulb",
	"sparkles",
	"coins",
	"star",
	"lock",
	"play",
	"check",
	"hand",
	"route",
	"video",
	"x",
	"map-pinned",
	"gift"
]


func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(ROOT + "sources.json")) as Dictionary


func test_complete_pinned_set_and_geometry() -> void:
	var files: Dictionary = _manifest()["files"]
	assert_eq(files.size(), NAMES.size())
	var usages: Dictionary = {}
	for name: String in NAMES:
		assert_true(files.has(name), name)
		var entry: Dictionary = files[name]
		var path: String = ROOT + name + ".svg"
		assert_eq(FileAccess.get_sha256(path), entry["sha256"])
		var svg: String = FileAccess.get_file_as_string(path)
		assert_true(svg.contains('viewBox="0 0 24 24"'))
		assert_true(svg.contains('fill="none"'))
		assert_true(svg.contains('stroke-width="2"'))
		assert_true(svg.contains('stroke-linecap="round"'))
		assert_true(svg.contains('stroke-linejoin="round"'))
		var original: String = svg.replace('stroke="#ffffff"', 'stroke="currentColor"')
		assert_eq(original.sha256_text(), entry["upstream_sha256"])
		assert_false(usages.has(entry["usage"]))
		assert_false((entry["usage"] as String).is_empty())
		usages[entry["usage"]] = true
		var settings: ConfigFile = ConfigFile.new()
		assert_eq(settings.load(path + ".import"), OK)
		assert_eq(settings.get_value("params", "compress/mode"), 0)
		assert_eq(settings.get_value("params", "mipmaps/generate"), false)
		assert_eq(settings.get_value("params", "svg/scale"), 4.0)


func test_imported_textures_are_transparent_white_masks() -> void:
	for name: String in NAMES:
		var texture: Texture2D = load(ROOT + name + ".svg") as Texture2D
		assert_not_null(texture, name)
		assert_eq(texture.get_size(), Vector2(96, 96))
		var image: Image = texture.get_image()
		var visible: int = 0
		var transparent: int = 0
		var coloured: int = 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				var pixel: Color = image.get_pixel(x, y)
				if pixel.a == 0.0:
					transparent += 1
				else:
					visible += 1
					if pixel.r8 != 255 or pixel.g8 != 255 or pixel.b8 != 255:
						coloured += 1
		assert_gt(visible, 0, name)
		assert_gt(transparent, 0, name)
		assert_eq(coloured, 0, name)


func test_complete_licence_resource_and_provenance() -> void:
	var manifest: Dictionary = _manifest()
	var notice: String = FileAccess.get_file_as_string(ROOT + "LICENSE.txt")
	assert_eq(notice.sha256_text(), manifest["licence"]["sha256"])
	assert_true(notice.contains("ISC License"))
	assert_true(notice.contains("The MIT License (MIT)"))
	assert_true(notice.contains("Cole Bemis"))
	var resource: Resource = load(ROOT + "icon_license.tres")
	assert_eq(resource.get_meta(&"license_notice"), notice)
	assert_eq(resource.get_meta(&"set_name"), "Lucide")
	assert_eq(resource.get_meta(&"source_commit"), manifest["commit"])
	assert_eq(resource.get_meta(&"source_url"), manifest["licence"]["url"])
	assert_eq(resource.get_meta(&"spdx"), "ISC AND MIT")
