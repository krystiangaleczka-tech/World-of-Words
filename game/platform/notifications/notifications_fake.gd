class_name NotificationsFake
extends NotificationsAdapter
## @api No SDK calls. Operations record calls; outcomes require explicit test delivery.

var calls: FakeCalls = FakeCalls.new()
