extends GutTest


func test_design_values_match() -> void:
	assert_eq(Tokens.Palette.BG, Color("#F6F1E7"))
	assert_eq(Tokens.Palette.PRIMARY, Color("#2F6F62"))
	assert_eq(Tokens.Palette.TEXT, Color("#1F2A30"))
	assert_eq(Tokens.Palette.TEXT_MUTED, Color("#5E6A70"))
	assert_eq(Tokens.Palette.ERROR, Color("#C0453A"))
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
