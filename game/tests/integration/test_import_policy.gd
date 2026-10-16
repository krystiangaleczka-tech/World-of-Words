extends GutTest

const IMPORT_THREADS: StringName = &"editor/import/use_multiple_threads"


func test_project_uses_serial_editor_resource_imports() -> void:
	var policy: Variant = ProjectSettings.get_setting(IMPORT_THREADS, true)
	assert_true(ProjectSettings.has_setting(IMPORT_THREADS))
	assert_eq(typeof(policy), TYPE_BOOL)
	assert_false(policy)
