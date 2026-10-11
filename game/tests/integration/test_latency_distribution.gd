extends GutTest

const METRICS: Script = preload("res://features/debug/performance_metrics.gd")


func test_unavailable_and_valid_zero() -> void:
	var metrics: RefCounted = METRICS.new()
	assert_eq(metrics.snapshot().latency_window_samples, 0)
	assert_eq(metrics.snapshot().p50_ms, -1.0)
	assert_eq(metrics.snapshot().p95_ms, -1.0)
	metrics.record_input(1000)
	metrics.mark_drawn()
	metrics.frame_post_draw(1000)
	assert_eq(metrics.snapshot().latency_window_samples, 1)
	assert_eq(metrics.snapshot().p50_ms, 0.0)
	assert_eq(metrics.snapshot().p95_ms, 0.0)


func test_nearest_rank_unsorted_samples_and_snapshot_stability() -> void:
	var metrics: RefCounted = METRICS.new()
	for duration: int in [3000, 1000, 5000, 2000, 4000]:
		metrics.record_input(10000 - duration)
	metrics.mark_drawn()
	metrics.frame_post_draw(10000)
	var first: Dictionary = metrics.snapshot()
	assert_eq(first.p50_ms, 3.0)
	assert_eq(first.p95_ms, 5.0)
	assert_eq(first.latency_window_samples, 5)
	assert_eq(metrics.snapshot(), first)
	metrics.record_input(11000)
	assert_eq(metrics.snapshot().p50_ms, 3.0, "pending events don't enter distribution")
	assert_eq(first.pending, 0, "snapshot independent of later observations")
	metrics.mark_drawn()
	metrics.frame_post_draw(11000)
	assert_eq(metrics.snapshot().p50_ms, 2.0, "rank3 of six: 0,1,2,3,4,5")
	assert_eq(metrics.snapshot().p95_ms, 5.0)


func test_coalesced_draw_prefix_excludes_later_input() -> void:
	var metrics: RefCounted = METRICS.new()
	metrics.record_input(1000)
	metrics.record_input(2000)
	metrics.mark_drawn()
	metrics.record_input(3000)
	metrics.frame_post_draw(5000)
	assert_eq(metrics.snapshot().latency_window_samples, 2)
	assert_eq(metrics.snapshot().p50_ms, 3.0)
	assert_eq(metrics.snapshot().p95_ms, 4.0)
	assert_eq(metrics.snapshot().pending, 1)
	metrics.frame_post_draw(9000)
	assert_eq(metrics.snapshot().latency_window_samples, 2)
	metrics.mark_drawn()
	metrics.frame_post_draw(10000)
	assert_eq(metrics.snapshot().p50_ms, 4.0)
	assert_eq(metrics.snapshot().p95_ms, 7.0)


func test_recent_ring_wrap_preserves_cumulative_metrics_and_reset() -> void:
	var metrics: RefCounted = METRICS.new()
	metrics.record_input(1000)
	metrics.mark_drawn()
	metrics.frame_post_draw(1000000)
	for index: int in METRICS.CAPACITY:
		metrics.record_input(1001000 + index * 1000)
		metrics.mark_drawn()
		metrics.frame_post_draw(1002000 + index * 1000)
	var stats: Dictionary = metrics.snapshot()
	assert_eq(stats.samples, 513)
	assert_eq(stats.latency_window_samples, 512)
	assert_eq(stats.p50_ms, 1.0)
	assert_eq(stats.p95_ms, 1.0)
	assert_eq(stats.max_ms, 999.0, "whole-window maximum retains old slow sample")
	assert_almost_eq(stats.mean_ms, 1511.0 / 513, 0.000001)
	metrics.reset()
	assert_eq(metrics.snapshot().latency_window_samples, 0)
	assert_eq(metrics.snapshot().p95_ms, -1.0)
	metrics.record_input(0)
	metrics.mark_drawn()
	metrics.frame_post_draw(8000)
	assert_eq(metrics.snapshot().p50_ms, 8.0, "old ring data excluded after reset")


func test_full_pending_queue_and_percentile_rank_at_capacity() -> void:
	var metrics: RefCounted = METRICS.new()
	for duration: int in range(512, 0, -1):
		metrics.record_input(1000000 - duration * 1000)
	metrics.record_input(0)
	assert_eq(metrics.snapshot().dropped, 1)
	assert_eq(metrics.snapshot().p95_ms, -1.0)
	metrics.mark_drawn()
	metrics.frame_post_draw(1000000)
	assert_eq(metrics.snapshot().samples, 512)
	assert_eq(metrics.snapshot().p50_ms, 256.0)
	assert_eq(metrics.snapshot().p95_ms, 487.0)
	assert_eq(metrics.snapshot().pending, 0)
