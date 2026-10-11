extends GutTest

const METRICS: Script = preload("res://features/debug/performance_metrics.gd")


func test_unavailable_first_frame_and_reset() -> void:
	var metrics: RefCounted = METRICS.new()
	for iteration: int in 2:
		assert_eq(metrics.snapshot().frame_intervals, 0)
		assert_eq(metrics.snapshot().frame_mean_ms, -1.0)
		assert_eq(metrics.snapshot().frame_max_ms, -1.0)
		assert_eq(metrics.snapshot().fps, -1.0)
		assert_eq(metrics.snapshot().frame_over_budget, 0)
		assert_eq(metrics.snapshot().frame_budget_usec, 16667)
		metrics.frame_post_draw(1000000 + iteration * 1000000)
		assert_eq(metrics.snapshot().frame_intervals, 0)
		metrics.frame_post_draw(1100000 + iteration * 1000000)
		assert_eq(metrics.snapshot().frame_intervals, 1)
		assert_eq(metrics.snapshot().frame_max_ms, 100.0)
		metrics.reset()


func test_uneven_intervals_and_strict_budget() -> void:
	var metrics: RefCounted = METRICS.new()
	for timestamp: int in [0, 10000, 26667, 43335, 93335]:
		metrics.frame_post_draw(timestamp)
	var stats: Dictionary = metrics.snapshot()
	assert_eq(stats.frame_intervals, 4)
	assert_almost_eq(stats.frame_mean_ms, 23.33375, 0.000001)
	assert_eq(stats.frame_max_ms, 50.0)
	assert_eq(stats.frame_over_budget, 2, "equal to diagnostic budget does not count")
	assert_almost_eq(stats.fps, 1000000.0 * 4 / 93335, 0.000001)
	assert_eq(stats.mean_ms, -1.0, "frame observations don't invent input samples")


func test_nonpositive_intervals_do_not_move_anchor() -> void:
	var metrics: RefCounted = METRICS.new()
	for timestamp: int in [10000, 10000, 4000, 14000]:
		metrics.frame_post_draw(timestamp)
	assert_eq(metrics.snapshot().frame_intervals, 1)
	assert_eq(metrics.snapshot().frame_mean_ms, 4.0)
	assert_eq(metrics.snapshot().frame_max_ms, 4.0)
	assert_eq(metrics.snapshot().fps, 250.0)


func test_draw_coverage_and_pending_input_are_unchanged() -> void:
	var metrics: RefCounted = METRICS.new()
	metrics.record_input(1000)
	metrics.mark_drawn()
	metrics.record_input(3000)
	metrics.frame_post_draw(10000)
	assert_eq(metrics.snapshot().samples, 1)
	assert_eq(metrics.snapshot().pending, 1)
	assert_eq(metrics.snapshot().mean_ms, 9.0)
	metrics.frame_post_draw(20000)
	assert_eq(metrics.snapshot().samples, 1)
	metrics.mark_drawn()
	metrics.frame_post_draw(40000)
	assert_eq(metrics.snapshot().samples, 2)
	assert_eq(metrics.snapshot().pending, 0)
	assert_eq(metrics.snapshot().max_ms, 37.0)
	assert_eq(metrics.snapshot().frame_intervals, 2)
	assert_eq(metrics.snapshot().frame_max_ms, 20.0)
