class_name AIPerception
extends RefCounted
## The sensor alone inspects world actors. Its public observations contain no internals.
const RANGE_M := GameConfig.AI_OBSERVATION_RANGE_M
const MEMORY_SECONDS := 6.0
var memory: Dictionary = {}
var actor_provider: Callable
var scans := 0
var preferred_sample := 0
const MAX_PREDICTION_SEGMENTS := 768
var lane_queries := 0
var last_lane_result: Dictionary = {}
var _observed_generations: Dictionary = {}

func clear() -> void:
	memory.clear()
	_observed_generations.clear()
	last_lane_result.clear()

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
		if not old.is_empty() and old.life_id == vehicle.life_id and _observed_generations.get(id,-1)==vehicle.state.generation and now-old.last_seen < AimSolver.MAX_OBSERVATION_AGE_S and now > old.last_seen:
			velocity = (center-old.position)/(now-old.last_seen)
			velocity = velocity.limit_length(30)
		memory[id] = {"entity_id":id,"life_id":vehicle.life_id,"visible":true,"position":center,"aim_point":visible_aim,"velocity":velocity,"last_seen":now}
		_observed_generations[id]=vehicle.state.generation
	for id in memory.keys():
		if now-float(memory[id].last_seen) > MEMORY_SECONDS:
			memory.erase(id)
			_observed_generations.erase(id)
	var result: Array[Dictionary] = []
	var ids := memory.keys()
	ids.sort()
	for id in ids: result.append(memory[id].duplicate(true))
	return result

func fire_lane_clear(observer: VehicleActor, observation: Dictionary, solution: Dictionary = {}) -> bool:
	lane_queries+=1
	last_lane_result=_predict_fire_lane(observer,observation,solution)
	return last_lane_result.ok

func _predict_fire_lane(observer: VehicleActor, observation: Dictionary, solution: Dictionary) -> Dictionary:
	if observation.is_empty() or not observation.get("visible",false): return _lane(false,"no_visible_observation")
	if not is_instance_valid(observer) or observer.gunner.shell==null: return _lane(false,"actor_unavailable")
	var ammunition := observer.gunner.shell
	var muzzle := observer.turret.muzzle.global_position
	var base := observer.turret.barrel_pivot.global_position
	var obstruction := WorldQueryAdapter.query_world_stop(observer.tank.get_world_3d().direct_space_state,base,muzzle-base,base.distance_to(muzzle),[observer.tank.get_rid()])
	if not obstruction.ok or obstruction.hit: return _lane(false,"barrel_occluded")
	var enemy := false
	var actors := _actors()
	var velocities := {}
	for vehicle in actors:
		if not is_instance_valid(vehicle) or vehicle.is_queued_for_deletion(): continue
		var key := _life_key(vehicle.entity_id,vehicle.life_id)
		if vehicle.state.team_id == observer.state.team_id:
			# Team motion is shared information. Enemy motion is ONLY the estimate
			# derived from visible samples; never read an enemy's actual velocity.
			velocities[key]=vehicle.tank.velocity
		elif vehicle.entity_id == observation.get("entity_id","") and vehicle.life_id == observation.get("life_id",-1):
			enemy=not vehicle.state.destroyed and _observed_generations.get(vehicle.entity_id,-1)==vehicle.state.generation
			velocities[key]=observation.get("velocity",Vector3.ZERO)
	if not enemy: return _lane(false,"stale_or_friendly_target")
	if solution.is_empty(): solution=AimSolver.solve_intercept(muzzle,observation,ammunition,observer.tank.velocity,Vector2.ZERO)
	if not solution.get("ok",false): return _lane(false,"no_intercept")
	if solution.get("shell_id","")!=ammunition.id: return _lane(false,"shell_changed")
	var fixed_step := 1.0/float(Engine.physics_ticks_per_second)
	if fixed_step>TranslationSweep.MAX_INTERVAL_S: return _lane(false,"unsupported_prediction_step")
	var duration := minf(ammunition.max_flight_time_s,float(solution.time_s)+5.0/maxf(1.0,ammunition.muzzle_velocity_mps))
	if not is_finite(duration) or duration<=0.0: return _lane(false,"invalid_prediction_time")
	var space := observer.tank.get_world_3d().direct_space_state
	var position := muzzle
	var velocity := observer.turret.barrel_direction()*ammunition.muzzle_velocity_mps+observer.tank.velocity
	var gravity := Vector3(0,-9.81,0)*ammunition.gravity_scale
	var source := _exterior_snapshots(actors)
	var previous := _prediction_frame(source,velocities,0.0)
	var elapsed := 0.0
	var travelled := 0.0
	var segments := 0
	var excluded := [{"entity_id":observer.entity_id,"life_id":observer.life_id}]
	while elapsed<duration-BallisticMath.TIME_EPS:
		var step := minf(fixed_step,duration-elapsed)
		var plan := BallisticMath.plan_times(velocity,gravity,step)
		if not plan.ok: return _lane(false,"prediction_substep_budget",segments)
		# Exactly the production's end-of-fixed-tick pose convention. Kinetic
		# contact interpolates within that interval; APHE keeps the same static
		# end pose for all its subsegments, without claiming moving internal CCD.
		var current := _prediction_frame(source,velocities,elapsed+fixed_step)
		var predicted := TranslationSweep.bind(previous,current,true,fixed_step) if ammunition.effect_policy=="kinetic" else current
		var times: PackedFloat64Array=plan.times
		for part in range(times.size()-1):
			segments+=1
			if segments>MAX_PREDICTION_SEGMENTS: return _lane(false,"prediction_segment_budget",segments-1)
			var h := times[part+1]-times[part]
			var advanced := BallisticMath.advance_free(position,velocity,gravity,h)
			if not advanced.ok: return _lane(false,"prediction_overflow",segments)
			var chord: Vector3=advanced.position-position
			var length := chord.length()
			if length<=ProjectileManager.MIN_SEG_M:
				position=advanced.position
				velocity=advanced.velocity
				continue
			var remaining := maxf(0.0,observer.weapon.gun_range-travelled)
			var alpha := minf(1.0,remaining/length)
			var query_length := length*alpha
			if query_length<=ProjectileManager.MIN_SEG_M: return _lane(false,"weapon_range_exceeded",segments)
			var end := position+chord*alpha
			var wall := WorldQueryAdapter.query_world_stop(space,position,chord,query_length,[observer.tank.get_rid()])
			if not wall.ok: return _lane(false,"world_query_failed",segments)
			var query := ShotQueryService.query({"query_id":"ai_preview","physics_tick":Engine.get_physics_frames(),"from_world":position,"to_world":end,
				"motion_fraction":Vector2(clampf(times[part]/fixed_step,0.0,1.0),clampf((times[part]+h*alpha)/fixed_step,0.0,1.0)),
				"excluded_instances":excluded,"include_modules":true,"include_crew":false,"world_stop":wall.contact},predicted)
			var selected := ExternalContactSelector.select_contact(query)
			if selected.status=="unresolved": return _lane(false,"geometry_unresolved",segments)
			var boundary := INF
			if selected.status=="vehicle": boundary=float(selected.event.distance_m)
			elif selected.status=="world": boundary=float(selected.contact.distance_m)
			# Only exterior module boxes are present in these permission snapshots.
			var external := DamageResolver.next_contact(query,{}, {},boundary)
			if not external.is_empty(): selected={"status":"vehicle","event":external}
			if selected.status=="world": return _lane(false,"world_blocked",segments)
			if selected.status=="vehicle":
				var intended: bool=selected.event.entity_id==observation.entity_id and selected.event.life_id==observation.life_id
				return _lane(intended,"predicted_target_contact" if intended else "other_vehicle_first",segments)
			travelled+=query_length
			if alpha<1.0: return _lane(false,"weapon_range_exceeded",segments)
			position=advanced.position
			velocity=advanced.velocity
		elapsed+=step
		previous=current
	return _lane(false,"predicted_path_misses",segments)

func _exterior_snapshots(actors: Array) -> Array:
	var snapshots: Array=[]
	for vehicle in actors:
		if not is_instance_valid(vehicle) or vehicle.is_queued_for_deletion() or vehicle.damage_layout_override==null: continue
		var snapshot := QuerySnapshotBuilder.build_from_vehicle(vehicle.tank,vehicle.damage_layout_override)
		# Shallow resource view: shared armor geometry is immutable, and only
		# explicit exterior modules participate. No crew or internal weak points.
		var exterior: VehicleLayoutDefinition=vehicle.damage_layout_override.duplicate(false)
		exterior.modules=[]
		exterior.crew_stations=[]
		for module in vehicle.damage_layout_override.modules:
			if module.external: exterior.modules.append(module)
		snapshot.layout=exterior
		snapshots.append(snapshot)
	return snapshots

static func _life_key(entity: String, life: int) -> String:
	return JSON.stringify([entity,life])

static func _prediction_frame(source: Array, velocities: Dictionary, time: float) -> Array:
	var snapshots: Array=[]
	for snapshot in source:
		var copy: Dictionary=snapshot.duplicate(false)
		var transforms := {}
		var motion: Vector3=velocities.get(_life_key(snapshot.entity_id,snapshot.life_id),Vector3.ZERO)
		for part in snapshot.part_world_transforms:
			var frame: Transform3D=snapshot.part_world_transforms[part]
			frame.origin+=motion*time
			transforms[part]=frame
		copy.part_world_transforms=transforms
		snapshots.append(copy)
	return snapshots

static func _lane(ok: bool, reason: String, segments: int = 0) -> Dictionary:
	return {"ok":ok,"reason":reason,"segments":segments}
