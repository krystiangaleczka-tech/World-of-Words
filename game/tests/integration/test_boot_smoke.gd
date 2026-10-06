extends GutTest
## Boot smoke (T-0044): the real boot scene, real autoloads and headless Fakes reach Level.
## GUT fails this test on any engine error or push_error raised during boot.

const BOOT_SCENE: String = "res://services/nav/boot.tscn"
const FIXTURE: String = "res://tests/fixtures/content"


func test_headless_boot_reaches_level_with_fakes() -> void:
	watch_signals(Nav)
	var boot: Node = (load(BOOT_SCENE) as PackedScene).instantiate()
	boot.set("content_root", FIXTURE)
	add_child_autofree(boot)
	assert_signal_not_emitted(Nav, "boot_failed")
	assert_eq(Nav.current_screen(), Nav.Screen.LEVEL)
	assert_between(Nav.level_slot(), 1, Content.slot_count())
	assert_eq(Content.get_language(), str(Save.get_setting(&"language")))
	assert_true(Config.has_key(&"unlocks.journey_slot"))
	for adapter: Object in [
		Platform.ads,
		Platform.iap,
		Platform.analytics,
		Platform.crash,
		Platform.consent,
		Platform.haptics,
		Platform.review,
		Platform.notifications,
	]:
		assert_true(adapter.get_script().resource_path.ends_with("_fake.gd"), str(adapter))
	assert_eq((Platform.ads as AdsFake).calls.entries.size(), 0, "boot makes no ad calls")
