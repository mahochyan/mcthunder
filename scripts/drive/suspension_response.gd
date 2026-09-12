class_name SuspensionResponse
extends RefCounted
## Four-support, bounded kinematic suspension. Drive collision remains the sole
## ground-motion solver; these authoritative poses also move shot geometry.
var displacement: Array[float] = [0.0,0.0,0.0,0.0]
var velocity: Array[float] = [0.0,0.0,0.0,0.0]
var targets: Array[float] = [0.0,0.0,0.0,0.0]
var previous_root := Transform3D.IDENTITY
var previous_grounded := false
var initialized := false
var impacts := 0

func reset() -> void:
	displacement.fill(0.0); velocity.fill(0.0); targets.fill(0.0)
	previous_root=Transform3D.IDENTITY; previous_grounded=false; initialized=false; impacts=0

func snapshot() -> Dictionary:
	return {"version":1,"displacement":displacement.duplicate(),"velocity":velocity.duplicate(),"targets":targets.duplicate(),"previous_root":previous_root,"previous_grounded":previous_grounded,"initialized":initialized,"impacts":impacts}

func step(tank: TankVehicle, contacts: Dictionary, delta: float, impact_speed: float) -> void:
	var profile := tank.defs.drive_profile
	if not profile.suspension_enabled or tank.track_probe_offsets.size()!=2 or delta<=0: return
	var grounded: bool=contacts.grounded
	var points: Array[Vector3]=[]
	var terrain: Array[float]=[]
	for part in [TrackAssembly.LEFT,TrackAssembly.RIGHT]:
		for index in 2:
			var point: Vector3=tank.track_probe_offsets[part][index]
			points.append(point)
			var id := "front" if index==0 else "rear"
			var height := -profile.suspension_extension_m
			for contact in contacts.track_contacts[part]:
				if contact.id==id and contact.hit and grounded:
					height=tank.to_local(contact.position).y-point.y
			terrain.append(clampf(height,-profile.suspension_extension_m,profile.suspension_compression_m))
	var impacted := grounded and impact_speed>=profile.landing_min_speed
	if impacted: impacts+=1
	var relative_motion := tank.global_transform.affine_inverse()*previous_root
	var omega := profile.suspension_response_rate
	for i in 4:
		targets[i]=clampf(terrain[i],-profile.suspension_compression_m,profile.suspension_extension_m) if grounded else 0.0
		# Preserve sprung inertia across drive-root movement while grounded. Damping
		# is relative to the moving base, so sustained climbs do not pin bump stops.
		var correction := (relative_motion*points[i]).y-points[i].y if initialized and previous_grounded and grounded else 0.0
		var base_speed := -correction/delta
		displacement[i]+=correction
		if impacted: velocity[i]-=impact_speed*profile.suspension_impact_scale
		velocity[i]=clampf(velocity[i],-profile.suspension_point_speed_limit,profile.suspension_point_speed_limit)
		var target := targets[i]+2.0*base_speed/omega
		var error := displacement[i]-target
		var coefficient := velocity[i]+omega*error
		var decay := exp(-omega*delta)
		displacement[i]=target+(error+coefficient*delta)*decay
		velocity[i]=(velocity[i]-omega*coefficient*delta)*decay
		velocity[i]=clampf(velocity[i],-profile.suspension_point_speed_limit,profile.suspension_point_speed_limit)
		var bounded := clampf(displacement[i],-profile.suspension_compression_m,profile.suspension_extension_m)
		if bounded!=displacement[i]:
			displacement[i]=bounded
			velocity[i]=0.0
	_apply_hull(tank,points,profile)
	_apply_track(tank.track_left_frame,points[0],points[1],terrain[0],terrain[1],profile)
	_apply_track(tank.track_right_frame,points[2],points[3],terrain[2],terrain[3],profile)
	previous_root=tank.global_transform; previous_grounded=grounded; initialized=true

func _apply_hull(tank: TankVehicle, points: Array[Vector3], profile: DriveProfile) -> void:
	var front := (displacement[0]+displacement[2])*0.5
	var rear := (displacement[1]+displacement[3])*0.5
	var left := (displacement[0]+displacement[1])*0.5
	var right := (displacement[2]+displacement[3])*0.5
	var limit := deg_to_rad(profile.suspension_angle_limit_degrees)
	var pitch := clampf(atan2(front-rear,absf(points[0].z-points[1].z)),-limit,limit)
	var roll := clampf(atan2(right-left,absf(points[2].x-points[0].x)),-limit,limit)
	tank.hull_frame.transform=Transform3D(Basis.from_euler(Vector3(pitch,0,roll)),Vector3(0,(front+rear)*0.5,0))

func _apply_track(frame: Node3D, front: Vector3, rear: Vector3, front_height: float, rear_height: float, profile: DriveProfile) -> void:
	var limit := deg_to_rad(profile.suspension_angle_limit_degrees)
	var angle := clampf(atan2(front_height-rear_height,absf(front.z-rear.z)),-limit,limit)
	var basis := Basis(Vector3.RIGHT,angle)
	var center := (front+rear)*0.5
	frame.transform=Transform3D(basis,Vector3(0,(front_height+rear_height)*0.5+center.y-(basis*center).y,0))
