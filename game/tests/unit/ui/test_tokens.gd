extends GutTest


func test_design_values_match() -> void:
	assert_eq(Tokens.Palette.BG, Color("#F6F2E9"))
	assert_eq(Tokens.Palette.PRIMARY, Color("#306453"))
	assert_eq(Tokens.Palette.TEXT, Color("#283E35"))
	assert_eq(Tokens.Palette.TEXT_MUTED, Color("#62695E"))
	assert_eq(Tokens.Palette.ERROR, Color("#A33F35"))
	assert_eq(
		[Tokens.Type.TITLE, Tokens.Type.BODY, Tokens.Type.LABEL, Tokens.Type.CAPTION],
		[60, 42, 40, 32]
	)
	assert_eq([Tokens.Space.S, Tokens.Space.M, Tokens.Touch.MIN_TARGET], [16, 32, 144])
	assert_eq(Tokens.Layout.TABLET_MAX_ASPECT, 1.65)
	assert_eq(Tokens.Layout.COMPACT_MAX_ASPECT, 1.95)


func test_tokens_are_pure() -> void:
	var tokens: Object = Tokens.new()
	assert_is(tokens, RefCounted)
	assert_false(tokens is Node)
