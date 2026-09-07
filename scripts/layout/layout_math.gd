class_name LayoutMath
extends RefCounted

# 004-a（GPT 参考实现）：刚体变换、关节姿态与模块方盒世界角点。
# 只做纯数学——不读取输入、不修改 Resource、不执行物理。
# 坐标约定：1 单位 = 1 米；+X 右、+Y 上、-Z 前；关节角输入度、内部弧度。

const EPS := 0.00001


static func is_rigid(t: Transform3D) -> bool:
	if not t.is_finite():
		return false

	var b := t.basis
	if absf(b.x.length_squared() - 1.0) > EPS:
		return false
	if absf(b.y.length_squared() - 1.0) > EPS:
		return false
	if absf(b.z.length_squared() - 1.0) > EPS:
		return false

	if absf(b.x.dot(b.y)) > EPS:
		return false
	if absf(b.x.dot(b.z)) > EPS:
		return false
	if absf(b.y.dot(b.z)) > EPS:
		return false

	return absf(b.determinant() - 1.0) <= EPS


static func posed_local(
		bind_local: Transform3D,
		joint_kind: String,
		requested_deg: float,
		min_deg: float,
		max_deg: float
	) -> Dictionary:

	if not is_rigid(bind_local):
		return {
			"ok": false,
			"error": "bind_local must be a finite rigid transform"
		}

	if not is_finite(requested_deg):
		return {"ok": false, "error": "requested angle is not finite"}

	if joint_kind == "fixed":
		return {
			"ok": true,
			"transform": bind_local,
			"applied_deg": 0.0
		}

	if joint_kind not in ["yaw", "pitch"]:
		return {"ok": false, "error": "unknown joint_kind"}

	if not is_finite(min_deg) or not is_finite(max_deg):
		return {"ok": false, "error": "joint limits are not finite"}

	if min_deg > max_deg:
		return {"ok": false, "error": "joint limits are reversed"}

	var applied := clampf(requested_deg, min_deg, max_deg)
	var axis := Vector3.UP if joint_kind == "yaw" else Vector3.RIGHT
	var rotation := Transform3D(
		Basis(axis, deg_to_rad(applied)),
		Vector3.ZERO
	)

	# Rotate about the part's own bind origin, not around the parent origin.
	return {
		"ok": true,
		"transform": bind_local * rotation,
		"applied_deg": applied
	}


static func compose_world(
		parent_world: Transform3D,
		local_pose: Transform3D
	) -> Dictionary:

	if not is_rigid(parent_world) or not is_rigid(local_pose):
		return {"ok": false, "error": "non-rigid transform in part chain"}

	return {
		"ok": true,
		"transform": parent_world * local_pose
	}


static func box_world_corners(
		part_world: Transform3D,
		box_local: Transform3D,
		size_m: Vector3
	) -> PackedVector3Array:

	var result := PackedVector3Array()

	if not is_rigid(part_world) or not is_rigid(box_local):
		return result

	if not size_m.is_finite():
		return result
	if size_m.x <= 0.0 or size_m.y <= 0.0 or size_m.z <= 0.0:
		return result

	var world := part_world * box_local
	var half := size_m * 0.5

	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var local_corner := Vector3(
					sx * half.x,
					sy * half.y,
					sz * half.z
				)
				result.append(world * local_corner)

	return result