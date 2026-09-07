class_name QueryGeometry
extends RefCounted
## 005：纯几何查询内核。输入位于同一个刚体局部坐标系，单位为米；不访问场景树。
## 只实现两个基础函数：线段—三角形、线段—局部方盒。上层（ShotQueryService）
## 负责变换、身份、去重与排序。

const EPS_M := 0.00001
const EPS_AREA := 0.0000000001
const EPS_PARALLEL := 0.00000001


static func _miss(relation: String = "miss") -> Dictionary:
	return {"ok": true, "hit": false, "relation": relation}


static func _invalid(reason: String) -> Dictionary:
	return {"ok": false, "hit": false, "error": reason}


static func segment_triangle(
		p0: Vector3, p1: Vector3,
		a: Vector3, b: Vector3, c: Vector3
	) -> Dictionary:

	var points: Array[Vector3] = [p0, p1, a, b, c]
	for point in points:
		if not point.is_finite():
			return _invalid("non_finite_point")

	var d := p1 - p0
	var length := d.length()
	if not is_finite(length) or length <= EPS_M:
		return _invalid("zero_or_invalid_segment")

	var cross := (b - a).cross(c - a)
	var area2 := cross.length()
	if not is_finite(area2) or area2 <= EPS_AREA:
		return _invalid("degenerate_triangle")

	var n := cross / area2
	var den := n.dot(d)
	var height := n.dot(p0 - a)

	if absf(den) <= EPS_PARALLEL * length:
		if absf(height) <= EPS_M and absf(n.dot(p1 - a)) <= EPS_M:
			return _miss("coplanar_unresolved")
		return _miss("parallel")

	var t := -height / den
	var eps_t := EPS_M / length
	if t < -eps_t or t > 1.0 + eps_t:
		return _miss()

	t = clampf(t, 0.0, 1.0)
	var p := p0 + d * t
	var vertices: Array[Vector3] = [a, b, c]
	var on_edge := false

	for i in range(3):
		var edge := vertices[(i + 1) % 3] - vertices[i]
		var edge_length := edge.length()
		if edge_length <= EPS_M:
			return _invalid("degenerate_edge")

		var side := n.dot(edge.cross(p - vertices[i])) / edge_length
		if side < -EPS_M:
			return _miss()

		on_edge = on_edge or absf(side) <= EPS_M

	return {
		"ok": true, "hit": true, "relation": "point",
		"t": t, "point_local": p, "normal_local": n,
		"front_face": den < 0.0, "on_edge": on_edge,
		"at_start": t <= eps_t, "at_end": t >= 1.0 - eps_t
	}


static func segment_box_local(
		p0: Vector3, p1: Vector3, size_m: Vector3
	) -> Dictionary:

	if not p0.is_finite() or not p1.is_finite() or not size_m.is_finite():
		return _invalid("non_finite_box_input")

	if size_m.x <= EPS_M or size_m.y <= EPS_M or size_m.z <= EPS_M:
		return _invalid("invalid_box_size")

	var d := p1 - p0
	var length := d.length()
	if not is_finite(length) or length <= EPS_M:
		return _invalid("zero_or_invalid_segment")

	var h := size_m * 0.5
	var near_t := -INF
	var far_t := INF
	var near_n := Vector3.ZERO
	var far_n := Vector3.ZERO
	var starts_inside := true
	var follows_face := false

	for axis in range(3):
		starts_inside = starts_inside and absf(p0[axis]) < h[axis] - EPS_M

		if absf(d[axis]) <= 0.000000000001:
			if p0[axis] < -h[axis] - EPS_M or p0[axis] > h[axis] + EPS_M:
				return _miss()
			follows_face = follows_face or absf(absf(p0[axis]) - h[axis]) <= EPS_M
			continue

		var ta := (-h[axis] - p0[axis]) / d[axis]
		var tb := ( h[axis] - p0[axis]) / d[axis]

		var na := Vector3.ZERO
		var nb := Vector3.ZERO
		na[axis] = -1.0
		nb[axis] = 1.0

		if ta > tb:
			var temp_t := ta
			ta = tb
			tb = temp_t
			var temp_n := na
			na = nb
			nb = temp_n

		if ta > near_t:
			near_t = ta
			near_n = na
		if tb < far_t:
			far_t = tb
			far_n = nb

		if near_t > far_t:
			return _miss()

	var enter_t := maxf(near_t, 0.0)
	var exit_t := minf(far_t, 1.0)
	if enter_t > exit_t:
		return _miss()

	var has_entry := near_t >= 0.0 and near_t <= 1.0
	var has_exit := far_t >= 0.0 and far_t <= 1.0

	return {
		"ok": true, "hit": true, "relation": "interval",
		"t_enter": enter_t, "t_exit": exit_t,
		"has_entry_boundary": has_entry,
		"has_exit_boundary": has_exit,
		"normal_enter_local": near_n if has_entry else Vector3.ZERO,
		"normal_exit_local": far_n if has_exit else Vector3.ZERO,
		"starts_inside": starts_inside,
		"grazing": follows_face or (exit_t - enter_t) * length <= EPS_M
	}