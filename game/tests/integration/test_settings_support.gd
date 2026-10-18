extends GutTest

const SERVICE: Script = preload("res://services/settings_support.gd")
const SAVE: Script = preload("res://services/save.gd")
const MEMORY: Script = preload("res://tests/integration/test_level_hud.gd")
const FIXTURE: Script = preload("res://tests/integration/test_iap_settlement.gd")
const ID: String = "12345678-1234-4234-8234-123456789abc"


class Composer:
	extends Node
	var calls: Array[Dictionary] = []
	var result: Variant = OK
	var hook: Callable

	func compose(subject: String, body: String) -> Variant:
		calls.append({"subject": subject, "body": body})
		if hook.is_valid():
			hook.call()
		return result


var service: SERVICE
var save: SAVE
var composer: Composer
var locale: String


func before_each() -> void:
	locale = TranslationServer.get_locale()
	TranslationServer.set_locale("pl")
	service = SERVICE.new()
	save = SAVE.new()
	composer = Composer.new()
	for node: Node in [save, composer, service]:
		add_child(node)
	save.initialize(FIXTURE.FixedClock.new())
	save.configure(MEMORY.MemoryStorage.new(), func() -> String: return ID)
	assert_eq(save.load(), OK)
	assert_eq(service.configure(save, composer.compose), OK)


func after_each() -> void:
	for node: Node in [service, composer, save]:
		if is_instance_valid(node):
			node.free()
	TranslationServer.set_locale(locale)


func test_readonly_draft_uses_full_committed_identity_and_only_closed_fields() -> void:
	var before: Dictionary = save.committed_view()
	assert_true(service.owner_matches(save))
	assert_false(service.owner_matches(composer))
	assert_false(service.owner_matches(null))
	var draft: Dictionary = service.draft()
	assert_eq(draft.keys(), ["subject", "body"])
	assert_eq(draft.subject, tr("settings.support.subject"))
	assert_eq(draft.body.count(ID), 1)
	assert_true(draft.body.contains(tr("settings.support.install_id") % ID))
	assert_true(draft.body.contains(tr("settings.support.language") % "pl"))
	assert_true(
		draft.body.contains(
			(
				tr("settings.support.version")
				% str(ProjectSettings.get_setting("application/config/version"))
			)
		)
	)
	assert_true(draft.body.contains("\n\n\n"))
	assert_false(draft.body.contains("processed_transactions"))
	assert_false(draft.body.contains("coins"))
	assert_eq(service.snapshot().short_id, ID.left(8))
	draft.body = "mutated"
	var snapshot: Dictionary = service.snapshot()
	snapshot.state = &"failed"
	assert_ne(service.draft().body, "mutated")
	assert_eq(service.snapshot().state, &"idle")
	assert_eq(composer.calls.size(), 0)
	assert_eq(save.committed_view(), before)


func test_live_locale_changes_text_without_changing_identity_or_content_language() -> void:
	var polish: Dictionary = service.draft()
	TranslationServer.set_locale("en")
	var english: Dictionary = service.draft()
	assert_ne(english.subject, polish.subject)
	assert_ne(english.body, polish.body)
	assert_eq(english.body.count(ID), 1)
	assert_true(english.body.contains(tr("settings.support.language") % "pl"))
	assert_eq(save.committed_view().sections.settings.language, "pl")
	assert_eq(composer.calls.size(), 0)


func test_invalid_bindings_preserve_the_actual_owner_and_composer() -> void:
	var before: Dictionary = service.snapshot()
	assert_eq(service.configure(null, composer.compose), ERR_UNCONFIGURED)
	assert_eq(service.configure(composer, composer.compose), ERR_UNCONFIGURED)
	assert_eq(service.configure(save, Callable()), ERR_UNCONFIGURED)
	assert_eq(service.configure(save, func() -> Error: return OK), ERR_INVALID_PARAMETER)
	var unloaded: SAVE = SAVE.new()
	assert_eq(service.configure(unloaded, composer.compose), ERR_UNCONFIGURED)
	unloaded.free()
	assert_eq(service.snapshot(), before)
	assert_true(service.owner_matches(save))
	assert_eq(composer.calls.size(), 0)


func test_handoff_failure_invalid_result_and_retry_never_claim_message_delivery() -> void:
	var before: Dictionary = save.committed_view()
	var states: Array[StringName] = []
	var observe: Callable = func() -> void: states.append(service.snapshot().state)
	service.changed.connect(observe)
	for result: Variant in [OK, ERR_UNAVAILABLE, "bad", true, -1, 1000000, OK]:
		composer.result = result
		var expected: Error = ERR_INVALID_DATA
		if result is int and result >= OK and result <= ERR_PRINTER_ON_FIRE:
			expected = result as Error
		var text: Dictionary = service.draft()
		var count: int = composer.calls.size()
		assert_eq(service.request_draft(), expected)
		assert_eq(composer.calls.size(), count + 1)
		assert_eq(composer.calls.back(), text)
		assert_eq(service.snapshot().state, &"handed_off" if expected == OK else &"failed")
		assert_eq(service.snapshot().error, expected)
		assert_eq(states[-2], &"requested")
	service.changed.disconnect(observe)
	assert_eq(save.committed_view(), before)


func _assert_blocked() -> void:
	var before: Dictionary = service.snapshot()
	assert_eq(service.request_draft(), ERR_BUSY)
	assert_eq(service.configure(save, composer.compose), ERR_BUSY)
	assert_eq(service.snapshot(), before)


func test_requested_terminal_and_port_callback_reentry_are_serialized() -> void:
	service.changed.connect(_assert_blocked)
	composer.hook = _assert_blocked
	assert_eq(service.request_draft(), OK)
	service.changed.disconnect(_assert_blocked)
	composer.hook = Callable()
	assert_eq(composer.calls.size(), 1)
	assert_eq(service.snapshot().state, &"handed_off")


func test_owner_loss_from_requested_notification_suppresses_port_dispatch() -> void:
	var lose: Callable = func() -> void:
		if service.snapshot().state == &"requested":
			remove_child(service)
	service.changed.connect(lose)
	assert_eq(service.request_draft(), ERR_UNCONFIGURED)
	service.changed.disconnect(lose)
	assert_eq(composer.calls.size(), 0)
	assert_eq(service.snapshot().state, &"unavailable")
	add_child(service)
	assert_false(service.owner_matches(save))
	assert_eq(service.request_draft(), ERR_UNCONFIGURED)
	assert_eq(service.configure(save, composer.compose), OK)
	assert_eq(service.request_draft(), OK)


func test_port_loss_from_requested_notification_suppresses_dispatch() -> void:
	var lose: Callable = func() -> void:
		if service.snapshot().state == &"requested":
			composer.free()
	service.changed.connect(lose)
	assert_eq(service.request_draft(), ERR_UNCONFIGURED)
	service.changed.disconnect(lose)
	assert_false(service.snapshot().available)
	assert_eq(service.draft(), {})


func test_lost_owner_during_port_callback_cannot_claim_handoff() -> void:
	composer.hook = func() -> void: remove_child(service)
	assert_eq(service.request_draft(), ERR_UNCONFIGURED)
	assert_eq(composer.calls.size(), 1)
	assert_eq(service.snapshot().state, &"unavailable")
	composer.hook = Callable()
	add_child(service)
	assert_eq(service.configure(save, composer.compose), OK)
	assert_eq(service.snapshot().state, &"idle")


func test_unconfigured_or_freed_save_is_unavailable_without_dispatch() -> void:
	var fresh: SERVICE = SERVICE.new()
	add_child(fresh)
	assert_eq(fresh.draft(), {})
	assert_false(fresh.snapshot().available)
	assert_eq(fresh.request_draft(), ERR_UNCONFIGURED)
	fresh.free()
	save.free()
	assert_false(service.owner_matches(null))
	assert_eq(service.draft(), {})
	assert_eq(service.snapshot().state, &"unavailable")
	assert_eq(service.request_draft(), ERR_UNCONFIGURED)
	assert_eq(composer.calls.size(), 0)
