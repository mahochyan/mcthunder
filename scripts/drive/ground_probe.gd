class_name GroundProbe
extends RefCounted
## Only actual WORLD geometry supplies ground normals; no height-map fiction.
static func sample(body: TankVehicle, direction: Vector3, half_size: Vector2) -> Dictionary:
	var out := {"grounded":false,"normal":Vector3.UP,"slope_deg":0.0,"points":[],"normals":[],"center_height":body.global_position.y,"support_count":0}
	var space := body.get_world_3d().direct_space_state
	var side := direction.cross(Vector3.UP).normalized()
	var sum := Vector3.ZERO
	var height := 0.0
	var drag := 0.0
	out.surface_drag=0.0
	out.left_support=0.0; out.right_support=0.0; out.traction_support=0.0
	out.track_contacts={TrackAssembly.LEFT:[],TrackAssembly.RIGHT:[]}
	for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1),Vector2.ZERO]:
		var base: Vector3 = body.global_position+side*pair.x*half_size.x+direction*pair.y*half_size.y
		var part := TrackAssembly.LEFT if pair.x<0 else TrackAssembly.RIGHT
		var frame := body.track_left_frame if pair.x<0 else body.track_right_frame
		var offset := Vector3.ZERO
		var authored: bool = pair.x!=0 and body.track_probe_offsets.has(part)
		if authored:
			offset=body.track_probe_offsets[part][0 if pair.y>0 else 1]
			base=frame.to_global(offset)
		var contact := {"id":"front" if pair.y>0 else "rear","hit":false,"supported":false,"position":Vector3.ZERO,"normal":Vector3.UP,"gap_m":INF}
		if pair.x!=0: out.track_contacts[part].append(contact)
		var query := PhysicsRayQueryParameters3D.create(base+Vector3.UP*GameConfig.DRIVE_PROBE_UP_M,base-Vector3.UP*GameConfig.DRIVE_PROBE_DOWN_M,GameConfig.LAYER_WORLD,[body.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).dot(Vector3.UP) <= 0.1: continue
		var gap := absf(frame.to_local(hit.position).y-offset.y) if authored else absf(body.to_local(hit.position).y)
		contact.hit=true; contact.position=hit.position; contact.normal=hit.normal; contact.gap_m=gap
		contact.supported=body.is_on_floor() and gap<=GameConfig.DRIVE_SUPPORT_REACH_M
		out.points.append(hit.position)
		out.normals.append(hit.normal)
		sum += hit.normal
		height += hit.position.y
		drag += DriveSurface.drag_at(hit.collider,hit.position)
		out.support_count += 1
		# A ray can see the bottom of a ditch without supporting the track above it.
		if pair.x!=0 and contact.supported:
			if pair.x<0: out.left_support+=0.5
			else: out.right_support+=0.5
	if out.support_count > 0 and sum.length_squared() > 0.01:
		out.normal = sum.normalized()
		out.center_height = height/out.support_count
		out.slope_deg = rad_to_deg(acos(clampf(out.normal.dot(Vector3.UP),-1,1)))
		# Rays measure terrain/support reach; only the movement solver confirms landing.
		# Proximity alone must not grant braking, steering or pose recovery in flight.
		out.grounded = body.is_on_floor()
		if out.grounded: out.surface_drag=drag/out.support_count
	if out.grounded: out.traction_support=(out.left_support+out.right_support)*0.5
	else: out.left_support=0.0; out.right_support=0.0
	return out

static func blocks_uphill(sampled: Dictionary, movement: Vector3, max_slope: float) -> bool:
	if not sampled.grounded or movement.length_squared() < 0.00001: return false
	for normal in sampled.normals:
		if (normal as Vector3).dot(Vector3.UP) < cos(deg_to_rad(max_slope))-0.0001 and movement.dot(normal) < -0.01: return true
	return false
