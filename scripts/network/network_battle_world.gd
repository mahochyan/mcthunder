class_name NetworkBattleWorld
extends Node3D
## Early open-field authority world, without local player, HUD, Camera3D or audio.
var actors: Array[VehicleActor] = []
var projectiles: ProjectileManager
var events: Array[Dictionary] = []
var event_sequence := 0
var ready_ok := false
func _ready() -> void:
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
	event_sequence+=1
	events.append({"sequence":event_sequence,"projectile_id":record.get("projectile_id"),"shot_id":record.get("shot_id"),"shooter_id":record.get("shooter_id"),"reason":record.get("reason")})
	if events.size()>64: events.pop_front()
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
	return {"version":VehicleFramePose.NETWORK_VERSION,"sequence":sequence,"tick":Engine.get_physics_frames(),"vehicles":vehicles,"event_sequence":event_sequence,"events":events.duplicate(true)}
