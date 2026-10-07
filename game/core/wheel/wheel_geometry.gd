class_name WheelGeometry
extends RefCounted
## @api Pure layout and nearest-circle hit testing in caller-defined coordinates.


static func positions(count: int, radius: float, center: Vector2) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if count < 3 or count > 8 or radius <= 0:
		return result
	result.resize(count)
	for index: int in count:
		var angle: float = -PI / 2.0 + TAU * float(index) / count
		result[index] = center + Vector2(cos(angle), sin(angle)) * radius
	return result


static func hit_test(point: Vector2, centers: PackedVector2Array, radius: float) -> int:
	if radius <= 0:
		return -1
	var best: float = radius * radius
	var hit: int = -1
	for index: int in centers.size():
		var distance: float = point.distance_squared_to(centers[index])
		if distance <= best and (hit < 0 or distance < best):
			best = distance
			hit = index
	return hit
