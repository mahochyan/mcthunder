class_name NetworkBattleWorld
extends Node3D
## Early open-field authority world, without local player, HUD, Camera3D or audio.
var actors: Array[VehicleActor] = []
var projectiles: ProjectileManager
var journal := NetworkEventJournal.new()
var journal_error := ""
var _published_projectile_id := 0
var ready_ok := false
func _ready() -> void:
	process_physics_priority=SimulationPhases.PROJECTILES-1
	if not journal.reset(Crypto.new().generate_random_bytes(16).hex_encode()): return
	var ground := StaticBody3D.new()
	ground.collision_layer=GameConfig.LAYER_WORLD
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size=Vector3(6000,1,6000)
	collision.shape=box; collision.position.y=-0.5
	ground.add_child(collision); add_child(ground)
	VehicleSimulationDriver.for_scene(self)
	var defs := VehicleDefs.new()
	if not defs.load_defaults().ok or not VehicleCatalog.new().load_all(defs).ok: return
	projectiles=ProjectileManager.new(); projectiles.presentation_enabled=false; add_child(projectiles)
	projectiles.snapshot_provider=query_snapshots
	projectiles.exclude_provider=exclude_rids
	projectiles.damage_handler=apply_damage
	projectiles.projectile_finished.connect(record_finished)
	for index in 2:
		var actor := VehicleActor.new(); actor.presentation_enabled=false; add_child(actor)
		if not actor.setup(defs,VehicleCatalog.IDS[index],"A" if index==0 else "B",index+1,Transform3D(Basis.IDENTITY,Vector3(index*16,0,12)),4,null).ok: return
		actor.gunner.projectile_manager=projectiles
		actor.gunner.snapshot_provider=query_snapshots
		actor.gunner.round_provider=func() -> int: return 1
		actors.append(actor)
	ready_ok=true
func query_snapshots() -> Array:
	var result: Array=[]
	for actor in actors: result.append(QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override))
	return result
func exclude_rids(entity: String, life: int) -> Array[RID]:
	for actor in actors:
		if actor.entity_id==entity and actor.life_id==life: return [actor.tank.get_rid()]
	return []
func apply_damage(event: Dictionary, available_mm: float) -> Dictionary:
	if event.get("round_id",-1)!=1: return {"ok":false,"reason":"stale_round"}
	for actor in actors:
		if actor.entity_id==event.get("entity_id") and actor.life_id==event.get("life_id"):
			return actor.apply_projectile_damage(event,available_mm)
	return {"ok":false,"reason":"stale_entity"}
func record_finished(record: Dictionary) -> void:
	var result := journal.append("projectile_finished",record.physics_tick,_record_shot(record),{"reason":record.reason,"position":_vector(record.impact_point)})
	if not result.ok: _journal_failed(result.reason)

static func _vector(value: Vector3) -> Array: return [value.x,value.y,value.z]
static func _record_shot(record: Dictionary) -> Dictionary:
	return {"round_id":record.round_id,"projectile_id":record.projectile_id,"shooter_id":record.shooter_id,"shooter_life_id":record.shooter_life_id,"shot_id":record.shot_id}
static func _projectile_shot(projectile: ProjectileState) -> Dictionary:
	return {"round_id":projectile.round_id,"projectile_id":projectile.projectile_id,"shooter_id":projectile.shooter_id,"shooter_life_id":projectile.shooter_life_id,"shot_id":projectile.shot_id}
func _journal_failed(reason: String) -> void:
	if journal_error.is_empty(): push_error("Network event journal: "+reason)
	journal_error=reason
func flush_launches() -> void:
	if projectiles==null or not journal_error.is_empty(): return
	var active := projectiles.active_states()
	active.sort_custom(func(a: ProjectileState,b: ProjectileState) -> bool: return a.projectile_id<b.projectile_id)
	for projectile: ProjectileState in active:
		if projectile.projectile_id<=_published_projectile_id: continue
		var payload := {"shell_id":projectile.shell_id,"position":_vector(projectile.launch_position),"velocity":_vector(projectile.launch_velocity),"gravity":_vector(projectile.gravity_world)}
		var result := journal.append("projectile_fired",projectile.born_physics_tick,_projectile_shot(projectile),payload)
		if not result.ok: _journal_failed(result.reason); return
		_published_projectile_id=projectile.projectile_id
func _physics_process(_delta: float) -> void:
	# Poll only after every vehicle has committed its weapon and inventory, and
	# before any projectile advances. try_spawn remains free of reentrant signals.
	flush_launches()
func active_projectiles() -> Array:
	var result: Array=[]
	for projectile: ProjectileState in projectiles.active_states():
		result.append({"shot":_projectile_shot(projectile),"shell_id":projectile.shell_id,"position":_vector(projectile.position_world),"velocity":_vector(projectile.velocity_world),"gravity":_vector(projectile.gravity_world),"age_s":projectile.age_s})
	return result
func own_status(actor: VehicleActor) -> Dictionary:
	# This status accompanies the same public snapshot, only for its owner.
	return {"cooldown":actor.gunner.cooldown_left,"ammo":actor.gunner.rounds_remaining,"speed":actor.tank.forward_speed,"consumed_sequence":actor.last_consumed_sequence,"fire_control":actor.fire_control.snapshot()}
func snapshot(sequence: int) -> Dictionary:
	var vehicles: Array=[]
	for actor in actors:
		var p := actor.tank.global_position
		var rotation := actor.tank.global_rotation
		# hull_pitch/roll are legacy names for drive-root angles. The sprung hull
		# and running gear have their own local poses in frame_pose.
		vehicles.append({"entity_id":actor.entity_id,"life_id":actor.life_id,"generation":actor.state.generation,"control_epoch":actor.control_epoch,
			"position":[p.x,p.y,p.z],"yaw":actor.tank.global_rotation.y,"turret_yaw":actor.turret.rotation.y,"gun_pitch":actor.turret.barrel_pivot.rotation.x,
			"hull_pitch":rotation.x,"hull_roll":rotation.z,
			"frame_pose":VehicleFramePose.capture(actor.tank),
			"shots":actor.gunner.shots_fired,"destroyed":actor.state.destroyed,"accepted_sequence":actor._last_input_sequence})
	return {"version":VehicleFramePose.NETWORK_VERSION,"session_id":journal.session_id,"sequence":sequence,"tick":Engine.get_physics_frames(),"vehicles":vehicles,"event_sequence":journal.head()}
