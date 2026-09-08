class_name PenetrationCurve
extends RefCounted
## TEST ONLY 游戏穿深距离曲线，单位 (m, mm)，不冒充材料学。

static func validate(points: PackedVector2Array) -> bool:
	if points.is_empty():
		return false
	var last_x := -1.0
	var last_y := INF
	for p in points:
		if not p.is_finite() or p.x < 0.0 or p.y < 0.0 or p.x <= last_x or p.y > last_y:
			return false
		last_x = p.x
		last_y = p.y
	return true

static func sample_mm(points: PackedVector2Array, distance_m: float) -> float:
	if not validate(points) or not is_finite(distance_m) or distance_m < 0.0:
		return -1.0
	if distance_m <= points[0].x:
		return points[0].y
	for i in range(1, points.size()):
		if distance_m <= points[i].x:
			var a := points[i - 1]
			var b := points[i]
			return lerpf(a.y, b.y, (distance_m - a.x) / (b.x - a.x))
	return points[points.size() - 1].y
