extends SceneTree
## Actual AI -> shared Actor phases -> Gunner -> ProjectileManager -> armor.
## TEST ONLY: drive phase supplies constant translation, isolating interception
## from acceleration/steering. This is not drivetrain or historical validation.

class ConstantMotionActor extends VehicleActor:
	var motion := Vector3.ZERO
	var load_events: Array[Dictionary]=[]
	func advance_simulation_drive(step: Dictionary, delta: float) -> void:
		if not simulation_step_valid(step): return
		tank.global_position+=motion*delta
		tank.velocity=motion
		tank.forward_speed=motion.dot(-tank.global_basis.z)
	func advance_simulation_loading(step: Dictionary, delta: float) -> void:
		var before := gunner.inventory.chamber
		super.advance_simulation_loading(step,delta)
		if before==0 and gunner.inventory.chamber>0:
			load_events.append({"tick":Engine.get_physics_frames(),"shell":gunner.shell.id,"fire_requested":step.cmd.fire_requested,"shots":gunner.shots_fired})

class FireVetoProbe extends Node:
	var cam_rig: CameraRig
	var gunner: Gunner
	var vehicle: VehicleActor
	var issue := true
	var allow := false
	var invalidate_epoch := false
	var calls := 0
	var poll_muzzle := Vector3.ZERO
	var authorization_muzzle := Vector3.ZERO
	var authorization_velocity := Vector3.ZERO
	func is_local_controller() -> bool: return false
	func poll() -> VehicleCommand:
		var cmd := VehicleCommand.new()
		cmd.hold_aim=true
		if issue:
			issue=false
			poll_muzzle=vehicle.turret.muzzle.global_position
			cmd.fire_requested=true
		return cmd
	func authorize_fire(_cmd: VehicleCommand) -> bool:
		calls+=1
		authorization_muzzle=vehicle.turret.muzzle.global_position
		authorization_velocity=vehicle.tank.velocity
		if invalidate_epoch: vehicle.invalidate_input_epoch()
		return allow

var checks := 0
var failures := 0
var world: Node3D
var defs: VehicleDefs
var shooter: ConstantMotionActor
var target: ConstantMotionActor
var actors: Array[VehicleActor]=[]
var ai: AITankController
var manager: ProjectileManager
var contacts: Array[Dictionary]=[]
var terminals: Array[Dictionary]=[]

func _initialize() -> void:
	create_timer(180).timeout.connect(func() -> void: print("AI_INTERCEPT_WATCHDOG"); quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)

func frames(count: int) -> void:
	for _i in count: await physics_frame
	await process_frame

func ammunition(speed: float, gravity: float = 1.0, lifetime: float = 20.0) -> ShellDefinition:
	var value := ShellDefinition.new()
	value.id="test_ai_intercept_"+str(speed)
	value.muzzle_velocity_mps=speed
	value.gravity_scale=gravity
	value.max_flight_time_s=lifetime
	value.penetration_curve=PackedVector2Array([Vector2(0,5),Vector2(2000,5)])
	value.source_refs=["TEST ONLY explicit constant-velocity interception fixture"]
	return value

func spawn_actor(entity: String, team: int, position: Vector3, yaw: float = 0.0) -> ConstantMotionActor:
	var vehicle := ConstantMotionActor.new()
	vehicle.presentation_enabled=false
	world.add_child(vehicle)
	var setup := vehicle.setup(defs,"player_tank",entity,team,Transform3D(Basis(Vector3.UP,yaw),position),GameConfig.VIS_LAYER_VEHICLE,null)
	check(setup.ok,"actual Actor.setup loads "+entity)
	if not setup.ok:
		vehicle.free()
		return null
	vehicle.set_damage_layout(DamageTrainingLayout.build(false))
	M4EngineeringProfile.apply(vehicle)
	vehicle.gunner.aim_preview_enabled=false
	actors.append(vehicle)
	return vehicle

func build_case(own_velocity: Vector3, target_velocity: Vector3, target_point: Vector3, speed: float = 65.0, gravity: float = 1.0) -> bool:
	contacts.clear(); terminals.clear(); actors.clear()
	world=Node3D.new(); root.add_child(world)
	VehicleSimulationDriver.for_scene(world)
	TerrainFixtures.box(world,Vector3(0,-0.5,-150),Vector3(700,1,600))
	defs=VehicleDefs.new()
	var loaded := defs.load_defaults()
	check(loaded.ok,"AI interception fixture loads production definitions")
	if not loaded.ok: return false
	shooter=spawn_actor("A",1,Vector3(0,0.03,0))
	target=spawn_actor("B",2,target_point,PI)
	if shooter==null or target==null: return false
	shooter.motion=own_velocity; shooter.tank.velocity=own_velocity
	target.motion=target_velocity; target.tank.velocity=target_velocity
	shooter.weapon=shooter.weapon.duplicate(true)
	shooter.weapon.gun_range=1000.0
	shooter.gunner.weapon=shooter.weapon
	var fixture_shell := ammunition(speed,gravity)
	check(fixture_shell!=null and fixture_shell.validate().ok,"TEST ONLY interception shell passes the actual flight-definition validator")
	if fixture_shell==null or not fixture_shell.validate().ok: return false
	shooter.gunner.shell=fixture_shell
	shooter.gunner.cooldown_left=100.0
	manager=ProjectileManager.new(); manager.presentation_enabled=false; world.add_child(manager)
	manager.snapshot_provider=func() -> Array:
		var snapshots: Array=[]
		for vehicle in actors: snapshots.append(QuerySnapshotBuilder.build_from_vehicle(vehicle.tank,vehicle.damage_layout_override))
		return snapshots
	manager.exclude_provider=func(_entity: String, _life: int) -> Array[RID]:
		var excluded: Array[RID]=[shooter.tank.get_rid()]
		return excluded
	manager.damage_handler=func(event: Dictionary, budget: float) -> Dictionary:
		for vehicle in actors:
			if vehicle.entity_id==event.get("entity_id",""): return vehicle.apply_projectile_damage(event,budget)
		return {"ok":false,"reason":"missing_actor"}
	manager.projectile_contact.connect(func(event: Dictionary) -> void: contacts.append(event.duplicate(true)))
	manager.projectile_finished.connect(func(event: Dictionary) -> void: terminals.append(event.duplicate(true)))
	shooter.gunner.projectile_manager=manager
	shooter.gunner.round_provider=func() -> int: return 71010
	ai=AITankController.new(); world.add_child(ai)
	ai.configure(shooter,DriveNavigator.new(),func() -> Array: return actors,"hard",71010)
	ai.difficulty.error_degrees=0.0 # Deterministic aim skill only; no vehicle rule is upgraded.
	shooter.set_controller(ai)
	await frames(4)
	check(shooter.simulation_driver.get_ref()==target.simulation_driver.get_ref(),"real actors share the production simulation driver")
	return true

func dispose_case() -> void:
	if is_instance_valid(world): world.free()
	actors.clear()
	await frames(2)

func run() -> void:
	await moving_shot("moving target, longer than two seconds",Vector3.ZERO,Vector3(10,0,0),Vector3(-35,0.03,-140),true)
	await moving_shot("moving shooter and target",Vector3(7,0,0),Vector3(-3,0,0),Vector3(15,0.03,-130),false)
	if "--moving-only" in OS.get_cmdline_user_args():
		print("AI_INTERCEPT_MOVING_DIAGNOSTIC checks=%d failures=%d"%[checks,failures])
		quit(0 if failures==0 else 1)
		return
	await blockers_and_readonly()
	await rejected_and_cadence()
	await fire_authorization_order()
	await newly_loaded_shell()
	await automatic_loading_recovery()
	check_age_and_compatibility()
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("AI_INTERCEPT_CHECKS_PASS" if failures==0 else "AI_INTERCEPT_CHECKS_FAIL")
	quit(0 if failures==0 else 1)

func moving_shot(label: String, own: Vector3, motion: Vector3, position: Vector3, require_long: bool) -> void:
	if not await build_case(own,motion,position): await dispose_case(); return
	var initial_target := target.tank.global_position
	var initial_shooter := shooter.tank.global_position
	var initial_ammo := shooter.gunner.rounds_remaining
	shooter.gunner.cooldown_left=0.0
	var minimum_tracking_error := INF
	var tracking_error_sum := 0.0
	var tracking_samples := 0
	var finite_axis_motion := true
	var previous_axes := Vector2(shooter.turret.barrel_pivot.rotation.x,shooter.turret.rotation.y)
	for _tick in 300:
		await physics_frame
		var current_axes := Vector2(shooter.turret.barrel_pivot.rotation.x,shooter.turret.rotation.y)
		var axis_step := Vector2(absf(current_axes.x-previous_axes.x),absf(wrapf(current_axes.y-previous_axes.y,-PI,PI)))
		finite_axis_motion=finite_axis_motion and axis_step.x<=deg_to_rad(shooter.definition.turret_pitch_speed)/Engine.physics_ticks_per_second+0.00001 and axis_step.y<=deg_to_rad(shooter.definition.turret_yaw_speed)/Engine.physics_ticks_per_second+0.00001
		previous_axes=current_axes
		if _tick>=60 and ai.last_aim_solution.get("ok",false):
			var error := rad_to_deg(shooter.turret.barrel_direction().angle_to(ai.last_aim_solution.direction))
			minimum_tracking_error=minf(minimum_tracking_error,error)
			tracking_error_sum+=error
			tracking_samples+=1
		if shooter.gunner.shots_fired>0: break
	var launched := manager.get_projectile_state(shooter.gunner.last_projectile_id)
	var solution := ai.last_aim_solution.duplicate(true)
	var lane := ai.sensor.last_lane_result.duplicate(true)
	var observed_velocity: Vector3=ai.observation.get("velocity",Vector3.INF)
	print("[DETAIL] ",label," solution=",solution," lane=",lane," gun=",shooter.gunner.blocked_reason)
	print("[TRACKING] ",label," phase=",ai.phase," chamber=",shooter.gunner.inventory.chamber," cooldown=",shooter.gunner.cooldown_left," grace=",shooter.gunner.resume_grace," authorization=",ai.last_fire_authorization," min_error_deg=",minimum_tracking_error," mean_error_deg=",tracking_error_sum/maxi(1,tracking_samples)," actual_axis_rate=",shooter.turret.mechanism.velocity," command_error_deg=",shooter.turret.alignment_error_deg())
	check(shooter.gunner.shots_fired==1 and launched!=null,label+": finite mechanism and observed motion produce one real projectile")
	check(finite_axis_motion,label+": response compensation never jumps past the actual per-axis rotation limits")
	check(observed_velocity.distance_to(motion)<0.01,label+": lead uses velocity estimated by actual visible samples")
	var expected_age := ai.clock-float(ai.observation.get("last_seen",-INF))+1.0/Engine.physics_ticks_per_second
	check(solution.get("ok",false) and absf(float(solution.get("observation_age_s",-1))-expected_age)<1.0e-7,label+": fire authorization ages the observation through the completed drive step")
	if solution.get("ok",false) and motion!=Vector3.ZERO:
		var old_phase_point: Vector3=ai.observation.aim_point+observed_velocity*(ai.clock-float(ai.observation.last_seen))
		check(solution.target_point_now.distance_to(old_phase_point)>0.02,label+": post-drive interception does not reuse the pre-drive observed target position")
	check(lane.get("ok",false) and lane.get("reason","")=="predicted_target_contact" and int(lane.get("segments",9999))<=AIPerception.MAX_PREDICTION_SEGMENTS,label+": bounded geometry preview permits the actual shot")
	if launched!=null:
		check(absf((launched.launch_velocity-own).length()-65.0)<0.001,label+": real launch adds own world velocity exactly once")
		var direct := ai.sensor.contact(shooter,shooter.turret.muzzle.global_position,shooter.turret.muzzle.global_position+shooter.turret.barrel_direction()*180)
		check(direct.status!="vehicle" or direct.event.entity_id!="B",label+": correct lead is allowed even though current straight ray misses current target")
	if require_long: check(solution.get("time_s",0.0)>2.0,label+": intercept retains flight time beyond former two-second cap")
	shooter.set_controller(null) # The actual first round continues; no second request.
	for _tick in 360:
		await physics_frame
		if not terminals.is_empty(): break
	check(not contacts.is_empty() and contacts[0].get("entity_id","")=="B",label+": actual moving authority geometry receives the flown shell")
	check(terminals.size()==1 and terminals[0].get("target_id","")=="B",label+": actual projectile terminates on the intended enemy")
	if require_long: check(not contacts.is_empty() and contacts[0].flight_time_s>2.0,label+": measured production flight exceeds two seconds")
	check(target.tank.global_position.distance_to(initial_target)>1.0,label+": target actually changes world position during the shot")
	if own!=Vector3.ZERO: check(shooter.tank.global_position.distance_to(initial_shooter)>1.0,label+": muzzle carrier actually moves during flight")
	check(shooter.gunner.rounds_remaining==initial_ammo-1 and shooter.gunner.inventory.conserved(),label+": real inventory debits one round and remains conserved")
	await dispose_case()

func prepare_stationary_lane() -> Dictionary:
	await frames(75) # AI pursues with finite slew while the real reload gate stays closed.
	check(shooter.gunner.shots_fired==0 and ai.sensor.lane_queries==0,"unready weapon never performs full future geometry queries")
	var observation := ai.observation.duplicate(true)
	var solution := ai.last_aim_solution.duplicate(true)
	check(observation.get("visible",false) and solution.get("ok",false),"real perception and finite mechanism prepare an observable shot")
	return {"observation":observation,"solution":solution}

func blockers_and_readonly() -> void:
	if not await build_case(Vector3.ZERO,Vector3.ZERO,Vector3(0,0.03,-120),65.0,0.0): await dispose_case(); return
	var prepared := await prepare_stationary_lane()
	var step := 1.0/Engine.physics_ticks_per_second
	check(ai._tracking_direction(shooter,prepared.solution,step).is_equal_approx(prepared.solution.direction),"stationary shooter and target receive no artificial mechanism motion lead")
	var moving_sample: Dictionary=prepared.observation.duplicate(true)
	moving_sample.velocity=Vector3(10,0,0)
	var moving_solution := AimSolver.solve_intercept(shooter.turret.muzzle.global_position,moving_sample,shooter.gunner.shell,Vector3.ZERO,Vector2.ZERO)
	ai._tracking_direction(shooter,moving_solution,step)
	var reacquired_sample: Dictionary=prepared.observation.duplicate(true)
	reacquired_sample.aim_point+=Vector3(20,0,0)
	reacquired_sample.velocity=Vector3.ZERO
	var reacquired := AimSolver.solve_intercept(shooter.turret.muzzle.global_position,reacquired_sample,shooter.gunner.shell,Vector3.ZERO,Vector2.ZERO)
	check(reacquired.ok and ai._tracking_direction(shooter,reacquired,step).is_equal_approx(reacquired.direction),"a discontinuous newly observed stationary aim point cannot inherit a fictitious rate from the previous moving solution")
	var before_damage := target.state.damage_snapshot()
	var before_ammo := shooter.gunner.inventory.snapshot()
	check(ai.sensor.fire_lane_clear(shooter,prepared.observation,prepared.solution),"clear curved-path permission finds actual enemy exterior geometry")
	check(target.state.damage_snapshot()==before_damage and shooter.gunner.inventory.snapshot()==before_ammo and shooter.gunner.shots_fired==0 and manager.active_count()==0,"trajectory permission is read-only and cannot manufacture a hit or launch")
	var future := BallisticMath.advance_free(shooter.turret.muzzle.global_position,shooter.turret.barrel_direction()*65,Vector3.ZERO,0.6)
	var wall := TerrainFixtures.box(world,future.position,Vector3(6,6,1))
	await frames(2)
	check(not ai.sensor.fire_lane_clear(shooter,prepared.observation,prepared.solution) and ai.sensor.last_lane_result.reason=="world_blocked","new world wall on actual predicted flight blocks stale-visible target permission")
	shooter.gunner.cooldown_left=0
	await frames(30)
	check(shooter.gunner.shots_fired==0 and manager.active_count()==0,"wall-blocked actual AI never emits a projectile")
	shooter.gunner.cooldown_left=100
	wall.free(); await frames(10)
	prepared.observation=ai.observation.duplicate(true); prepared.solution=ai.last_aim_solution.duplicate(true)
	var friend := spawn_actor("C",1,Vector3(0,0.03,-55))
	await frames(2)
	check(friend!=null and not ai.sensor.fire_lane_clear(shooter,prepared.observation,prepared.solution) and ai.sensor.last_lane_result.reason=="other_vehicle_first","actual friendly vehicle before target denies firing permission")
	shooter.gunner.cooldown_left=0
	await frames(25)
	check(shooter.gunner.shots_fired==0,"friendly obstruction cannot generate an actual AI shot")
	shooter.gunner.cooldown_left=100
	actors.erase(friend); friend.free(); await frames(10)
	prepared.observation=ai.observation.duplicate(true); prepared.solution=ai.last_aim_solution.duplicate(true)
	wall=TerrainFixtures.box(world,shooter.turret.barrel_pivot.global_position.lerp(shooter.turret.muzzle.global_position,0.5),Vector3(2,2,0.3))
	await frames(2)
	check(not ai.sensor.fire_lane_clear(shooter,prepared.observation,prepared.solution) and ai.sensor.last_lane_result.reason=="barrel_occluded","fresh barrel-root to muzzle check rejects a wall behind the muzzle")
	wall.free(); await frames(2)
	target.state.generation+=1; target.tank.state_generation=target.state.generation
	check(not ai.sensor.fire_lane_clear(shooter,prepared.observation,prepared.solution),"a target generation change invalidates its old observed identity")
	await dispose_case()

func rejected_and_cadence() -> void:
	if not await build_case(Vector3.ZERO,Vector3.ZERO,Vector3(0,0.03,-140),10.0,1.0): await dispose_case(); return
	shooter.gunner.cooldown_left=0
	await frames(80)
	check(not ai.last_aim_solution.get("ok",true) and ai.sensor.lane_queries==0 and shooter.gunner.shots_fired==0,"unreachable ballistic target generates neither permission queries nor actual shots")
	await dispose_case()
	if not await build_case(Vector3.ZERO,Vector3.ZERO,Vector3(0,0.03,-120),65.0,0.0): await dispose_case(); return
	var prepared := await prepare_stationary_lane()
	shooter.weapon.gun_range=40
	shooter.gunner.cooldown_left=0
	var before := ai.sensor.lane_queries
	await frames(60)
	var queries := ai.sensor.lane_queries-before
	check(queries>=2 and queries<=10,"ready aligned AI runs bounded permission only on its 0.12 s decision cadence")
	check(ai.sensor.last_lane_result.get("reason","")=="weapon_range_exceeded" and shooter.gunner.shots_fired==0,"weapon cumulative-flight budget rejects the otherwise solvable target")
	shooter.gunner.cooldown_left=100
	shooter.weapon.gun_range=1000
	shooter.gunner.shell=ammunition(5,0,30)
	await frames(10)
	prepared.observation=ai.observation.duplicate(true)
	prepared.solution=AimSolver.solve_intercept(shooter.turret.muzzle.global_position,prepared.observation,shooter.gunner.shell,Vector3.ZERO,Vector2.ZERO)
	check(prepared.solution.ok and not ai.sensor.fire_lane_clear(shooter,prepared.observation,prepared.solution) and ai.sensor.last_lane_result.reason=="prediction_segment_budget" and ai.sensor.last_lane_result.segments==AIPerception.MAX_PREDICTION_SEGMENTS,"mathematically reachable long path stops at the explicit geometry-segment budget")
	check(shooter.gunner.shots_fired==0 and manager.active_count()==0,"budget exhaustion never falls back to firing")
	await dispose_case()

func check_age_and_compatibility() -> void:
	var sample := {"aim_point":Vector3(0,2,-100),"velocity":Vector3(10,0,0)}
	var value := ammunition(65,0)
	var aged := AimSolver.solve_intercept(Vector3(0,2,0),sample,value,Vector3.ZERO,Vector2.ZERO,0.25)
	check(aged.ok and aged.target_point_now==Vector3(2.5,2,-100),"aim solver accounts for observation age before solving future interception")
	var expected := BallisticIntercept.solve(Vector3(0,2,0),Vector3(2.5,2,-100),Vector3(10,0,0),Vector3.ZERO,value)
	check(expected.ok and aged.ok and aged.ideal_direction.is_equal_approx(expected.direction),"aged observation uses the shared production intercept mathematics")
	check(not AimSolver.solve_intercept(Vector3.ZERO,sample,value,Vector3.ZERO,Vector2.ZERO,0.601).ok,"observation older than the supported motion sample window is rejected")
	check(not AimSolver.solve_intercept(Vector3.ZERO,sample,value,Vector3.ZERO,Vector2.ZERO,-0.01).ok,"future-dated observation is rejected")
	check(AimSolver.solve(Vector3.ZERO,sample,value,Vector3.ZERO,Vector2.ZERO).is_finite(),"existing scripted training callers retain a finite compatible aim point")
	check(not AimSolver.solve(Vector3.ZERO,sample,ammunition(1,1),Vector3.ZERO,Vector2.ZERO).is_finite(),"unreachable compatibility call cannot manufacture a valid fallback aim point")

func fire_authorization_order() -> void:
	if not await build_case(Vector3.ZERO,Vector3.ZERO,Vector3(0,0.03,-120),65,0): await dispose_case(); return
	shooter.set_controller(null)
	shooter.motion=Vector3(6,0,0)
	shooter.tank.velocity=Vector3.ZERO
	shooter.gunner.cooldown_left=0
	var before := shooter.gunner.rounds_remaining
	var probe := FireVetoProbe.new(); probe.vehicle=shooter; world.add_child(probe)
	shooter.set_controller(probe)
	await frames(3)
	check(probe.calls==1 and probe.authorization_velocity==Vector3(6,0,0) and probe.authorization_muzzle.distance_to(probe.poll_muzzle+Vector3(6.0/Engine.physics_ticks_per_second,0,0))<0.001,"Actor fire authorization runs once after actual drive moved the muzzle and set inherited velocity")
	check(shooter.gunner.shots_fired==0 and shooter.gunner.rounds_remaining==before and manager.active_count()==0,"false controller authorization cannot consume ammunition or create a projectile")
	probe.issue=true; probe.allow=true; probe.invalidate_epoch=true
	var epoch := shooter.control_epoch
	await frames(3)
	check(shooter.control_epoch==epoch+1 and probe.calls==2 and shooter.gunner.shots_fired==0 and shooter.gunner.rounds_remaining==before,"authorization callback invalidating control epoch cannot fire from the stale simulation step")
	probe.issue=true; probe.invalidate_epoch=false
	await frames(3)
	check(probe.calls==3 and shooter.gunner.shots_fired==1 and shooter.gunner.rounds_remaining==before-1,"valid current-epoch authorization reaches the same actual Gunner launch")
	await dispose_case()

func newly_loaded_shell() -> void:
	if not await build_case(Vector3.ZERO,Vector3.ZERO,Vector3(0,0.03,-100),65,0): await dispose_case(); return
	var first := ammunition(65,0)
	var second := ammunition(130,0)
	var options: Array[ShellDefinition]=[first,second]
	check(shooter.gunner.configure_shell_loadout(options,{first.id:1,second.id:3},first.id),"natural loading test installs two real shell definitions")
	shooter.gunner.cooldown_left=0
	shooter.gunner.select_shell(1)
	check(shooter.gunner.request_fire(),"first chambered shell launches normally before the AI reload boundary")
	manager.cancel_all("test_first_shell_recorded")
	contacts.clear(); terminals.clear()
	for _tick in 240:
		await physics_frame
		if not shooter.load_events.is_empty(): break
	check(not shooter.load_events.is_empty() and shooter.load_events[0].shell==second.id and not shooter.load_events[0].fire_requested and shooter.load_events[0].shots==1,"AI poll before loading cannot request fire with the old shell on the exact tick the new shell is chambered")
	for _tick in 180:
		await physics_frame
		if shooter.gunner.shots_fired>1: break
	var launched := manager.get_projectile_state(shooter.gunner.last_projectile_id)
	check(shooter.gunner.shots_fired==2 and launched!=null and launched.shell_id==second.id and absf(launched.launch_velocity.length()-130.0)<0.001 and ai.last_aim_solution.get("shell_id","")==second.id,"next ready AI solution and actual launch both use the newly chambered shell")
	await dispose_case()

func automatic_loading_recovery() -> void:
	if not await build_case(Vector3.ZERO,Vector3.ZERO,Vector3(0,0.03,-80),65,0): await dispose_case(); return
	var layout: VehicleLayoutDefinition=shooter.damage_layout_override.duplicate(true)
	layout.recovery_enabled=true
	var mechanism := ModuleVolumeDefinition.new()
	mechanism.id="fixture_loading_mechanism"; mechanism.kind="autoloader"; mechanism.part_id="hull"
	mechanism.local_box_transform.origin=Vector3(0,1.2,0); mechanism.size_m=Vector3(0.2,0.2,0.2)
	mechanism.geometry_status="estimated"
	layout.modules.append(mechanism)
	for module in layout.modules:
		if module.id=="ammo_rack": module.ammo_capacity=30
	var profile := LoadingProfile.new()
	profile.mode="automatic"; profile.crew_role=""
	profile.required_module_ids=[mechanism.id]; profile.shot_feed_rack_ids=["ammo_rack"]
	profile.note="TEST ONLY mechanism dependency; no historical equipment claim"
	shooter.definition.loading_profile=profile
	shooter.set_damage_layout(layout)
	shooter.state.recovery_enabled=true
	var value := ammunition(65,0)
	var options: Array[ShellDefinition]=[value]
	check(profile.validate_bindings(layout).is_empty() and shooter.gunner.configure_shell_loadout(options,{value.id:4},value.id),"automatic AI fixture uses explicit validated mechanism and ammo-rack bindings")
	shooter.state.module_states[mechanism.id].integrity=0
	check(not shooter.capabilities().can_load and shooter.capabilities().fire and shooter.gunner.inventory.chamber==1,"destroyed loader mechanism disables loading while retaining the actual chambered round")
	shooter.gunner.cooldown_left=0
	for _tick in 240:
		await physics_frame
		if shooter.gunner.shots_fired==1: break
	check(shooter.gunner.shots_fired==1 and shooter.gunner.inventory.chamber==0,"AI may fire its already chambered round after automatic loading machinery fails")
	await frames(20)
	check(ai.phase=="repair" and shooter.state.recovery_action=="repair" and shooter.state.action_target==mechanism.id and shooter.state.action_progress>0,"empty-chamber AI naturally requests and starts legal repair using can_load capability")
	check(shooter.gunner.shots_fired==1 and not shooter.capabilities().can_load,"repair-in-progress cannot invent another loaded shell or repeat fire")
	await dispose_case()
