class_name GroundProbe
extends RefCounted
## Only actual WORLD geometry supplies ground normals; no height-map fiction.
static func sample(body: TankVehicle, direction: Vector3, half_size: Vector2) -> Dictionary:
	var out := {"grounded":false,"normal":Vector3.UP,"slope_deg":0.0,"points":[],"normals":[],"center_height":body.global_position.y,"support_count":0}
	var space := body.get_world_3d().direct_space_state
	var side := direction.cross(Vector3.UP).normalized()
	var sum := Vector3.ZERO
	var height := 0.0
	for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1),Vector2.ZERO]:
		var base: Vector3 = body.global_position+side*pair.x*half_size.x+direction*pair.y*half_size.y
		var query := PhysicsRayQueryParameters3D.create(base+Vector3.UP*GameConfig.DRIVE_PROBE_UP_M,base-Vector3.UP*GameConfig.DRIVE_PROBE_DOWN_M,GameConfig.LAYER_WORLD,[body.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).dot(Vector3.UP) <= 0.1: continue
		out.points.append(hit.position)
		out.normals.append(hit.normal)
		sum += hit.normal
		height += hit.position.y
		out.support_count += 1
	if out.support_count > 0 and sum.length_squared() > 0.01:
		out.normal = sum.normalized()
		out.center_height = height/out.support_count
		out.slope_deg = rad_to_deg(acos(clampf(out.normal.dot(Vector3.UP),-1,1)))
		out.grounded = body.is_on_floor() or absf(body.global_position.y-float(out.center_height)) < 0.55
	return out

static func blocks_uphill(sampled: Dictionary, movement: Vector3, max_slope: float) -> bool:
	if not sampled.grounded or movement.length_squared() < 0.00001: return false
	for normal in sampled.normals:
		if (normal as Vector3).dot(Vector3.UP) < cos(deg_to_rad(max_slope))-0.0001 and movement.dot(normal) < -0.01: return true
	return false
