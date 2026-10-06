class_name HapticsFake
extends HapticsAdapter
## @api No SDK calls. Operations record calls; outcomes require explicit test delivery.

var calls: FakeCalls = FakeCalls.new()


## @api Record play; tests emit inherited signals to deliver success/failure/pending.
func play(pattern: String) -> void:
	calls.record("play", [pattern])
