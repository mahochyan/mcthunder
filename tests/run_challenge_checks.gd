extends SceneTree
## Rule fixtures may arrange starting poses/clocks. Shots and damage always use
## real VehicleCommand, turret, gunner, projectile manager and historical content.
var count := 0
var failed := 0
var service := GarageService.new()
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	if OS.get_cmdline_user_args().has("--active-defense-only"):
		await _hold_active("hard" if OS.get_cmdline_user_args().has("--hard-defense") else "normal")
		print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
		quit(0 if failed == 0 else 1); return
	_rules()
	await _persistence()
	await _flow()
	await _flank()
	await _flank("hard")
	await _failure_cases()
	await _objective_boundaries()
	await _repair()
	await _hold()
	await _route()
	await _route("hard")
	await _hold_active()
	await _hold_active("hard")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	if failed == 0: print("CHALLENGE_CHECKS_PASS")
	quit(0 if failed == 0 else 1)
func _rules() -> void:
	check(ChallengeCatalog.create("unknown").is_empty() and ChallengeCatalog.create("td_route","impossible").is_empty(),"unknown challenge or difficulty rejected")
	var keys := {}
	for id in ChallengeCatalog.IDS:
		for level in ChallengeCatalog.LEVELS:
			var c := ChallengeCatalog.create(id,level)
			check(service.build_loadout(ChallengeCatalog.loadout(c,service)).ok,id+"/"+level+": finite historical loadout validates")
			check(c.enemies.size()+1<=8 and MapRegistry.contains(c.map),id+": existing map and finite actor budget")
			keys[ChallengeCatalog.key(c)] = true
			var good := ChallengeScore.evaluate(c,{"elapsed":c.quick,"shots":c.economy,"repairs":1},true)
			check(good.stars == 3 and ChallengeScore.validate_bests({ChallengeCatalog.key(c):ChallengeScore.best_row(good)}),id+": exact star thresholds survive save validation")
			var late := ChallengeScore.evaluate(c,{"elapsed":c.quick+0.001,"shots":c.economy+1,"repairs":0},true)
			check(late.stars == 1,id+": both bonus boundaries excluded immediately beyond threshold")
			check(ChallengeScore.evaluate(c,{"elapsed":1,"shots":0,"repairs":1},false).stars==0,id+": failure earns no stars")
	check(keys.size()==6,"task/difficulty/version best keys remain distinct")
	check(not ChallengeScore.validate_bests({"flank_hunter:v2:normal":{}}),"unrecognized rules version is not mixed into v1 bests")
func _persistence() -> void:
	var path := "user://tests/challenges024_"+str(Time.get_ticks_usec())+"/commander"
	var old := ProfileStore.new("",service).snapshot(); old.erase("challenge_bests"); old.schema_version = 1; old.revision = 7
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path+".1.json",FileAccess.WRITE); file.store_string(JSON.stringify(old)); file.close()
	var migrated := ProfileStore.new(path,service)
	check(migrated.writable and migrated.snapshot().schema_version == 2 and migrated.snapshot().revision==7 and migrated.snapshot().challenge_bests.is_empty(),"schema1 explicitly migrates to empty challenge bests preserving revision")
	check(migrated.snapshot().garage == old.garage and migrated.snapshot().profile_id == old.profile_id,"migration preserves identity and actual garage loadouts")
	check(migrated.commit(migrated.snapshot()).ok and ProfileStore.new(path,service).snapshot()==migrated.snapshot(),"migrated profile commits and restores exact schema2")
	var bad := migrated.snapshot(); bad.challenge_bests = {"unknown":{}}
	check(not migrated.commit(bad).ok,"malformed challenge best table rejected transactionally")
	bad = migrated.snapshot(); bad.schema_version = 99
	check(not migrated.commit(bad).ok,"future schema still rejected")
	await frames(1)
func _flow() -> void:
	var app := AppFlow.new(); app.profile = ProfileStore.new("",service); root.add_child(app); current_scene = app
	await frames(3)
	app.garage._open_challenges()
	check(app.garage.challenge_selection.task_choice.item_count == 3 and app.garage.challenge_selection.best_label.text.contains("暂无"),"garage exposes three tasks and honest empty personal best")
	for id in ChallengeCatalog.IDS:
		app.enter_challenge(id,"normal"); await frames(5)
		var scene := app.training as ChallengeRange
		check(scene != null and scene.challenge_ready,id+": actual application challenge initializes")
		if scene == null or not scene.challenge_ready: continue
		check(scene.actor.definition.id == scene.config.vehicle and scene.actor.gunner.rounds_remaining == scene.config.rounds,id+": actual selected historical vehicle has exact finite ammunition")
		check(scene.combat_actors().size()==2 and scene.director.phase == "countdown",id+": one initial opponent and blocked countdown")
		check(not app.challenges.settle(scene.director.attempt_id).ok and not scene.director.finish_once(true,"fake"),id+": cannot save or announce premature success")
		scene._pause(); var before := scene.director.countdown_left; await frames(15)
		check(scene.director.countdown_left==before,id+": pause freezes countdown")
		scene._resume(); await frames(190)
		check(scene.director.phase == "playing" and scene.actor.gunner.shots_fired==0,id+": natural countdown starts without leaked launch shot")
		scene._pause(); before = scene.director.elapsed; var position := scene.actor.tank.global_position; await frames(15)
		check(scene.director.elapsed==before and scene.actor.tank.global_position==position,id+": playing pause freezes clock and actual vehicle")
		scene._resume(); check(scene.actor.gunner.resume_grace>0,id+": resume adds real firing grace")
		var attempt := scene.director.attempt_id; var life := scene.actor.life_id
		for request in 3: scene.retry()
		await frames(8)
		scene = app.training as ChallengeRange
		check(scene.director.attempt_id != attempt and scene.actor.life_id != life and scene.projectiles.active_count()==0 and scene.combat_actors().size()==2,id+": rapid repeated retry replaces entire scene, life and attempt without old enemies")
		check(not scene.director.accept_record({"record_id":"invented","identity":{"round_id":attempt,"shooter_id":"A","shooter_life_id":life}}),id+": prior-attempt and fabricated records rejected")
		scene.leave_match(); await frames(6)
		check(app.training==null and is_instance_valid(app.garage) and app.profile.snapshot().challenge_bests.is_empty(),id+": quit restores garage without awarding stars")
	app.free(); await frames(3)
func _flank(level := "normal") -> void:
	var store := ProfileStore.new("user://tests/challenge_best024_"+str(Time.get_ticks_usec())+"/commander",service)
	var progression := ChallengeProgression.new(store)
	var scene := ChallengeRange.new(); scene.difficulty = level; root.add_child(scene); current_scene = scene
	check(progression.bind(scene.director) and not progression.bind(scene.director),"challenge settlement binds actual director exactly once")
	await frames(195)
	check(scene.challenge_ready,"real-shot side test initializes")
	if not scene.challenge_ready: scene.free(); return
	# Explicit static firing fixture: arrange player beside the authentic target.
	# No cooldown/armour/module/inventory writes, and turret turns naturally.
	scene.actor.set_controller(null)
	scene.actor.tank.global_transform = Transform3D(Basis(Vector3.UP,-PI/2),Vector3(-18,0.03,-19))
	var target: VehicleActor = scene.find_actor("B1",scene._spawned.B1)
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(target.tank,target.damage_layout_override)
	var aim: Vector3 = snapshot.part_world_transforms.turret*Vector3(0,0.08,0.7)
	for tick in 1800:
		var command := VehicleCommand.new(); command.has_aim_point = true; command.aim_world_point = aim; command.fire_requested = tick>=180
		scene.actor.submit_command(command); await frames(1)
		if scene.director.phase == "finished": break
	print("[flank actual] result=",scene.director.result," dead=",target.state.destroyed," records=",scene.projectiles.shot_records.count()," flank=",scene.director.flank_hits)
	for i in scene.projectiles.shot_records.count():
		var record := scene.projectiles.shot_records.get_record(i)
		var contacts: Array = []
		for contact in record.contacts: contacts.append([contact.surface_id,contact.result])
		var damage: Array = []
		for event in record.damage: damage.append([event.item_id,event.get("newly_destroyed",false)])
		print("[shot] ",record.identity," contacts=",contacts," damage=",damage)
	check(scene.director.phase == "finished" and scene.director.result.status == "passed","real historical side shots complete flank objective")
	check(not scene.director.finish_once(true,"objectives_complete"),"actual challenge result freezes after exactly one settlement")
	var attempt := scene.director.attempt_id
	var before := store.snapshot()
	store.writable = false; store.problem = "injected save outage"
	check(not progression.settle(attempt).ok and store.snapshot()==before,"save outage preserves old profile and no invented saved best")
	var result := scene.director.result.duplicate(true)
	scene.free(); await frames(3)
	store.writable = true; store.problem = ""
	check(progression.settle(attempt).ok and store.snapshot().challenge_bests.get(result.best_key,{})==ChallengeScore.best_row(result),"verified success retries after arena freed and persists its exact best")
	before = store.snapshot()
	check(progression.settle(attempt).get("duplicate",false) and store.snapshot()==before,"duplicate completion cannot save twice or grant extra stars")
	check(ProfileStore.new(store._path,service).snapshot()==before,"new process store restores exact committed best")
func _failure_cases() -> void:
	for id in ChallengeCatalog.IDS:
		var scene := ChallengeRange.new(); scene.challenge_id = id; root.add_child(scene); await frames(2)
		scene.director.set_physics_process(false); scene.director.advance(3)
		check(not scene.director.accept_repair({"event_id":"fake","life_id":scene.actor.life_id,"after":100,"before":0}),id+": fabricated repair cannot score")
		scene.director.advance(scene.config.limit+1000)
		check(scene.director.phase=="finished" and scene.director.result.reason=="time_limit" and scene.director.result.stars==0,id+": timeout fails without inventing goal completion")
		check(scene.director.elapsed==scene.config.limit and not scene.actor.is_physics_processing() and scene.projectiles.active_count()==0,id+": finish clamps time and freezes actual combat")
		scene.free(); await frames(2)
	# Real empty-ammunition fixture: shoot into open sky and wait for real expiry.
	var empty := ChallengeRange.new(); root.add_child(empty); await frames(195)
	empty.actor.set_controller(null)
	var in_flight_empty := false
	var duplicate_checked := false
	for tick in 4200:
		var cmd := VehicleCommand.new(); cmd.has_aim_point = true; cmd.aim_world_point = Vector3(0,70,-140); cmd.fire_requested = tick>=180
		empty.actor.submit_command(cmd); await frames(1)
		if not duplicate_checked and empty.projectiles.shot_records.count()>0 and empty.director.phase=="playing":
			duplicate_checked = true
			var record := empty.projectiles.shot_records.get_record(0)
			var seen_before := empty.director._seen.size()
			check(not empty.director.accept_record(record) and empty.director._seen.size()==seen_before,"duplicate actual projectile event is rejected during live challenge")
			record.identity.shooter_life_id += 1
			check(not empty.director.accept_record(record),"mutated stale-life record cannot enter objective ledger")
		if empty.actor.gunner.rounds_remaining == 0 and empty.projectiles.active_count()>0:
			in_flight_empty = empty.director.phase=="playing"
		if empty.director.phase == "finished": break
	check(in_flight_empty,"last round in flight cannot prematurely fail finite-ammo challenge")
	check(empty.director.phase=="finished" and empty.director.result.reason=="ammunition_empty" and empty.actor.gunner.shots_fired==empty.config.rounds,"actual fired ammunition exhaustion fails once after projectiles finish")
	empty.free(); await frames(2)
	# Real opponent shot fixture arranges only a starting firing pose.
	for id in ChallengeCatalog.IDS:
		var killed := ChallengeRange.new(); killed.challenge_id = id; root.add_child(killed); await frames(195)
		killed.actor.set_controller(null)
		var enemy := killed.find_actor("B1",killed._spawned.B1); enemy.set_controller(null)
		enemy.tank.global_transform = Transform3D(Basis(Vector3.UP,-PI/2),killed.config.start+Vector3(-17,0,0))
		for attempt in 3:
			await _shoot_at(killed,enemy,killed.actor,"ammo_ready",1200)
			if killed.actor.state.destroyed: break
		check(killed.actor.state.destroyed and killed.director.result.get("reason")=="player_destroyed" and killed.director.result.stars==0,id+": actual enemy projectile destruction fails challenge without awarding stars")
		killed.free(); await frames(2)
func _aim_module(target: VehicleActor, item_id: String) -> Vector3:
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(target.tank,target.damage_layout_override)
	for module in target.damage_layout_override.modules:
		if module.id == item_id: return snapshot.part_world_transforms[module.part_id]*module.local_box_transform.origin
	return target.tank.global_position+Vector3.UP*2
func _shoot_at(scene: ChallengeRange, shooter: VehicleActor, target: VehicleActor, item_id: String, limit: int) -> void:
	var baseline := shooter.gunner.shots_fired
	for tick in limit:
		if scene.director.phase != "playing" or shooter.state.destroyed or target.state.destroyed: break
		var point := _aim_module(target,item_id)
		var cmd := VehicleCommand.new(); cmd.has_aim_point = true; cmd.aim_world_point = point
		cmd.fire_requested = shooter.turret.barrel_direction().dot((point-shooter.turret.barrel_pivot.global_position).normalized())>0.99999
		shooter.submit_command(cmd); await frames(1)
		if shooter.gunner.shots_fired>baseline and scene.projectiles.active_count()==0: break
func _repair() -> void:
	var scene := ChallengeRange.new(); scene.challenge_id="hold_ground"; root.add_child(scene); await frames(195)
	scene.actor.set_controller(null)
	var enemy := scene.find_actor("B1",scene._spawned.B1); enemy.set_controller(null)
	for i in 20:
		var healthy := VehicleCommand.new(); healthy.repair_requested = true; scene.actor.submit_command(healthy); await frames(1)
	check(scene.director.repairs==0 and scene.actor.last_recovery_record.is_empty(),"healthy repair commands never earn repair stars")
	enemy.tank.global_transform = Transform3D(Basis(Vector3.UP,-PI/2),Vector3(-95,0.03,100))
	var point := scene.actor.tank.global_transform*Vector3(-1.12,0.51,-1.6)
	var baseline := enemy.gunner.shots_fired
	for tick in 1200:
		var cmd := VehicleCommand.new(); cmd.has_aim_point=true; cmd.aim_world_point=point
		cmd.fire_requested = enemy.turret.barrel_direction().dot((point-enemy.turret.barrel_pivot.global_position).normalized())>0.99999
		enemy.submit_command(cmd); await frames(1)
		if enemy.gunner.shots_fired>baseline and scene.projectiles.active_count()==0: break
	check(not scene.actor.state.destroyed and float(scene.actor.state.module_states.track_left.integrity)<float(scene.actor.state.module_states.track_left.max_integrity),"real enemy round damages player track without scripted damage")
	var repair := VehicleCommand.new(); repair.repair_requested = true
	scene.actor.submit_command(repair); await frames(2)
	scene._pause(); var progress := scene.actor.state.action_progress; await frames(30)
	check(scene.actor.state.action_progress==progress and scene.director.repairs==0,"pause freezes actual in-progress repair and challenge score")
	scene._resume()
	for i in 900:
		scene.actor.submit_command(repair); await frames(1)
		if scene.director.repairs>0: break
	check(scene.director.repairs==1 and not scene.actor.last_recovery_record.is_empty(),"actual damaged module repair emits one authenticated event")
	check(not scene.director.accept_repair(scene.actor.last_recovery_record) and scene.director.repairs==1,"duplicate committed repair event cannot score twice")
	scene.free(); await frames(2)
func _hold() -> void:
	var scene := ChallengeRange.new(); scene.challenge_id="hold_ground"; root.add_child(scene); await frames(195)
	scene.actor.set_controller(null)
	# Isolated shot/wave/occupancy integration fixture. Full-AI driving is exercised
	# separately; here opponents are retained as real, stationary firing targets.
	for wave in 2:
		var blockers: Array[Node] = []
		if wave == 0:
			blockers.append(scene._add_wall(Vector3(-95,2,50),Vector3(8,4,8)))
			blockers.append(scene._add_wall(Vector3(-95,2,75),Vector3(8,4,8)))
		var enemy := scene.find_actor("B%d"%(wave+1),scene._spawned.get("B%d"%(wave+1),-1))
		check(enemy != null,"finite defense wave %d actually spawns"%(wave+1))
		if enemy == null: break
		enemy.set_controller(null)
		var pose := enemy.tank.global_transform
		scene.actor.tank.global_transform = Transform3D(Basis(Vector3.UP,-PI/2 if wave == 0 else PI/2),pose.origin+Vector3(-18 if wave == 0 else 18,0,0))
		for attempt in 3:
			await _shoot_at(scene,scene.actor,enemy,"ammo_ready",1200)
			if enemy.state.destroyed: break
		check(enemy.state.destroyed,"real historical projectile destroys defense wave %d"%(wave+1))
		await frames(3)
		if wave == 0:
			check(scene.director.spawn_waiting and scene.combat_actors().size()==2,"all occupied wave candidates wait without overlap or invented defeat")
			for blocker in blockers: blocker.free()
			await frames(90)
			check(not scene.director.spawn_waiting and scene._spawned.has("B2"),"second wave safely enters when a real candidate clears")
	check(scene.combat_actors().size()==3 and scene.director.kills.size()==2,"defense uses exactly two unique attributed enemy lives")
	check(scene.spawn_wave(1) and scene.combat_actors().size()==3,"repeated wave request cannot spawn extra actors")
	scene.actor.tank.global_transform = Transform3D(Basis.IDENTITY,scene.config.start)
	await frames(2200)
	check(scene.director.phase=="finished" and scene.director.result.status=="passed","actual occupancy time and real finite-wave kills complete defense")
	scene.free(); await frames(2)

func _objective_boundaries() -> void:
	# Mathematical time/position fixture: actors are arranged at region boundaries.
	# This does not stand in for the driving and shooting integration cases below.
	var scene := ChallengeRange.new(); scene.challenge_id = "td_route"; root.add_child(scene); await frames(2)
	scene.director.set_physics_process(false); scene.director.advance(3)
	for vehicle in scene.combat_actors(): vehicle.set_physics_process(false)
	var enemy := scene.find_actor("B1",scene._spawned.B1)
	scene.actor.tank.global_position = Vector3.ZERO; scene.director.advance(5)
	check(scene.director.checkpoint==0 and scene.director.held==0,"entering final point before route cannot advance objectives")
	scene.actor.tank.global_position = scene.config.route[1]; scene.director.advance(1)
	check(scene.director.checkpoint==0,"second checkpoint cannot be taken out of order")
	for point in scene.config.route:
		scene.actor.tank.global_position = point; scene.director.advance(0.1)
	scene.actor.tank.global_position = Vector3.ZERO; scene.director.advance(7)
	check(scene.director.checkpoint==2 and is_equal_approx(scene.director.held,7),"ordered checkpoints enable actual unopposed capture")
	scene.actor.tank.global_position = Vector3(20,0,0); scene.director.advance(0.1)
	check(scene.director.held==0,"leaving timed point resets continuous capture")
	scene.actor.tank.global_position = Vector3.ZERO; scene.director.advance(7)
	enemy.tank.global_position = Vector3(3,0,0); scene.director.advance(0.1)
	check(scene.director.held==0 and scene.director.contested(),"living enemy entering point resets continuous capture")
	enemy.tank.global_position = Vector3(25,0,-20); scene.director.advance(7)
	scene._pause(); scene.director.advance(40)
	check(is_equal_approx(scene.director.held,7),"manual large clock delta cannot advance paused capture")
	scene._resume()
	scene.actor.tank.global_position = Vector3(20,0,0); scene.director.advance(scene.config.limit-scene.director.elapsed-1)
	scene.actor.tank.global_position = Vector3.ZERO; scene.director.advance(100)
	check(scene.director.result.get("reason")=="time_limit" and scene.director.held<=1.000001,"oversized final delta cannot award capture time beyond deadline")
	scene.free(); await frames(2)
	scene = ChallengeRange.new(); scene.challenge_id="hold_ground"; root.add_child(scene); await frames(2)
	scene.director.set_physics_process(false); scene.director.advance(3)
	for vehicle in scene.combat_actors(): vehicle.set_physics_process(false)
	scene.director.advance(5)
	scene.actor.tank.global_position = scene.config.zone+Vector3(20,0,0); scene.director.advance(5)
	check(is_equal_approx(scene.director.held,5),"defense retains previous hold time while outside zone")
	scene.actor.tank.global_position = scene.config.zone
	enemy = scene.find_actor("B1",scene._spawned.B1); enemy.tank.global_position = scene.config.zone+Vector3(3,0,0)
	scene.director.advance(5)
	check(is_equal_approx(scene.director.held,5),"contested defense stops accumulating without clearing prior time")
	enemy.tank.global_position = Vector3(-78,0,25); scene.director.advance(5)
	check(is_equal_approx(scene.director.held,10) and scene.director.phase=="playing","defense resumes accumulation but cannot finish without kills")
	scene.free(); await frames(2)
func _drive(scene: ChallengeRange, goal: Vector3, maximum_frames: int, target_module := "ammo_ready", keep_fighting := false, stop_kills := -1) -> bool:
	for tick in maximum_frames:
		if stop_kills>=0 and scene.director.kills.size()>=stop_kills: return true
		if scene.director.phase != "playing" or scene.actor.state.destroyed: break
		var delta := (goal-scene.actor.tank.global_position)*Vector3(1,0,1)
		var angle := wrapf(atan2(-delta.x,-delta.z)-scene.actor.tank.global_rotation.y,-PI,PI)
		var cmd := VehicleCommand.new()
		cmd.steer = (1.0 if angle>0.05 else (-1.0 if angle< -0.05 else 0.0)) if delta.length()>2 else 0.0
		if delta.length()>2 and absf(angle)<0.15: cmd.throttle = 1.0 if scene.actor.tank.forward_speed<7 else 0.0
		elif delta.length()<=2 and scene.actor.tank.forward_speed>0.2: cmd.throttle = -1
		# This integration pilot is an explicit script controller. Actual opponent
		# perception and commands remain unchanged and all fire uses common physics.
		for enemy in scene.combat_actors():
			if enemy.state.team_id != 2 or enemy.state.destroyed: continue
			var point := _aim_module(enemy,target_module)
			point = AimSolver.solve(scene.actor.turret.muzzle.global_position,{"aim_point":point,"velocity":enemy.tank.velocity},scene.actor.gunner.shell,scene.actor.tank.velocity,Vector2.ZERO)
			cmd.has_aim_point = true; cmd.aim_world_point = point
			var offset := point-scene.actor.turret.muzzle.global_position
			var sight := WorldQueryAdapter.query_world_stop(scene.get_world_3d().direct_space_state,scene.actor.turret.muzzle.global_position,offset.normalized(),offset.length(),[scene.actor.tank.get_rid()])
			var clear: bool = sight.get("ok",false) and sight.get("contact",{}).is_empty()
			cmd.fire_requested = clear and scene.actor.turret.barrel_direction().dot((point-scene.actor.turret.barrel_pivot.global_position).normalized())>0.999999 and offset.length()<100
			if target_module.contains("floor"):
				var local: Vector3 = enemy.tank.global_basis.inverse()*(scene.actor.tank.global_position-enemy.tank.global_position)
				cmd.fire_requested = cmd.fire_requested and absf(local.x)>absf(local.z)*1.5
		var caps := scene.actor.capabilities()
		if not caps.drive or not caps.fire or caps.turret_speed<=0 or not scene.actor.state.fires.is_empty():
			cmd.throttle = 0; cmd.steer = 0
			if not scene.actor.state.role_available("gunner") or not scene.actor.state.role_available("driver"): cmd.replace_crew_requested = true
			else: cmd.repair_requested = true
			cmd.extinguish_requested = not scene.actor.state.fires.is_empty()
		scene.actor.submit_command(cmd); await frames(1)
		if delta.length()<2 and absf(scene.actor.tank.forward_speed)<0.2 and not keep_fighting: return true
	print("[drive incomplete] goal=",goal," position=",scene.actor.tank.global_position," speed=",scene.actor.tank.forward_speed," caps=",scene.actor.capabilities()," phase=",scene.director.phase)
	return false
func _route(level := "normal") -> void:
	var scene := ChallengeRange.new(); scene.challenge_id="td_route"; scene.difficulty=level; root.add_child(scene); await frames(195)
	scene.actor.set_controller(null)
	for point in scene.config.route:
		check(await _drive(scene,point,2400),"actual M36 drives to authored checkpoint "+str(point))
	check(scene.director.checkpoint==2,"ordered checkpoints advance from real actor positions")
	check(await _drive(scene,Vector3.ZERO,2400),"actual M36 reaches central capture zone against active AI")
	await frames(1000)
	print("[route actual] ",scene.director.result," held=",scene.director.held," checkpoints=",scene.director.checkpoint," shots=",scene.actor.gunner.shots_fired," player_dead=",scene.actor.state.destroyed)
	check(scene.director.phase=="finished" and scene.director.result.status=="passed","real route and uninterrupted capture complete limited-ammo M36 task")
	scene.free(); await frames(2)
func _hold_active(level := "normal") -> void:
	var scene := ChallengeRange.new(); scene.challenge_id="hold_ground"; scene.difficulty=level; root.add_child(scene); await frames(195)
	scene.actor.set_controller(null)
	await _drive(scene,Vector3(-62,0,100),2400,"ammo_floor_left",true,1)
	if scene.director.phase == "playing":
		await _drive(scene,Vector3(-65,0,90),2400,"ammo_floor_left",true,2)
		await _drive(scene,Vector3(-65,0,100),1800,"ammo_floor_left")
		await frames(2200)
	var enemies: Array = []
	for vehicle in scene.combat_actors():
		if vehicle != scene.actor: enemies.append({"id":vehicle.entity_id,"position":vehicle.tank.global_position,"dead":vehicle.state.destroyed,"shots":vehicle.gunner.shots_fired,"caps":vehicle.capabilities(),"ai":vehicle.controller.phase if vehicle.controller is AITankController else "none","drive":vehicle.controller.driver.phase if vehicle.controller is AITankController else "none"})
	print("[active defense] ",scene.director.result," held=",scene.director.held," kills=",scene.director.kills," player_shots=",scene.actor.gunner.shots_fired," remaining=",scene.actor.gunner.rounds_remaining," enemies=",enemies)
	for i in scene.projectiles.shot_records.count():
		var record := scene.projectiles.shot_records.get_record(i)
		if record.identity.shooter_id != "A": continue
		var hit_rows: Array = []; var damage_rows: Array = []
		for contact in record.contacts: hit_rows.append([contact.get("surface_id"),contact.get("result"),contact.get("point_world")])
		for event in record.damage: damage_rows.append([event.item_id,event.get("newly_destroyed",false)])
		print("[defense shot] ",record.identity.shot_id," hit=",hit_rows," damage=",damage_rows)
	check(scene.director.phase=="finished" and scene.director.result.status=="passed","real defense script pilot completes finite waves with opponent AI untouched")
	scene.free(); await frames(2)
