extends SceneTree
## Actual Actor/PlayerController/terrain/projectile integration at natural physics
## time. Input actions exercise production polling; camera angles are a declared
## headless fixture, not a claim of OS mouse or human driving verification.
## All three vehicles are TEST ONLY with game_rule profiles, not historical tanks.

class AuthorityProbe extends Node:
	var actors: Array[VehicleActor] = []
	var projectiles: ProjectileManager
	var phase := ""
	var rows: Array[Dictionary] = []
	var shots: Dictionary = {}
	func _ready() -> void:
		process_mode=Node.PROCESS_MODE_PAUSABLE
		process_physics_priority=SimulationPhases.PROJECTILES-1
	func _physics_process(_delta: float) -> void:
		for actor in actors:
			var barrel := actor.turret.barrel_direction()
			var target := (actor.turret._aim_point()-actor.turret.barrel_pivot.global_position).normalized()
			var angles := TurretMechanismState.angles_for(barrel)
			var intended := TurretMechanismState.angles_for(target)
			if not phase.is_empty():
				rows.append({"entity":actor.entity_id,"phase":phase,
					"pitch_error":absf(angles.x-intended.x),"yaw_error":absf(wrapf(angles.y-intended.y,-PI,PI)),
					"hull_pitch":actor.tank.hull_frame.global_rotation.x,"spring_pitch":actor.tank.hull_frame.rotation.x,
					"compensation":actor.turret.mechanism.compensation_rate,
					"valid":VehicleFramePose.valid(VehicleFramePose.capture(actor.tank))})
			var projectile := projectiles.get_projectile_state(actor.gunner.last_projectile_id)
			if projectile!=null and not shots.has(projectile.projectile_id):
				# Sample between authority weapon and projectile phases, on birth tick.
				shots[projectile.projectile_id]={"entity":actor.entity_id,"tick":Engine.get_physics_frames(),
					"born_tick":projectile.born_physics_tick,"velocity":projectile.launch_velocity,
					"vehicle_velocity":actor.tank.velocity,"muzzle_speed":actor.gunner.shell.muzzle_velocity_mps,
					"barrel":barrel,"target":target,"origin":projectile.launch_position,"muzzle":actor.turret.muzzle.global_position}

var checks := 0
var failures := 0
var world: Node3D
var projectiles: ProjectileManager
var actors: Array[VehicleActor] = []
var probe: AuthorityProbe
var damage_shot := 0
const MODES := ["none","vertical","two_axis"]
const DT := 1.0/60.0

func _initialize() -> void:
	create_timer(180.0).timeout.connect(func() -> void:
		print("[WATCHDOG] turret mechanism integration exceeded 180 seconds")
		quit(2))
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func ticks(count: int) -> void:
	for i in count: await physics_frame
	await process_frame
func tap(action: String) -> void:
	Input.action_press(action)
	await ticks(3)
	Input.action_release(action)
	await ticks(3)
func release_inputs() -> void:
	for action in ["move_forward","move_back","turn_left","turn_right","aim","fire","repair","binoculars","free_look"]:
		Input.action_release(action)

func axis_layout() -> VehicleLayoutDefinition:
	# One designed 20 mm plate followed by three separated 40 cm module boxes.
	# Projectiles enter along local -Z at x=-1/0/+1, y=1. This isolates each
	# electrical/mechanical failure from unrelated crew, engine or ammunition.
	var fixture := ArmorTrainingTargets.build([{"center":Vector3(0,1,-1),"thickness":20.0}])
	var layout: VehicleLayoutDefinition=fixture.layout
	layout.id="test_turret_axis_layout"
	layout.recovery_enabled=true
	for spec in [["horizontal","turret_horizontal_drive",-1.0],["vertical","turret_vertical_drive",0.0],["stabilizer","stabilizer",1.0]]:
		var module := ModuleVolumeDefinition.new()
		module.id=spec[0]; module.kind=spec[1]; module.part_id="hull"
		module.local_box_transform=Transform3D(Basis.IDENTITY,Vector3(spec[2],1,-2))
		module.size_m=Vector3(0.4,0.4,0.4)
		module.geometry_status="estimated"; module.evidence_keys=PackedStringArray(["TEST ONLY: isolated axis damage fixture"])
		layout.modules.append(module)
	for side in [-1,1]:
		var track := ModuleVolumeDefinition.new()
		track.id="track_left" if side<0 else "track_right"
		track.kind="track"; track.part_id="hull"; track.external=true
		track.local_box_transform=Transform3D(Basis.IDENTITY,Vector3(side*1.25,0.3,0))
		track.size_m=Vector3(0.55,0.6,3.9); track.geometry_status="estimated"
		layout.modules.append(track)
	TrackAssembly.bind_layout(layout)
	return layout

func setup_world() -> bool:
	InputBindingService.initialize()
	InputBindingService.set_context("recovery")
	for action in InputBindingService.ACTIONS:
		if not InputMap.has_action(action): return false
	release_inputs()
	world=Node3D.new(); root.add_child(world)
	TerrainFixtures.box(world,Vector3(0,-0.5,0),Vector3(400,1,400))
	VehicleSimulationDriver.for_scene(world)
	projectiles=ProjectileManager.new(); projectiles.presentation_enabled=false; world.add_child(projectiles)
	projectiles.snapshot_provider=query_snapshots
	projectiles.exclude_provider=exclude_rids
	projectiles.damage_handler=apply_damage
	var defs := VehicleDefs.new()
	if not defs.load_defaults().ok: return false
	for index in MODES.size():
		var definition := defs.get_vehicle("player_tank").duplicate(true) as VehicleDefinition
		definition.id="test_mechanism_"+MODES[index]
		definition.forward_max_speed=4.0; definition.hull_turn_speed=20.0
		definition.drive_profile.suspension_enabled=true
		definition.turret_yaw_speed=120.0; definition.turret_pitch_speed=90.0
		definition.barrel_pitch_min=-35.0; definition.barrel_pitch_max=45.0
		var profile := FireControlProfile.new()
		profile.stabilizer_mode=MODES[index]
		profile.pitch_accel_deg_s2=720.0; profile.yaw_accel_deg_s2=720.0
		profile.pitch_brake_deg_s2=1080.0; profile.yaw_brake_deg_s2=1080.0
		profile.speed_limit_mps=6.0; profile.speed_hysteresis_mps=0.5
		definition.fire_control_profile=profile
		defs.vehicles[definition.id]=definition
		var actor := VehicleActor.new(); actor.presentation_enabled=false; world.add_child(actor)
		var player := PlayerController.new(); world.add_child(player)
		var origin := Vector3((index-1)*30,0,8)
		if not actor.setup(defs,definition.id,MODES[index],index+1,Transform3D(Basis.IDENTITY,origin),4,player).ok: return false
		var layout := axis_layout()
		actor.set_damage_layout(layout)
		TrackAssembly.install(actor,layout)
		actor.gunner.projectile_manager=projectiles
		actor.gunner.snapshot_provider=query_snapshots
		actor.gunner.round_provider=func() -> int: return 1
		actor.cam_rig.set_aim(0.35,0.04)
		actors.append(actor)
		TerrainFixtures.ramp(world,Vector3(origin.x,0,0),5.0,14.0,30.0)
	probe=AuthorityProbe.new(); probe.actors=actors; probe.projectiles=projectiles; world.add_child(probe)
	return true

func query_snapshots() -> Array:
	var result: Array=[]
	for actor in actors: result.append(QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override))
	return result
func exclude_rids(entity: String, life: int) -> Array[RID]:
	for actor in actors:
		if actor.entity_id==entity and actor.life_id==life: return [actor.tank.get_rid()]
	return []
func apply_damage(event: Dictionary, available_mm: float) -> Dictionary:
	for actor in actors:
		if event.get("entity_id","")==actor.entity_id: return actor.apply_projectile_damage(event,available_mm)
	return {"ok":false,"reason":"missing_target"}

func metrics(entity: String, phase: String) -> Dictionary:
	var out := {"samples":0,"pitch":0.0,"yaw":0.0,"hull_pitch":0.0,"spring_pitch":0.0,"compensation":0.0,"valid":true}
	for row in probe.rows:
		if row.entity!=entity or row.phase!=phase: continue
		out.samples+=1; out.pitch+=row.pitch_error; out.yaw+=row.yaw_error
		out.hull_pitch=maxf(out.hull_pitch,absf(row.hull_pitch)); out.spring_pitch=maxf(out.spring_pitch,absf(row.spring_pitch))
		out.compensation=maxf(out.compensation,(row.compensation as Vector2).length())
		out.valid=out.valid and row.valid
	if out.samples>0: out.pitch/=out.samples; out.yaw/=out.samples
	return out

func driving_and_shots() -> void:
	Input.action_press("aim")
	await ticks(180)
	check(actors.all(func(actor: VehicleActor) -> bool: return actor.tank.is_on_floor() and actor.tank.suspension.initialized and actor.controller is PlayerController),"all identical test vehicles settle on real track probes under actual PlayerController polling")
	check(actors.all(func(actor: VehicleActor) -> bool: return actor.definition.content_tier=="test" and actor.definition.fire_control_profile.provenance=="game_rule"),"stabilizer comparison uses declared game rules without binding historical vehicles")
	probe.phase="ramp"
	Input.action_press("move_forward")
	await ticks(280)
	probe.phase="turn"
	Input.action_press("turn_left")
	await ticks(120)
	var ramp: Array[Dictionary]=[]
	var turn: Array[Dictionary]=[]
	for actor in actors:
		ramp.append(metrics(actor.entity_id,"ramp")); turn.append(metrics(actor.entity_id,"turn"))
		print("[ROUTE] ",actor.entity_id," position=",actor.tank.position," ramp=",ramp.back()," turn=",turn.back())
		check(actor.tank.position.length()>12 and ramp.back().hull_pitch>0.025 and ramp.back().spring_pitch>0.001 and ramp.back().valid and turn.back().valid,"real driving ramp excites sprung hull and retains valid authoritative poses: "+actor.entity_id)
	check(ramp[0].samples>200 and ramp[0].pitch>0.0001 and ramp[1].pitch<ramp[0].pitch*0.85 and ramp[2].pitch<ramp[0].pitch*0.85,"vertical and two-axis profiles reduce measured pitch error on the same actual ramp route")
	check(turn[0].yaw>0.005 and turn[1].yaw>turn[0].yaw*0.7 and turn[2].yaw<turn[0].yaw*0.5,"single-axis mode retains horizontal lag while two-axis mode reduces it during real steering")
	check(ramp[0].compensation==0.0 and turn[0].compensation==0.0,"unstabilized production rig has no hull disturbance feed-forward throughout driving")
	await tap("fire")
	for actor in actors:
		var shot: Dictionary=probe.shots.get(actor.gunner.last_projectile_id,{})
		check(actor.gunner.shots_fired==1 and not shot.is_empty(),"normal fire input launches exactly one actual projectile while driving: "+actor.entity_id)
		if shot.is_empty(): continue
		var launch: Vector3=(shot.velocity-shot.vehicle_velocity)/shot.muzzle_speed
		check(shot.tick==shot.born_tick and launch.distance_to(shot.barrel)<0.00001 and shot.origin.distance_to(shot.muzzle)<0.00001,"same-tick projectile launch uses physical muzzle and barrel plus vehicle velocity: "+actor.entity_id)
		if actor.entity_id=="none":
			check((shot.barrel as Vector3).angle_to(shot.target)>0.005,"shot preserves unstabilized barrel lag instead of snapping the projectile to optical aim")
	probe.phase=""
	release_inputs()
	await ticks(120)
	projectiles.cancel_all("cancelled_reset")
	for actor in actors: actor.reset_vehicle()
	await ticks(180)

func penetrate_axis(actor: VehicleActor, id: String, x: float) -> void:
	damage_shot+=1
	var hull := actor.tank.hull_frame.global_transform
	var result := projectiles.try_spawn({"round_id":1,"shooter_id":"test_axis_attacker","shooter_life_id":99,
		"shot_id":damage_shot,"shell_id":"test_axis_ap","armor_policy":"resolve",
		"penetration_curve":PackedVector2Array([Vector2(0,120)]),"position_world":hull*Vector3(x,1,2),
		"velocity_world":hull.basis*Vector3(0,0,-600),"gravity_world":Vector3.ZERO,"max_age_s":1.0,"max_distance_m":100.0})
	check(result.get("ok",false),"manager admits the declared physical module path: "+id)
	if not result.get("ok",false): return
	var projectile := projectiles.get_projectile_state(result.projectile_id)
	await ticks(5)
	print("[AXIS HIT] ",id," contacts=",projectile.contacts.size()," damage=",projectile.damage_records)
	check(projectile.contacts.size()==1 and projectile.damage_records.size()==1 and actor.state.module_states[id].integrity==0,"actual plate penetration destroys exactly the intended axis module: "+id)
	for other in ["horizontal","vertical","stabilizer"]:
		if other!=id: check(actor.state.module_states[other].integrity==100,"isolated "+id+" shot preserves "+other)
	var labels := {"horizontal":"水平炮塔驱动损毁","vertical":"火炮俯仰驱动损毁","stabilizer":"稳定器损毁"}
	var model := HUDPresenter.present(actor,{})
	var correct_reason: bool=model.weapon_text.contains(labels[id]) and model.ready
	for other in labels:
		if other!=id: correct_reason=correct_reason and not model.weapon_text.contains(labels[other])
	check(correct_reason,"HUD identifies the destroyed mechanism by module kind while the intact gun remains ready: "+id)
	projectiles.cancel_all("cancelled_reset")

func damage_repair_pause() -> void:
	var actor := actors[2]
	await penetrate_axis(actor,"horizontal",-1.0)
	var yaw := actor.turret.rotation.y
	var pitch := actor.turret.barrel_pivot.rotation.x
	actor.cam_rig.set_aim(0.8,0.2)
	await ticks(90)
	check(absf(actor.turret.rotation.y-yaw)<0.00001 and absf(actor.turret.barrel_pivot.rotation.x-pitch)>0.03 and actor.turret.mechanism.stabilized_axes==Vector2i(1,0),"horizontal drive destruction freezes only real turret traverse while elevation still responds")
	await tap("repair")
	await ticks(60)
	check(actor.state.recovery_action=="repair" and actor.state.action_target=="horizontal","normal repair input starts the damaged horizontal mechanism through production recovery")
	var progress := actor.state.action_progress
	var pose := VehicleFramePose.capture(actor.tank)
	var mechanism_velocity := actor.turret.mechanism.velocity
	var angles := Vector2(actor.turret.barrel_pivot.rotation.x,actor.turret.rotation.y)
	var ammo := actor.gunner.rounds_remaining
	var shot_count := actor.gunner.shots_fired
	var shot_id := actor.gunner.shot_id
	var projectile_id := actor.gunner.last_projectile_id
	var spring := actor.tank.suspension.snapshot()
	paused=true
	for i in 6: await process_frame
	var fire := VehicleCommand.new(); fire.fire_requested=true
	check(not actor.submit_command(fire) and actor.state.action_progress==progress and actor.gunner.rounds_remaining==ammo and VehicleFramePose.capture(actor.tank)==pose and actor.tank.suspension.snapshot()==spring and actor.turret.mechanism.velocity==mechanism_velocity and Vector2(actor.turret.barrel_pivot.rotation.x,actor.turret.rotation.y)==angles,"pause freezes mechanism, suspension and repair clock and rejects queued firing")
	paused=false
	await ticks(ceili(RecoveryRules.REPAIR_SECONDS/DT)-60)
	check(actor.state.recovery_action.is_empty() and actor.state.module_states.horizontal.integrity==50 and actor.capabilities().yaw_scale==0.5 and actor.capabilities().pitch_scale==1.0,"natural repair restores the damaged drive to the configured half-strength threshold only")
	check(not HUDPresenter.present(actor,{}).weapon_text.contains("水平炮塔驱动损毁"),"HUD removes the horizontal-drive failure when actual repair restores function")
	# Gunner counters deliberately survive reset; compare with the pause boundary,
	# including projectile identity, instead of assuming this is its first shot.
	print("[PAUSE SHOTS] before=",[ammo,shot_count,shot_id,projectile_id]," after=",[actor.gunner.rounds_remaining,actor.gunner.shots_fired,actor.gunner.shot_id,actor.gunner.last_projectile_id])
	check(actor.gunner.rounds_remaining==ammo and actor.gunner.shots_fired==shot_count and actor.gunner.shot_id==shot_id and actor.gunner.last_projectile_id==projectile_id,"resuming repair does not replay the rejected paused fire request")
	actor.cam_rig.set_aim(-0.8,0.2)
	await ticks(60)
	check(absf(actor.turret.rotation.y-yaw)>0.05 and absf(actor.turret.mechanism.velocity.y)<=deg_to_rad(actor.definition.turret_yaw_speed)*0.5+0.00001,"repaired traverse resumes actual movement within its degraded maximum rate")
	actor.reset_vehicle()
	check(actor.turret.mechanism.velocity==Vector2.ZERO and not actor.turret.mechanism._pose_valid and actor.state.module_states.horizontal.integrity==100,"new life clears mechanism motion/history and repairs the fixture state")
	await ticks(180)
	await penetrate_axis(actor,"vertical",0.0)
	yaw=actor.turret.rotation.y; pitch=actor.turret.barrel_pivot.rotation.x
	actor.cam_rig.set_aim(-0.8,0.2)
	await ticks(90)
	check(absf(actor.turret.barrel_pivot.rotation.x-pitch)<0.00001 and absf(actor.turret.rotation.y-yaw)>0.1 and actor.turret.mechanism.stabilized_axes==Vector2i(0,1),"vertical drive destruction freezes physical elevation while traverse and its stabilization remain available")
	actor.reset_vehicle()
	await ticks(180)
	await penetrate_axis(actor,"stabilizer",1.0)
	yaw=actor.turret.rotation.y; pitch=actor.turret.barrel_pivot.rotation.x
	actor.cam_rig.set_aim(0.8,0.2)
	await ticks(60)
	check(not actor.turret.mechanism.stabilizer_active and actor.turret.mechanism.compensation_rate==Vector2.ZERO and absf(actor.turret.rotation.y-yaw)>0.1 and absf(actor.turret.barrel_pivot.rotation.x-pitch)>0.03,"destroyed stabilizer removes disturbance compensation while both physical gunner drives still work")

func run() -> void:
	var ready_ok := setup_world()
	check(ready_ok,"construct real authority scene with three isolated gameplay profiles")
	if ready_ok:
		await driving_and_shots()
		await damage_repair_pause()
	release_inputs(); paused=false
	if world!=null: world.free()
	await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("TURRET_MECHANISM_PLAYER_CHECKS_PASS" if failures==0 else "TURRET_MECHANISM_PLAYER_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
