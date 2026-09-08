class_name AIPerception
extends RefCounted
## The sensor alone inspects world actors. Its public observations contain no internals.
const RANGE_M := 180.0
const MEMORY_SECONDS := 6.0
var memory: Dictionary = {}
var actor_provider: Callable
var scans := 0
var preferred_sample := 0

func clear() -> void: memory.clear()

func _actors() -> Array:
	return actor_provider.call() if actor_provider.is_valid() else []

func _snapshots() -> Array:
	var snapshots: Array = []
	for vehicle in _actors():
		if is_instance_valid(vehicle) and not vehicle.is_queued_for_deletion() and vehicle.damage_layout_override != null:
			snapshots.append(QuerySnapshotBuilder.build_from_vehicle(vehicle.tank,vehicle.damage_layout_override))
	return snapshots

func contact(observer: VehicleActor, from: Vector3, to: Vector3, prepared: Array = []) -> Dictionary:
	var snapshots := _snapshots() if prepared.is_empty() else prepared
	var offset := to-from
	if offset.length() < 0.001: return {"status":"unresolved"}
	var wall := WorldQueryAdapter.query_world_stop(observer.tank.get_world_3d().direct_space_state,from,offset,offset.length(),[observer.tank.get_rid()])
	if not wall.ok: return {"status":"unresolved"}
	return ExternalContactSelector.select_contact(ShotQueryService.query({"from_world":from,"to_world":to,"include_modules":false,"include_crew":false,"excluded_instances":[{"entity_id":observer.entity_id,"life_id":observer.life_id}],"world_stop":wall.contact},snapshots))

func scan(observer: VehicleActor, now: float) -> Array[Dictionary]:
	scans += 1
	for row in memory.values(): row.visible = false
	var eye := observer.turret.global_position+Vector3.UP*0.55
	var forward := -observer.turret.global_basis.z
	var snapshots := _snapshots()
	for vehicle in _actors():
		if not is_instance_valid(vehicle) or vehicle == observer or vehicle.state.team_id == observer.state.team_id: continue
		var center: Vector3 = vehicle.tank.global_position+Vector3.UP*1.25
		var offset := center-eye
		if offset.length() > RANGE_M or forward.dot(offset.normalized()) < cos(deg_to_rad(75)): continue
		# Visible surface samples, never module or crew coordinates.
		var samples := [Vector3(0,1.2,0),Vector3(-0.8,1.5,0),Vector3(0.8,1.5,0),Vector3(0,2.2,-0.3),Vector3(-0.6,2.2,-0.3),Vector3(0.6,2.2,-0.3)]
		var visible_aim: Variant = null
		for index in samples.size():
			var local: Vector3 = samples[(index+preferred_sample)%samples.size()]
			var sample: Vector3 = vehicle.tank.global_transform*local
			var hit := contact(observer,eye,sample,snapshots)
			if hit.status != "vehicle" or hit.event.entity_id != vehicle.entity_id or hit.event.life_id != vehicle.life_id: continue
			if vehicle.state.destroyed:
				if memory.has(vehicle.entity_id) and memory[vehicle.entity_id].life_id == vehicle.life_id: memory.erase(vehicle.entity_id)
				break # Wreck recognition requires a visible exterior.
			var aim: Vector3 = hit.event.point_world+(sample-eye).normalized()*0.2
			if visible_aim == null: visible_aim = aim
			var local_direction := observer.tank.global_basis.inverse()*(aim-observer.turret.barrel_pivot.global_position)
			var pitch := rad_to_deg(atan2(local_direction.y,Vector2(local_direction.x,local_direction.z).length()))
			if pitch >= observer.definition.barrel_pitch_min+0.3 and pitch <= observer.definition.barrel_pitch_max-0.3:
				visible_aim = aim
				break # Prefer a visible surface the actual gun can reach, including at close range.
		if visible_aim == null: continue
		var id: String = vehicle.entity_id
		var velocity := Vector3.ZERO
		var old: Dictionary = memory.get(id,{})
		if not old.is_empty() and old.life_id == vehicle.life_id and now-old.last_seen < 0.6 and now > old.last_seen:
			velocity = (center-old.position)/(now-old.last_seen)
			velocity = velocity.limit_length(30)
		memory[id] = {"entity_id":id,"life_id":vehicle.life_id,"visible":true,"position":center,"aim_point":visible_aim,"velocity":velocity,"last_seen":now}
	for id in memory.keys():
		if now-float(memory[id].last_seen) > MEMORY_SECONDS: memory.erase(id)
	var result: Array[Dictionary] = []
	var ids := memory.keys()
	ids.sort()
	for id in ids: result.append(memory[id].duplicate(true))
	return result

func fire_lane_clear(observer: VehicleActor, observation: Dictionary) -> bool:
	if observation.is_empty() or not observation.get("visible",false): return false
	var muzzle := observer.turret.muzzle.global_position
	var base := observer.turret.barrel_pivot.global_position
	var obstruction := WorldQueryAdapter.query_world_stop(observer.tank.get_world_3d().direct_space_state,base,muzzle-base,base.distance_to(muzzle),[observer.tank.get_rid()])
	if not obstruction.ok or obstruction.hit: return false
	var enemy := false
	for vehicle in _actors():
		if is_instance_valid(vehicle) and vehicle.entity_id == observation.entity_id and vehicle.life_id == observation.life_id:
			enemy = vehicle.state.team_id != observer.state.team_id
	if not enemy: return false
	var distance := muzzle.distance_to(observation.aim_point)+5.0
	var hit := contact(observer,muzzle,muzzle+observer.turret.barrel_direction()*distance)
	return hit.status == "vehicle" and hit.event.entity_id == observation.entity_id and hit.event.life_id == observation.life_id
