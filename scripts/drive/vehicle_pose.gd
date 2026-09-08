class_name VehiclePose
extends RefCounted
static func flat_forward(basis: Basis) -> Vector3:
	var direction := -basis.z
	direction.y = 0
	return direction.normalized() if direction.length_squared() > 1e-6 else Vector3.FORWARD

static func compose(forward: Vector3, normal: Vector3) -> Basis:
	var up := normal.normalized()
	var tangent := forward.slide(up).normalized()
	if tangent.length_squared() < 0.01: return Basis.IDENTITY
	var right := tangent.cross(up).normalized()
	return Basis(right,up,-tangent).orthonormalized()

static func approach(current: Basis, target: Basis, delta: float) -> Basis:
	var a := current.get_rotation_quaternion()
	var b := target.get_rotation_quaternion()
	var angle := a.angle_to(b)
	if angle < 0.00001: return target
	var ratio := minf(1,deg_to_rad(GameConfig.DRIVE_POSE_DEG_PER_SECOND)*delta/angle)
	return Basis(a.slerp(b,ratio)).orthonormalized()
