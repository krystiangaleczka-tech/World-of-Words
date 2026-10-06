extends ServiceStub
## @api Typed adapter container. SDK registration is separate from SDK initialization.
## Until production SDK tasks register factories, every build uses inert Fakes.

var ads: AdsAdapter = AdsFake.new()
var iap: IapAdapter = IapFake.new()
var analytics: AnalyticsAdapter = AnalyticsFake.new()
var crash: CrashAdapter = CrashFake.new()
var consent: ConsentAdapter = ConsentFake.new()
var haptics: HapticsAdapter = HapticsFake.new()
var review: ReviewAdapter = ReviewFake.new()
var notifications: NotificationsAdapter = NotificationsFake.new()

var _sdk: Dictionary[StringName, Dictionary] = {}
var _forced: Dictionary[StringName, bool] = {}


## @api Boot selects adapters without starting SDKs or making platform calls.
func initialize(clock: Clock) -> void:
	super.initialize(clock)
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	select_adapters(
		OS.get_name(),
		Engine.is_editor_hint(),
		DisplayServer.get_name() == "headless",
		args,
		Engine.get_singleton_list()
	)


## @api Register a factory for a known service; plugin is the Engine singleton name.
## A factory must return that service's adapter subclass. Registration has no side effects.
func register_sdk(service: StringName, plugin: StringName, factory: Callable) -> bool:
	if not _known(service) or plugin.is_empty() or not factory.is_valid():
		return false
	_sdk[service] = {"plugin": plugin, "factory": factory}
	return true


## @api Deterministic selection seam. Real boot supplies runtime facts to this method.
## Editor, headless, desktop and --fakes always win over installed/registered SDKs.
func select_adapters(
	os_name: String,
	editor: bool,
	headless: bool,
	args: PackedStringArray,
	plugins: PackedStringArray
) -> void:
	var device: bool = os_name in ["Android", "iOS"] and not editor and not headless
	device = device and not args.has("--fakes")
	ads = _select(&"ads", AdsFake.new(), device, plugins) as AdsAdapter
	iap = _select(&"iap", IapFake.new(), device, plugins) as IapAdapter
	analytics = _select(&"analytics", AnalyticsFake.new(), device, plugins) as AnalyticsAdapter
	crash = _select(&"crash", CrashFake.new(), device, plugins) as CrashAdapter
	consent = _select(&"consent", ConsentFake.new(), device, plugins) as ConsentAdapter
	haptics = _select(&"haptics", HapticsFake.new(), device, plugins) as HapticsAdapter
	review = _select(&"review", ReviewFake.new(), device, plugins) as ReviewAdapter
	notifications = (
		_select(&"notifications", NotificationsFake.new(), device, plugins) as NotificationsAdapter
	)


## @api Debug/tests can force one service to Fake; other adapters stay intact.
func force_fake(service: StringName) -> bool:
	if not _known(service):
		return false
	_forced[service] = true
	match service:
		&"ads":
			ads = AdsFake.new()
		&"iap":
			iap = IapFake.new()
		&"analytics":
			analytics = AnalyticsFake.new()
		&"crash":
			crash = CrashFake.new()
		&"consent":
			consent = ConsentFake.new()
		&"haptics":
			haptics = HapticsFake.new()
		&"review":
			review = ReviewFake.new()
		&"notifications":
			notifications = NotificationsFake.new()
	return true


func _known(service: StringName) -> bool:
	return (
		service
		in [
			&"ads",
			&"iap",
			&"analytics",
			&"crash",
			&"consent",
			&"haptics",
			&"review",
			&"notifications"
		]
	)


func _select(
	service: StringName, fake: RefCounted, device: bool, plugins: PackedStringArray
) -> RefCounted:
	if not device or _forced.has(service) or not _sdk.has(service):
		return fake
	var entry: Dictionary = _sdk[service]
	if not plugins.has(str(entry["plugin"])):
		return fake
	var factory: Callable = entry["factory"]
	var candidate: Variant = factory.call()
	if not candidate is RefCounted:
		return fake
	# Every adapter contract is a direct RefCounted subclass with its own signals.
	# Validate against the expected contract before assigning a typed public property.
	var expected: Script = fake.get_script().get_base_script()
	if not is_instance_of(candidate, expected):
		return fake
	return candidate as RefCounted
