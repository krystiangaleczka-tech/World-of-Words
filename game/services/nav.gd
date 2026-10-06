extends ServiceStub
## @api Navigation stub; screen routing and domain loading are implemented in T-0043.


## @api Explicitly inject one Clock into the closed autoload list. No domain work yet.
func boot(clock: Clock) -> void:
	var names: PackedStringArray = PackedStringArray(
		[
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
	)
	for service_name: String in names:
		var service: ServiceStub = get_node("/root/" + service_name) as ServiceStub
		assert(service != null, "Missing autoload: " + service_name)
		service.initialize(clock)
