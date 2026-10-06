extends Control

var _output: Label


func _ready() -> void:
	_output = Label.new()
	_output.position = Vector2(24, 80)
	_output.size = Vector2(672, 900)
	_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_output.add_theme_font_size_override("font_size", 28)
	add_child(_output)

	_record("S1 iOS diagnostic smoke test; matrix NOT PASSED")
	_record("Godot: " + Engine.get_version_info()["string"])
	_record("Bundle ID: com.mazen.worldofwordgame.spike")

	for singleton: String in [
		"PoingGodotAdMob",
		"PoingGodotAdMobConsentInformation",
		"PoingGodotAdMobRewardedAd",
		"PoingGodotAdMobInterstitialAd",
	]:
		_record("Native %s: %s" % [singleton, Engine.has_singleton(singleton)])

	_record("OpenIAP GodotIap class: %s" % ClassDB.class_exists("GodotIap"))
	_record("OpenIAP autoload: %s" % has_node("/root/GodotIapPlugin"))
	_record("Native Haptics singleton: %s" % Engine.has_singleton("Haptics"))
	_record("Ads/IAP calls disabled until real UMP, ATT and sandbox resources exist")


func _record(message: String) -> void:
	print("S1 iOS: " + message)
	_output.text += message + "\n"
