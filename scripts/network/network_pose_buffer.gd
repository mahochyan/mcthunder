class_name NetworkPoseBuffer
extends RefCounted
## Presentation-only server timeline. Never extrapolate or blend across a new life.
const DELAY_TICKS := 6.0
const CAPACITY := 32
var frames: Array[Dictionary] = []
var render_tick := 0.0
func clear() -> void: frames.clear(); render_tick=0.0
static func valid_snapshot(snapshot: Variant) -> bool:
	if not snapshot is Dictionary or snapshot.size()!=6 or not NetworkEventJournal.integer(snapshot.get("version")) or snapshot.version!=VehicleFramePose.NETWORK_VERSION: return false
	if not NetworkEventJournal.valid_session(snapshot.get("session_id")): return false
	for key in ["tick","sequence","event_sequence"]:
		if not NetworkEventJournal.integer(snapshot.get(key)): return false
	if not snapshot.get("vehicles") is Array or snapshot.vehicles.is_empty() or snapshot.vehicles.size()>2: return false
	var ids := {}
	for row in snapshot.vehicles:
		if not row is Dictionary or row.size()!=15 or not NetworkEventJournal.identifier(row.get("entity_id")) or ids.has(row.entity_id): return false
		ids[row.entity_id]=true
		for key in ["life_id","generation","control_epoch","shots"]:
			if not NetworkEventJournal.integer(row.get(key)): return false
		if row.life_id<1 or not row.get("destroyed") is bool or not NetworkEventJournal.integer(row.get("accepted_sequence"),-1): return false
		if not NetworkEventJournal.vector(row.get("position"),NetworkEventJournal.POSITION_LIMIT): return false
		for key in ["yaw","turret_yaw","gun_pitch","hull_pitch","hull_roll"]:
			var value: Variant=row.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>TAU*1000.0: return false
		if not VehicleFramePose.valid(row.get("frame_pose")) or not ReactiveArmorProfile.valid_state(row.get("reactive_armor")): return false
	return true
func push(snapshot: Dictionary) -> bool:
	if not valid_snapshot(snapshot): return false
	if not frames.is_empty() and (snapshot.session_id!=frames[-1].session_id or snapshot.tick<frames[-1].tick or snapshot.sequence<=frames[-1].sequence or snapshot.event_sequence<frames[-1].event_sequence): return false
	# The final snapshot may share a simulation tick with the last broadcast.
	if not frames.is_empty() and snapshot.tick==frames[-1].tick: frames.pop_back()
	frames.append(snapshot.duplicate(true))
	if frames.size()>CAPACITY: frames.pop_front()
	render_tick=maxf(render_tick,float(snapshot.tick)-DELAY_TICKS) if frames.size()>1 else float(snapshot.tick)-DELAY_TICKS
	return true
func advance(delta: float) -> Array:
	if frames.is_empty(): return []
	render_tick=minf(render_tick+maxf(delta,0.0)*60.0,float(frames[-1].tick))
	return sample(render_tick)
func same_life(a: Dictionary, b: Dictionary) -> bool:
	return a.entity_id==b.entity_id and a.life_id==b.life_id and a.generation==b.generation and a.control_epoch==b.control_epoch
func sample(tick: float) -> Array:
	if frames.is_empty(): return []
	var before: Dictionary=frames[0]
	var after: Dictionary=frames[-1]
	for frame in frames:
		if frame.tick<=tick: before=frame
		if frame.tick>=tick: after=frame; break
	var alpha := clampf((tick-float(before.tick))/maxf(1.0,float(after.tick)-float(before.tick)),0,1)
	var old_by_id := {}; var next_by_id := {}
	for row in before.vehicles: old_by_id[row.entity_id]=row
	for row in after.vehicles: next_by_id[row.entity_id]=row
	var result: Array=[]
	for current in frames[-1].vehicles:
		var old: Dictionary=old_by_id.get(current.entity_id,current)
		var next: Dictionary=next_by_id.get(current.entity_id,current)
		var pose: Dictionary=current.duplicate(true)
		if same_life(old,current) and same_life(next,current) and old.get("destroyed",false)==current.get("destroyed",false):
			var a := Vector3(old.position[0],old.position[1],old.position[2])
			var b := Vector3(next.position[0],next.position[1],next.position[2])
			var p := a.lerp(b,alpha); pose.position=[p.x,p.y,p.z]
			for angle in ["yaw","turret_yaw","gun_pitch"]: pose[angle]=lerp_angle(float(old[angle]),float(next[angle]),alpha)
			for angle in ["hull_pitch","hull_roll"]: pose[angle]=lerp_angle(float(old.get(angle,0)),float(next.get(angle,0)),alpha)
			pose.frame_pose=VehicleFramePose.blend(old.frame_pose,next.frame_pose,alpha)
		result.append(pose)
	return result
