extends SceneTree
const APP_SCENE = preload("res://scenes/app.tscn")
var app: AppFlow
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(count: int = 3) -> void:
	for i in count: await physics_frame
	await process_frame
func idle() -> void:
	for i in 500:
		await process_frame
		if not app._transitioning: await frames(); return
	check(false,"tutorial transition bounded")
func start(chapter: int) -> void:
	app.start_tutorial(chapter); await idle()
	check(is_instance_valid(app.tutorial_guide) and app.tutorial_guide.chapter == chapter,"chapter %d starts actual configured scene" % chapter)
	check(not app.tutorial_guide.passed and app.tutorial_guide.next_button.disabled,"chapter %d cannot complete by opening it" % chapter)
func drive(goal: Vector3, limit: int) -> void:
	var actor := app.training.actor as VehicleActor
	actor.set_controller(null)
	for tick in limit:
		var offset := (goal-actor.tank.global_position)*Vector3(1,0,1)
		var angle := wrapf(atan2(-offset.x,-offset.z)-actor.tank.global_rotation.y,-PI,PI)
		var command := VehicleCommand.new()
		command.steer = clampf(angle*2,-1,1) if offset.length()>1 else 0
		if offset.length()>1 and absf(angle)<0.15: command.throttle = 1 if actor.tank.forward_speed<3 else 0
		elif actor.tank.forward_speed>0.2: command.throttle = -1
		actor.submit_command(command); await frames(1)
		if offset.length()<1.5 and absf(actor.tank.forward_speed)<0.2: return
func shoot(core: CoreRange, aim_override := Vector3.INF) -> void:
	core.source_actor.set_controller(null)
	var before := core.source_actor.gunner.shots_fired
	for tick in 1000:
		var point := AimSolver.solve(core.source_actor.turret.muzzle.global_position,{"aim_point":aim_override if aim_override.is_finite() else core.target_point(),"velocity":core.target_actor.tank.velocity},core.source_actor.gunner.shell,Vector3.ZERO,Vector2.ZERO)
		var command := VehicleCommand.new(); command.has_aim_point = true; command.aim_world_point = point
		command.fire_requested = core.source_actor.turret.barrel_direction().dot((point-core.source_actor.turret.barrel_pivot.global_position).normalized())>0.999999
		core.source_actor.submit_command(command); await frames(1)
		if core.source_actor.gunner.shots_fired>before and core.projectiles.active_count()==0: return
func run() -> void:
	create_timer(600,true,false,true).timeout.connect(func() -> void: print("TUTORIAL_TIMEOUT"); quit(2))
	var path := "user://tests/tutorial028_%d/commander" % Time.get_ticks_usec()
	var store := ProfileStore.new(path)
	var old := store.snapshot(); old.erase("tutorial"); old.schema_version = 2; old.revision = 3
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path+".1.json",FileAccess.WRITE); file.store_string(JSON.stringify(old)); file.close()
	store = ProfileStore.new(path)
	check(store.snapshot().schema_version==3 and store.snapshot().revision==3 and store.snapshot().research_points==old.research_points,"schema2 migration adds only chapter progress and preserves real saved economy")
	for bad in [{"chapter":-1,"completed":[]},{"chapter":11,"completed":[]},{"chapter":1,"completed":[1,1]},{"chapter":0,"completed":["res://evil.gd"]}]:
		var invalid := store.snapshot(); invalid.tutorial = bad
		check(not store.commit(invalid).ok,"invalid tutorial checkpoint rejected")
	app = APP_SCENE.instantiate(); app.profile = store; root.add_child(app); current_scene = app; await idle()
	await start(0)
	var saved := store.snapshot()
	check(not app._save_tutorial() and store.snapshot()==saved,"uncompleted guide cannot award a chapter")
	await drive(app.tutorial_guide.goal,900); await frames(5)
	check(app.tutorial_guide.passed and 0 in store.snapshot().tutorial.completed,"real driving and parking completes chapter and saves once")
	saved = store.snapshot(); app._save_tutorial()
	check(store.snapshot()==saved,"chapter completion is idempotent")
	app.training.restart_lesson(); await frames()
	check(not app.tutorial_guide.passed and app.tutorial_guide.next_button.disabled,"retry clears observation of previous round")
	await start(1)
	app.training.actor.set_controller(null)
	for tick in 120:
		var command := VehicleCommand.new(); command.has_aim_point=true; command.aim_world_point=Vector3(12,2,-30); command.aim_held=true
		app.training.actor.submit_command(command); await frames(1)
	check(app.tutorial_guide.passed,"actual turret motion and real gunsight complete observation chapter")
	for chapter in [2,3,4,5,6,7]:
		await start(chapter)
		var core := app.training as CoreRange
		if chapter==4:
			await shoot(core,core.target_actor.tank.global_transform*Vector3(0,1.3,1.45))
			check(not app.tutorial_guide.passed,"actual engine hit cannot complete the required breech chapter")
		if chapter==3: store.writable=false; store.problem="test save outage"
		await shoot(core)
		if chapter==3:
			check(app.tutorial_guide.passed and not app.tutorial_guide.save_error.is_empty() and 3 not in store.snapshot().tutorial.completed,"save failure leaves chapter visibly unsaved and preserves prior disk state")
			store.writable=true; store.problem=""
			check(app._save_tutorial() and 3 in ProfileStore.new(path).snapshot().tutorial.completed,"retry saves the same verified chapter after write access returns")
		if chapter in [5,6]:
			check(not app.tutorial_guide.passed,"damage alone cannot complete recovery chapter %d" % chapter)
			core.switch_control(); core.actor.set_controller(null)
			for tick in 1000:
				var command := VehicleCommand.new(); command.repair_requested=chapter==5; command.extinguish_requested=chapter==6
				core.actor.submit_command(command); await frames(1)
				if app.tutorial_guide.passed: break
		print("TUTORIAL_ACTUAL chapter=%d passed=%s shots=%d director=%s target=%s" % [chapter,app.tutorial_guide.passed,core.source_actor.gunner.shots_fired,core.director.status,core.target_actor.capabilities()])
		if chapter==6: print("TUTORIAL_FIRE observed=",app.tutorial_guide.fire_seen," action_seen=",app.tutorial_guide.extinguish_seen," charges=",core.target_actor.state.extinguisher_charges," initial=",app.tutorial_guide.charges_before," fires=",core.target_actor.state.fires," action=",core.target_actor.state.recovery_action," reason=",core.target_actor.state.recovery_reason," enabled=",core.target_actor.state.recovery_enabled)
		check(app.tutorial_guide.passed,"real projectile/recovery pipeline completes chapter %d" % chapter)
	await start(8)
	await frames(120)
	check(not app.tutorial_guide.passed and app.tutorial_guide.capture.capture_progress==0,"time outside capture circle does not complete chapter")
	await drive(app.tutorial_guide.goal,1200); await frames(740)
	check(app.tutorial_guide.passed and app.tutorial_guide.capture.capture_owner==1,"actual entry and full production capture duration complete objective")
	await start(9)
	var battle := app.training as TeamRange
	await frames(190); battle.abandon_vehicle(); await frames(5)
	check(not app.tutorial_guide.passed,"death itself does not count as redeploy")
	battle.request_respawn(); await frames(10)
	check(not app.tutorial_guide.passed,"early redeploy cannot skip preparation")
	await frames(480); battle.request_respawn(); await frames(8)
	check(app.tutorial_guide.passed and not battle.actor.gunner.training_resupply and app.match_token.is_empty(),"normal respawn completes chapter without infinite battle ammo or formal reward")
	app.return_to_garage(); await idle()
	check(app.tutorial_chapter==-1 and app.garage!=null,"skip/return leaves tutorial context")
	check(ProfileStore.new(path).snapshot().tutorial == store.snapshot().tutorial and store.snapshot().tutorial.completed.size()==TutorialCatalog.COUNT,"all ten chapters persist through real disk reload")
	check(store.snapshot().research_points==old.research_points and store.snapshot().receipts.is_empty(),"tutorial never grants formal combat rewards")
	app.free(); await frames()
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks,failed])
	if failed==0: print("TUTORIAL_CHECKS_PASS")
	quit(0 if failed==0 else 1)
