extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frame(tick: int, x: float, yaw: float, life: int=1) -> Dictionary:
	var relative := {"version":VehicleFramePose.VERSION}
	for part in VehicleFramePose.PARTS: relative[part]=VehicleFramePose.pack(Transform3D.IDENTITY)
	return {"version":VehicleFramePose.NETWORK_VERSION,"session_id":"11111111111111111111111111111111","event_sequence":0,"tick":tick,"sequence":tick,"vehicles":[{"entity_id":"A","life_id":life,"generation":1,"control_epoch":1,"position":[x,0,0],"yaw":yaw,"turret_yaw":yaw,"gun_pitch":0,"hull_pitch":0,"hull_roll":0,"frame_pose":relative,"destroyed":false,"shots":0,"accepted_sequence":-1}]}
func _initialize() -> void:
	var buffer := NetworkPoseBuffer.new()
	var first := frame(90,0,deg_to_rad(179))
	check(buffer.push(first) and buffer.push(frame(96,6,deg_to_rad(-179))),"ordered authoritative samples admitted")
	var middle: Dictionary=buffer.sample(93)[0]
	check(absf(middle.position[0]-3)<0.0001,"midpoint is interpolated between server samples")
	check(absf(absf(middle.yaw)-PI)<0.0001,"angle crosses wrap by shortest arc")
	check(buffer.sample(120)[0].position[0]==6,"missing packets freeze at latest position without extrapolation")
	check(not buffer.push(first),"late or duplicate snapshot cannot rewind timeline")
	var final := frame(96,6,deg_to_rad(-179)); final.sequence=97; final.vehicles[0].destroyed=true
	check(buffer.push(final) and buffer.frames.size()==2 and buffer.sample(96)[0].destroyed,"newer final snapshot at same tick replaces last state")
	var malformed := frame(99,9,0); malformed.vehicles[0].position[1]=NAN
	check(not buffer.push(malformed) and buffer.frames.size()==2,"invalid pose rejected atomically")
	buffer.push(frame(99,100,0,2))
	check(buffer.sample(97)[0].position[0]==100,"new life snaps instead of crossing old vehicle path")
	var changed := frame(102,200,0,2); changed.vehicles[0].control_epoch=2
	buffer.push(changed)
	check(buffer.sample(100)[0].position[0]==200,"control epoch change clears old pose interpolation")
	var copy: Array=buffer.sample(102); copy[0].position[0]=-500
	check(buffer.sample(102)[0].position[0]==200,"presentation consumers cannot mutate authoritative samples")
	for tick in range(103,160): buffer.push(frame(tick,tick,0,2))
	check(buffer.frames.size()==NetworkPoseBuffer.CAPACITY,"timeline memory remains bounded")
	buffer.clear()
	var tilted := frame(3,1,0); tilted.vehicles[0].hull_pitch=0.1; tilted.vehicles[0].hull_roll=-0.2
	var tilted_next := frame(9,2,0); tilted_next.vehicles[0].hull_pitch=0.3; tilted_next.vehicles[0].hull_roll=0.2
	check(buffer.push(tilted) and buffer.push(tilted_next),"server hull attitude accepted")
	var tilted_middle: Dictionary=buffer.sample(6)[0]
	check(absf(tilted_middle.hull_pitch-0.2)<0.00001 and absf(tilted_middle.hull_roll)<0.00001,"hull pitch and roll follow server interpolation")
	var invalid_tilt := frame(12,3,0); invalid_tilt.vehicles[0].hull_pitch=NAN
	check(not buffer.push(invalid_tilt),"nonfinite hull attitude rejected")
	buffer.clear()
	var articulated := frame(3,0,0)
	var next_articulated := frame(9,0,0)
	articulated.vehicles[0].frame_pose.hull=VehicleFramePose.pack(Transform3D(Basis(Vector3.FORWARD,0.1),Vector3(0,-0.1,0)))
	next_articulated.vehicles[0].frame_pose.hull=VehicleFramePose.pack(Transform3D(Basis(Vector3.FORWARD,0.3),Vector3(0,-0.3,0)))
	next_articulated.vehicles[0].frame_pose.running_left.position[1]=0.12
	check(buffer.push(articulated) and buffer.push(next_articulated),"relative hull and independent track poses admitted")
	var relative: Dictionary=buffer.sample(6)[0].frame_pose
	var expected := Transform3D(Basis(Vector3.FORWARD,0.2),Vector3(0,-0.2,0))
	check(VehicleFramePose.unpack(relative.hull).is_equal_approx(expected) and absf(relative.running_left.position[1]-0.06)<0.00001 and relative.running_right.position[1]==0,"hull rotation and side travel interpolate independently")
	for field in ["missing","nan","overflow","quaternion","version"]:
		var invalid := frame(12,0,0)
		match field:
			"missing": invalid.vehicles[0].frame_pose.erase("running_right")
			"nan": invalid.vehicles[0].frame_pose.hull.position[0]=NAN
			"overflow": invalid.vehicles[0].frame_pose.hull.position[0]=1e100
			"quaternion": invalid.vehicles[0].frame_pose.hull.rotation=[0,0,0,0]
			"version": invalid.vehicles[0].frame_pose.version=99
		check(not buffer.push(invalid) and buffer.frames.size()==2,"malformed relative pose rejected atomically: "+field)
	var old_protocol := frame(12,0,0); old_protocol.version=1
	check(not buffer.push(old_protocol),"old protocol cannot silently omit suspended hull state")
	var respawn := frame(12,0,0,2); buffer.push(respawn)
	check(VehicleFramePose.unpack(buffer.sample(10)[0].frame_pose.hull)==Transform3D.IDENTITY,"new life snaps relative hull pose instead of blending old compression")
	buffer.clear()
	var wrap_a := frame(3,0,0); var wrap_b := frame(9,0,0)
	wrap_a.vehicles[0].frame_pose.hull=VehicleFramePose.pack(Transform3D(Basis(Vector3.FORWARD,deg_to_rad(179)),Vector3.ZERO))
	wrap_b.vehicles[0].frame_pose.hull=VehicleFramePose.pack(Transform3D(Basis(Vector3.FORWARD,deg_to_rad(-179)),Vector3.ZERO))
	buffer.push(wrap_a); buffer.push(wrap_b)
	var wrap_pose := VehicleFramePose.unpack(buffer.sample(6)[0].frame_pose.hull)
	check(wrap_pose.basis.is_equal_approx(Basis(Vector3.FORWARD,PI)),"relative quaternion interpolation crosses wrap by shortest arc")
	var detached_copy: Dictionary=buffer.sample(9)[0].frame_pose
	detached_copy.hull.position[0]=500
	check(buffer.sample(9)[0].frame_pose.hull.position[0]==0,"relative presentation data cannot mutate buffered authority")
	buffer.clear()
	check(buffer.push(frame(3,1,0)) and buffer.sample(3)[0].position[0]==1,"fresh connection accepts restarted server timeline")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("NETWORK_POSE_CHECKS_PASS" if failures==0 else "NETWORK_POSE_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
