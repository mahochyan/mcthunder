extends SceneTree
## Real loopback packets; only the authority world contains the ranging wall.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func ticks(count: int) -> void:
	for i in count: await physics_frame
	await process_frame
func command_for(mode: String="sight") -> VehicleCommand:
	var cmd := VehicleCommand.new()
	cmd.clear_aim=true
	cmd.aim_held=mode=="sight"
	cmd.hold_aim=mode in ["binocular","free"]
	cmd.aim_intent.active=true
	cmd.aim_intent.mode=mode
	cmd.aim_intent.yaw=0
	cmd.aim_intent.pitch=0
	return cmd
func send_command(client: NetworkBattleClient, cmd: VehicleCommand) -> bool:
	for i in 60:
		if client.submit(cmd): return true
		await physics_frame
	return false
func hold_command(client: NetworkBattleClient, cmd: VehicleCommand, count: int) -> void:
	for i in count:
		client.submit(cmd)
		await physics_frame
	await process_frame
func run() -> void:
	var space := SubViewport.new(); space.own_world_3d=true; root.add_child(space)
	var server := NetworkBattleServer.new(); space.add_child(server)
	check(server.start(19116)==OK and server.world.ready_ok,"real authority starts for network ranging")
	if not server.world.ready_ok: space.free(); quit(1); return
	var view := NetworkClientView.new(); view.port=19116; root.add_child(view)
	# Disable only the human-input poll; the production receive/render path stays live.
	view.set_physics_process(false)
	var observer := NetworkBattleClient.new(); root.add_child(observer); observer.connect_local(19116)
	await ticks(90)
	check(view.owned!=null and observer.entity_id!="" and observer.entity_id!=view.connection.entity_id,"two real clients receive distinct ownership")
	if view.owned==null or observer.entity_id=="":
		view.free(); observer.free(); space.free(); quit(1); return
	var authority: VehicleActor
	var other_authority: VehicleActor
	for actor in server.world.actors:
		if actor.entity_id==view.connection.entity_id: authority=actor
		else: other_authority=actor
	check(not authority.presentation_enabled and authority.cam_rig.cam==null,"authority owns no Camera3D presentation dependency")
	# First-ever optical input on the other vehicle has no warmed camera cache.
	# An untrusted hold=false / fire=true packet must not override binocular rules.
	var first_observation := command_for("binocular")
	first_observation.hold_aim=false; first_observation.fire_requested=true
	first_observation.aim_intent.yaw=0.4
	var other_yaw := other_authority.turret.rotation.y
	var other_shots := other_authority.gunner.shots_fired
	await send_command(observer,first_observation)
	await ticks(6)
	check(other_authority.cam_rig.binoculars and other_authority.cam_rig.intent_point().is_finite(),"first server binocular entry has a finite intention without a rendered camera")
	check(other_authority.turret.observation_hold and other_authority.turret.rotation.y==other_yaw and other_authority.gunner.shots_fired==other_shots,"binocular packet cannot disable mechanical hold or force a shot")
	var inactive_fire := VehicleCommand.new()
	inactive_fire.fire_requested=true; inactive_fire.has_aim_point=true
	inactive_fire.aim_world_point=other_authority.tank.global_position+Vector3(100,20,-20)
	await send_command(observer,inactive_fire)
	await ticks(6)
	check(other_authority.cam_rig.binoculars and other_authority.turret.observation_hold and other_authority.turret.rotation.y==other_yaw and other_authority.gunner.shots_fired==other_shots,"inactive intent cannot bypass retained binocular hold or fire inhibition")
	other_authority.reset_vehicle()
	# Headless DisplayServer cannot capture mouse input. Set the client's optical
	# intention explicitly, then retain the production PlayerController poll,
	# packet transport and finite authority mechanism. Real mouse events belong
	# to run_optics_player_checks in an actual window.
	view.player.commands_enabled=true
	view.set_physics_process(true)
	view.owned.cam_rig.set_aim(0.525,0.07)
	await ticks(180)
	print("[ANGULAR_NETWORK] local_yaw=",view.owned.cam_rig.aim_yaw," authority_intent=",authority.cam_rig.aim_yaw," turret_yaw=",authority.turret.rotation.y," speed_deg_s=",authority.definition.turret_yaw_speed," accepted=",server.accepted," rejected=",server.rejected)
	check(absf(view.owned.cam_rig.aim_yaw)>0.01 and authority.fire_control.zeroing_m==0 and absf(wrapf(authority.turret.rotation.y-view.owned.cam_rig.aim_yaw,-PI,PI))<0.02,"client camera intention traverses actual player poll and network to turn the zeroed authority turret")
	view.set_physics_process(false)
	var direct := command_for()
	await hold_command(view.connection,direct,60)
	# Both possible assigned vehicles see this wall about 500m away. It is absent
	# from the client world, so a successful measurement cannot be client geometry.
	TerrainFixtures.box(server.world,Vector3(8,5,-488),Vector3(200,20,1))
	await ticks(3)
	var cmd := command_for(); cmd.range_requested=true
	check(await send_command(view.connection,cmd),"range edge is sent through production command encoder")
	cmd.range_requested=false
	await hold_command(view.connection,cmd,12)
	check(authority.fire_control.status=="measuring" and authority.fire_control.measurement_left_s>0,"server starts a timed measurement from angular intent")
	var left := authority.fire_control.measurement_left_s
	await hold_command(view.connection,cmd,20)
	check(authority.fire_control.measurement_left_s<left and authority.fire_control.measurement_left_s>0,"held packets do not replay the range edge or restart its timer")
	await hold_command(view.connection,cmd,130)
	check(authority.fire_control.status=="measured" and absf(authority.fire_control.measured_range_m-500)<=25,"authority measures its own distant wall with configured quantization")
	await ticks(6)
	check(view.owned.fire_control.status=="measured" and view.owned.fire_control.measured_range_m==authority.fire_control.measured_range_m,"owner replica receives the authoritative measurement")
	check(view.owned.fire_control.zeroing_m==0,"measurement alone does not silently alter zeroing")
	check(observer.own_status.fire_control.status=="idle" and observer.own_status.fire_control.measured_range_m==0,"other client receives only its own unmeasured status")
	var leaked := false
	for row in view.connection.latest.vehicles:
		for key in ["fire_control","measured_range_m","zeroing_m","aim_intent"]:
			leaked=leaked or row.has(key)
	check(not leaked,"public vehicle poses contain no private range or optical intention")
	check(int(view.connection.own_status.consumed_sequence)>=0,"owner receives a real consumed-input acknowledgement")
	cmd.apply_range_requested=true
	check(await send_command(view.connection,cmd),"apply measured range edge is sent")
	cmd.apply_range_requested=false
	await hold_command(view.connection,cmd,12)
	check(authority.fire_control.zeroing_m==authority.fire_control.measured_range_m and view.owned.fire_control.zeroing_m==authority.fire_control.zeroing_m,"adopt-range request changes server zeroing and returns to owner")
	var adopted := authority.fire_control.zeroing_m
	cmd.zeroing_steps=2
	check(await send_command(view.connection,cmd),"manual zeroing edge is sent")
	cmd.zeroing_steps=0
	await hold_command(view.connection,cmd,30)
	check(authority.fire_control.zeroing_m==adopted+200 and view.owned.fire_control.zeroing_m==authority.fire_control.zeroing_m,"two manual increments execute once across held packets")
	cmd=command_for("binocular"); cmd.range_requested=true; cmd.steer=0.5
	check(await send_command(view.connection,cmd),"binocular range request crosses network")
	cmd.range_requested=false
	await hold_command(view.connection,cmd,6)
	var yaw := authority.turret.rotation.y
	var pitch := authority.turret.barrel_pivot.rotation.x
	await hold_command(view.connection,cmd,24)
	check(authority.fire_control.status=="measuring" and authority.turret.rotation.y==yaw and authority.turret.barrel_pivot.rotation.x==pitch,"binocular ranging preserves both authoritative mechanism axes while hull turns")
	# A real generation transition must clear both in-flight measurement and
	# client-side edges waiting for a send opportunity.
	var staged := command_for(); staged.range_requested=true; view.pending.submit(staged)
	var stale := VehicleCommandCodec.encode(cmd,authority,view.connection.sequence,Engine.get_physics_frames())
	authority.reset_vehicle()
	await ticks(12)
	check(view.own_generation==authority.state.generation and not view.pending.has_staged(),"new authoritative generation clears staged client actions")
	check(authority.fire_control.status=="idle" and view.owned.fire_control.status=="idle" and view.owned.fire_control.zeroing_m==0,"respawn replaces old measurement and zeroing on authority and owner")
	var accepted_before := server.accepted
	view.connection.send({"type":"command","envelope":stale})
	await ticks(6)
	check(server.accepted==accepted_before and authority.fire_control.status=="idle","old generation cannot reapply optical input after respawn")
	# Changing only the control epoch is also a lifecycle boundary. Old pending
	# edges must not be repackaged with the new epoch by the next send opportunity.
	var before_generation := authority.state.generation
	view.pending.submit(staged)
	authority.pause_block(true)
	await ticks(6)
	authority.pause_block(false)
	await ticks(6)
	check(authority.state.generation==before_generation and not view.pending.has_staged(),"same-generation control epoch change clears staged client range edges")
	cmd=command_for(); cmd.aim_intent.pitch=0.6; cmd.range_requested=true
	await send_command(view.connection,cmd); cmd.range_requested=false
	await hold_command(view.connection,cmd,155)
	check(authority.fire_control.status=="failed" and view.owned.fire_control.status=="failed" and view.owned.fire_control.measured_range_m==0,"empty sky returns authoritative failure without inventing a distance")
	# Exercise the production receive function with malformed private data. No
	# packet may advance public pose while leaving an older private result behind.
	var stable_snapshot := view.connection.latest.duplicate(true)
	var stable_status := view.connection.own_status.duplicate(true)
	for fault in ["nan_range","numeric_flag","unknown_status","missing_field","expired_as_measured","future_consumed","extra_owner_field"]:
		var snapshot := server.world.snapshot(int(view.connection.latest.sequence)+1)
		var stats := server.world.own_status(authority)
		match fault:
			"nan_range": stats.fire_control.measured_range_m=NAN
			"numeric_flag": stats.fire_control.solution_ok=1
			"unknown_status": stats.fire_control.status="invented"
			"missing_field": stats.fire_control.erase("zeroing_m")
			"expired_as_measured":
				stats.fire_control.status="measured"; stats.fire_control.measured_range_m=500; stats.fire_control.valid_left_s=0
			"future_consumed": stats.consumed_sequence=authority._last_input_sequence+1
			"extra_owner_field": stats.enemy_range=999
		check(not view.connection.accept_message({"type":"snapshot","snapshot":snapshot,"own_status":stats}) and view.connection.latest==stable_snapshot and view.connection.own_status==stable_status,"malformed owner status rejected atomically: "+fault)
	check(view.owned.gunner.shots_fired==0 and view.owned.tank.drive_call_count()==0,"range feedback never starts local combat authority")
	view.free(); observer.free(); space.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("NETWORK_FIRE_CONTROL_CHECKS_PASS" if failures==0 else "NETWORK_FIRE_CONTROL_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
