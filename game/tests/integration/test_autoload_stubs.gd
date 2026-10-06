extends GutTest

const AUTOLOAD_NAMES: Array[String] = [
	"Config",
	"Save",
	"Progress",
	"Economy",
	"Daily",
	"Content",
	"Monetization",
	"Analytics",
	"Audio",
	"Nav",
	"Events",
	"Platform",
]


class FixedClock:
	extends Clock

	func unix_time_seconds() -> int:
		return 123456

	func monotonic_msec() -> int:
		return 987


func test_closed_autoload_registration_and_order() -> void:
	var registered: PackedStringArray = PackedStringArray()
	for property: Dictionary in ProjectSettings.get_property_list():
		var key: String = str(property["name"])
		if key.begins_with("autoload/"):
			registered.append(key.trim_prefix("autoload/"))
	assert_eq(Array(registered), AUTOLOAD_NAMES)
	for service_name: String in AUTOLOAD_NAMES:
		assert_is(get_node("/root/" + service_name), ServiceStub)
	assert_false(ProjectSettings.has_setting("autoload/Clock"))


func test_boot_scene_initializes_every_service_with_one_clock() -> void:
	var scene: PackedScene = load("res://services/nav/boot.tscn") as PackedScene
	var boot_scene: Node = scene.instantiate()
	add_child_autofree(boot_scene)
	var shared_clock: Clock = Nav.get_clock()
	assert_not_null(shared_clock)
	for service_name: String in AUTOLOAD_NAMES:
		var service: ServiceStub = get_node("/root/" + service_name) as ServiceStub
		assert_same(service.get_clock(), shared_clock)
	assert_eq(
		ProjectSettings.get_setting("application/run/main_scene"), "res://services/nav/boot.tscn"
	)


func test_fixed_clock_can_replace_previous_boot_source() -> void:
	var fixed: FixedClock = FixedClock.new()
	Nav.boot(fixed)
	for service_name: String in AUTOLOAD_NAMES:
		var service: ServiceStub = get_node("/root/" + service_name) as ServiceStub
		assert_same(service.get_clock(), fixed)
		assert_eq(service.get_clock().unix_time_seconds(), 123456)
		assert_eq(service.get_clock().monotonic_msec(), 987)


func test_service_is_inert_until_explicit_initialization() -> void:
	var stub: ServiceStub = ServiceStub.new()
	add_child_autofree(stub)
	assert_null(stub.get_clock())
