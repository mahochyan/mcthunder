class_name VehicleFramePose
extends RefCounted
## Relative rigid poses. They belong to authority; render interpolation never
## writes back to the server's query, driving or weapon state.
const VERSION := 1
const NETWORK_VERSION := 6 # Per-tile reactive armor state; journal v1, command v3 and frame pose v1.
const PARTS := ["hull", "running_left", "running_right"]

static func node(tank: TankVehicle, part: String) -> Node3D:
	match part:
		"hull": return tank.hull_frame
		"running_left": return tank.track_left_frame
		"running_right": return tank.track_right_frame
	return null

static func pack(pose: Transform3D) -> Dictionary:
	if not LayoutMath.is_rigid(pose): return {}
	var p := pose.origin
	var q := pose.basis.get_rotation_quaternion()
	return {"position":[p.x,p.y,p.z],"rotation":[q.x,q.y,q.z,q.w]}

static func capture(tank: TankVehicle) -> Dictionary:
	var out := {"version":VERSION}
	for part in PARTS: out[part]=pack(node(tank,part).transform)
	return out

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not VehicleCommandCodec.integer(value.get("version")) or value.version!=VERSION: return false
	for part in PARTS:
		var pose: Variant=value.get(part)
		if not pose is Dictionary: return false
		if not pose.get("position") is Array or pose.position.size()!=3 or not pose.get("rotation") is Array or pose.rotation.size()!=4: return false
		for number in pose.position+pose.rotation:
			if not (number is int or number is float) or not is_finite(float(number)): return false
		if not Vector3(pose.position[0],pose.position[1],pose.position[2]).is_finite(): return false
		var q := Quaternion(pose.rotation[0],pose.rotation[1],pose.rotation[2],pose.rotation[3])
		if absf(q.length_squared()-1.0)>0.0001: return false
	return true

static func unpack(pose: Dictionary) -> Transform3D:
	var p: Array=pose.position
	var q: Array=pose.rotation
	return Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3]).normalized()),Vector3(p[0],p[1],p[2]))

static func blend(a: Dictionary, b: Dictionary, alpha: float) -> Dictionary:
	var out := {"version":VERSION}
	for part in PARTS:
		out[part]=pack(unpack(a[part]).interpolate_with(unpack(b[part]),clampf(alpha,0,1)))
	return out

static func apply(tank: TankVehicle, value: Variant) -> bool:
	# Validate every part first: malformed right track cannot partially move hull.
	if not valid(value): return false
	for part in PARTS: node(tank,part).transform=unpack(value[part])
	return true
