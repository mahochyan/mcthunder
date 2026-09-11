extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frame(tick: int, x: float, yaw: float, life: int=1) -> Dictionary:
	return {"tick":tick,"sequence":tick,"vehicles":[{"entity_id":"A","life_id":life,"generation":1,"control_epoch":1,"position":[x,0,0],"yaw":yaw,"turret_yaw":yaw,"gun_pitch":0,"destroyed":false}]}
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
	check(buffer.push(frame(3,1,0)) and buffer.sample(3)[0].position[0]==1,"fresh connection accepts restarted server timeline")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("NETWORK_POSE_CHECKS_PASS" if failures==0 else "NETWORK_POSE_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
