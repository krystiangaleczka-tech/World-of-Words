extends GutTest


func test_positions_three_to_eight_and_nearest_hit() -> void:
	for count: int in range(3, 9):
		var center: Vector2 = Vector2(300, 400)
		var points: PackedVector2Array = WheelGeometry.positions(count, 200, center)
		assert_eq(points.size(), count)
		for index: int in count:
			assert_almost_eq(points[index].distance_to(center), 200.0, 0.01)
			assert_eq(WheelGeometry.hit_test(points[index], points, 50), index)
		assert_eq(WheelGeometry.hit_test(center, points, 50), -1)
	assert_true(WheelGeometry.positions(2, 100, Vector2.ZERO).is_empty())
	assert_true(WheelGeometry.positions(9, 100, Vector2.ZERO).is_empty())
	assert_eq(
		WheelGeometry.hit_test(
			Vector2(9, 0), PackedVector2Array([Vector2.ZERO, Vector2(10, 0)]), 20
		),
		1
	)
