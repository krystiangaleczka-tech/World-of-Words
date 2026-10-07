extends GutTest


func after_each() -> void:
	Tokens.reduced_motion = false


func test_duration_seconds_and_reduced_motion() -> void:
	Tokens.reduced_motion = false
	assert_eq(Tokens.dur(Tokens.Motion.BASE), 0.24)
	assert_eq(Tokens.dur(Tokens.Motion.FAST), 0.12)
	Tokens.reduced_motion = true
	assert_eq(Tokens.dur(Tokens.Motion.BASE), 0.0)
	assert_eq(Tokens.dur(Tokens.Motion.FAST), 0.12)
	assert_eq(Tokens.dur(Tokens.Motion.INSTANT), 0.0)
	assert_eq(Tokens.dur(-1), 0.0)


func test_palette_and_geometry_relationships() -> void:
	assert_eq(Tokens.Palette.TILE_SELECTED, Tokens.Palette.PRIMARY)
	assert_ne(Tokens.Palette.CELL_HINTED, Tokens.Palette.CELL_FILLED)
	assert_eq(Tokens.PaletteHC.BG, Color.WHITE)
	assert_lt(Tokens.Layout.WHEEL_RING_RATIO + Tokens.Layout.TILE_RADIUS_RATIO, 0.5)
	assert_gte(
		(
			Tokens.Layout.WHEEL_MIN
			* Tokens.Layout.TILE_RADIUS_RATIO
			* 2.0
			* Tokens.Touch.TILE_HIT_RATIO
		),
		Tokens.Touch.MIN_TARGET
	)
	assert_gt(Tokens.Touch.TILE_HIT_RATIO, 1.0)
