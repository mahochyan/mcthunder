extends "res://tests/run_shell_checks.gd"
## TEST ONLY geometry, speeds and rules. Tests real manager/fragment transactions.
var policy := {"mode":"penetration_delay","arming_thickness_mm":8.0,"delay_s":0.003,
	"provenance":"game_rule","reason":"TEST ONLY timing and geometry fixture"}
var replay_sample: Dictionary = {}

func launch_delayed(thickness: float = 20.0, length: float = 4.0, speed: float = 600.0, supplied: Dictionary = {}) -> ProjectileState:
	manager.cancel_all("cancelled_fixture")
	target.set_damage_layout(ShellTrainingTargets.build(thickness,length,false))
	shot += 1
	var spec := {"round_id":13,"shooter_id":"fixture","shooter_life_id":1,"shot_id":shot,"shell_id":"test_delayed",
		"armor_policy":"resolve","effect_policy":"internal_burst","penetration_curve":PackedVector2Array([Vector2(0,96)]),"seed":2101,
		"fuze_policy":policy.duplicate(true),"position_world":target.tank.global_transform*Vector3(0,2,4),
		"velocity_world":Vector3(0,0,-speed),"gravity_world":Vector3.ZERO,"max_age_s":0.1,"max_distance_m":100.0}
	spec.merge(supplied,true)
	var accepted := manager.try_spawn(spec)
	check(accepted.get("ok",false),"real manager admits TEST ONLY delayed round")
	return manager.get_projectile_state(int(accepted.get("projectile_id",0)))

func advance_until_done(st: ProjectileState, dt: float = 1.0/60.0) -> void:
	for i in 100:
		if st.is_terminal(): break
		manager.advance_projectile(st,dt,snapshots(),world.get_world_3d().direct_space_state)
	check(st.is_terminal(),"bounded fixture reaches real terminal state")

func check_burst(st: ProjectileState, expected: Vector3, label: String) -> void:
	check(not st.burst.is_empty() and st.terminal_reason=="internal_burst",label+": detonated")
	if st.burst.is_empty(): return
	check(absf(st.burst.time_s-st.fuze_armed_age_s-float(st.fuze_policy.delay_s))<1e-7,label+": exact simulated delay")
	check(st.burst.point_world.distance_to(target.tank.global_transform*expected)<0.001,label+": real ballistic position")
	check(st.fragments.size()==12,label+": bounded real fragments")
	var record: Dictionary=manager.shot_records.get_record(manager.shot_records.count()-1)
	check(not record.is_empty() and ShotRecordBuilder.validate(record).ok,label+": replay validates")

func add_exterior_module() -> void:
	var layout := target.damage_layout_override.duplicate(true) as VehicleLayoutDefinition
	var module := ModuleVolumeDefinition.new()
	module.id="external_component"; module.kind="turret_drive"; module.part_id="hull"; module.external=true
	module.local_box_transform.origin=Vector3(1.5,2,-1.6); module.size_m=Vector3(0.5,2.8,3)
	layout.modules.append(module); target.set_damage_layout(layout)

func validation_cases() -> void:
	check(ShellFuze.validate({},"kinetic").is_empty(),"legacy AP remains compatible")
	check(not ShellFuze.validate(policy,"kinetic").is_empty(),"AP cannot silently acquire explosive fuze")
	for invalid in [null,[],{"mode":"other"},policy.merged({"delay_s":0.0},true),policy.merged({"delay_s":INF},true),
		policy.merged({"arming_thickness_mm":-1.0},true),policy.merged({"provenance":"historical_verified"},true),policy.merged({"reason":""},true)]:
		check(not ShellFuze.validate(invalid,"internal_burst").is_empty(),"invalid policy rejected: "+str(invalid))
		var accepted := manager.try_spawn({"shell_id":"test","shooter_id":"fixture","shot_id":999,"position_world":Vector3.ZERO,
			"velocity_world":Vector3.FORWARD,"max_age_s":1,"max_distance_m":5,"effect_policy":"internal_burst",
			"penetration_curve":PackedVector2Array([Vector2(0,96)]),"fuze_policy":invalid})
		check(not accepted.ok and accepted.reason=="invalid_fuze_policy","invalid launch rejected before identity consumption")
	var st := ProjectileState.new(); st.fuze_policy=policy.duplicate(true); st.age_s=0.1
	for result in [{"result":"stopped"},{"result":"unknown_armor"},{"result":"ricochet"},{"result":"penetrated","backface":true,"effective_mm":20}]:
		ShellFuze.arm(st,{},result); check(st.fuze_due_age_s<0,"non-arming contact leaves clock unset")
	ShellFuze.arm(st,{"entity_id":"first"},{"result":"penetrated","backface":false,"effective_mm":8.0})
	var due := st.fuze_due_age_s
	st.age_s=0.101; ShellFuze.arm(st,{"entity_id":"later"},{"result":"penetrated","backface":false,"effective_mm":50})
	check(st.fuze_due_age_s==due and st.burst_target.entity_id=="first","threshold inclusive; later armor never resets armed delay")

func timing_cases() -> void:
	for dt in [1.0/30,1.0/60,1.0/144,0.001]:
		var st := launch_delayed(); advance_until_done(st,dt)
		check_burst(st,Vector3(0,2,0.2),"step "+str(dt))
	var st := launch_delayed(20,4,300); advance_until_done(st)
	check_burst(st,Vector3(0,2,1.1),"different speed preserves time, changes path")
	for thickness in [5.0,100.0,-1.0]:
		st=launch_delayed(thickness); advance_until_done(st)
		check(st.fuze_due_age_s<0 and st.burst.is_empty(),"thin/blocked/unknown armor cannot trigger: "+str(thickness))
	st=launch_delayed(20,0.4); advance_until_done(st)
	check_burst(st,Vector3(0,2,-1.6),"exits before delay")
	check(st.burst.get("external",false) and st.contacts.size()>=2,"exit armor does not cancel armed clock")
	st=launch_delayed(20,0.4)
	target.damage_layout_override.armor_patches[5].thickness_mm=100
	advance_until_done(st)
	check_burst(st,Vector3(0,2,-0.2),"armed projectile arrested by rear armor")
	check(st.fuze_resting and st.velocity_world==Vector3.ZERO and st.burst.stop_reason=="armor_stopped","stopped body retains independent delayed effect")
	var slow_policy := policy.duplicate(true); slow_policy.delay_s=0.05
	st=launch_delayed(20,0.4,600,{"fuze_policy":slow_policy,"gravity_world":Vector3.DOWN})
	target.damage_layout_override.armor_patches[5].thickness_mm=100
	manager.advance_projectile(st,0.01,snapshots(),world.get_world_3d().direct_space_state)
	var net_world := NetworkBattleWorld.new(); net_world.projectiles=manager
	var active := net_world.active_projectiles(); net_world.free()
	check(st.fuze_resting and not st.is_terminal() and active.size()==1 and active[0].gravity==[0.0,0.0,0.0] and st.gravity_world==Vector3.DOWN,"network waiting pose has zero acceleration while launch gravity remains frozen")
	advance_until_done(st)
	st=launch_delayed()
	var layout := target.damage_layout_override.duplicate(true) as VehicleLayoutDefinition
	var module := ModuleVolumeDefinition.new(); module.id="stopper"; module.kind="engine"; module.part_id="hull"
	module.local_box_transform.origin=Vector3(0,2,1); module.size_m=Vector3.ONE; module.resistance_mm=100
	layout.modules.append(module); target.set_damage_layout(layout); advance_until_done(st)
	check_burst(st,Vector3(0,2,1.5),"armed projectile arrested by internal module")
	check(st.fuze_resting and st.burst.stop_reason=="damage_budget_exhausted","actual module transaction stops body without cancelling fuze")
	var record: Dictionary=manager.shot_records.get_record(manager.shot_records.count()-1)
	for field in ["due_age_s","armed_age_s"]:
		var bad := record.duplicate(true); bad.burst.fuze[field]+=0.01
		check(not ShotRecordBuilder.validate(bad).ok,"replay rejects corrupted "+field)
	st=launch_delayed(20,4,600,{"max_age_s":0.005}); advance_until_done(st)
	check(st.terminal_reason=="expired_time" and st.burst.is_empty(),"lifetime before fuze prevents late detonation")
	st=launch_delayed(20,4,600,{"max_distance_m":3.0}); advance_until_done(st)
	check(st.terminal_reason=="expired_distance" and st.burst.is_empty(),"range before fuze prevents late detonation")
	st=launch_delayed(); manager.advance_projectile(st,0.004,snapshots(),world.get_world_3d().direct_space_state)
	check(st.fuze_due_age_s>st.age_s,"clock armed across physics steps")
	var age := st.age_s
	manager.advance_projectile(st,0.0,snapshots(),world.get_world_3d().direct_space_state)
	check(st.age_s==age and st.burst.is_empty() and not st.is_terminal(),"zero simulation time neither advances nor expires active fuze")
	manager.cancel_all("cancelled_test")
	advance_until_done(st); check(st.burst.is_empty(),"cancelled projectile never detonates later")
	st=launch_delayed(); manager.advance_projectile(st,0.004,snapshots(),world.get_world_3d().direct_space_state)
	manager.advance_projectile(st,0.003,[],world.get_world_3d().direct_space_state)
	check(st.is_terminal() and not st.burst.is_empty() and st.burst.external,"target removal does not erase independent timer")
	record=manager.shot_records.get_record(manager.shot_records.count()-1)
	check(not record.is_empty() and ShotRecordBuilder.validate(record).ok,"removed target detonation has valid replay without invented geometry")

func external_cases() -> void:
	var st := launch_delayed(20,0.4); add_exterior_module(); advance_until_done(st)
	replay_sample=manager.shot_records.get_record(manager.shot_records.count()-1).duplicate(true)
	check(st.damage_records.size()>0 and st.fragments.size()==12,"external burst damages real off-axis external module")
	for damage in st.damage_records: check(damage.get("fragment_id",-1)>=0,"external damage comes from traced fragment")
	var blocker := StaticBody3D.new(); blocker.collision_layer=GameConfig.LAYER_WORLD; blocker.collision_mask=0
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size=Vector3(0.2,5,7); shape.shape=box
	blocker.add_child(shape); world.add_child(blocker); blocker.global_position=target.tank.global_transform*Vector3(0.7,2,-1.6)
	await physics_frame; await physics_frame
	st=launch_delayed(20,0.4); add_exterior_module(); advance_until_done(st)
	check(st.damage_records.is_empty(),"real wall blocks external fragment damage")
	var walls := 0
	for fragment in st.fragments:
		if fragment.reason=="world": walls+=1
	check(walls>0,"external fragment rays record actual world contact")
	blocker.queue_free(); await physics_frame; await physics_frame
	blocker=StaticBody3D.new(); blocker.collision_layer=GameConfig.LAYER_WORLD; blocker.collision_mask=0
	shape=CollisionShape3D.new(); box=BoxShape3D.new(); box.size=Vector3(5,5,0.2); shape.shape=box
	blocker.add_child(shape); world.add_child(blocker); blocker.global_position=target.tank.global_transform*Vector3(0,2,1)
	await physics_frame; await physics_frame
	st=launch_delayed(); advance_until_done(st)
	check_burst(st,Vector3(0,2,1.1),"armed projectile arrested by world")
	check(st.fuze_resting and st.burst.stop_reason=="impact_world","world stop preserves independent timer")
	blocker.queue_free(); await physics_frame; await physics_frame

func natural_pause_case() -> void:
	var mutable := policy.duplicate(true); mutable.delay_s=0.15
	var st := launch_delayed(20,4,600,{"fuze_policy":mutable,"max_age_s":0.3})
	mutable.delay_s=0.9
	check(st.fuze_policy.delay_s==0.15,"accepted launch owns a frozen independent fuze policy")
	manager.snapshot_provider=Callable(self,"snapshots"); manager.set_physics_process(true)
	for i in 4: await physics_frame
	check(st.fuze_due_age_s>st.age_s and st.fuze_due_age_s>=0,"natural physics arms delayed round")
	paused=true
	var age := st.age_s
	for i in 6: await physics_frame
	check(st.age_s==age and st.burst.is_empty(),"actual SceneTree pause freezes active fuze")
	paused=false
	for i in 24:
		await physics_frame
		if st.is_terminal(): break
	check(not st.burst.is_empty() and absf(st.burst.time_s-st.fuze_armed_age_s-0.15)<1e-7,"natural resume detonates once at original simulation deadline")
	manager.set_physics_process(false)

func presentation_case() -> void:
	var before := target.state.damage_snapshot()
	var host := Control.new(); root.add_child(host); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); host.add_child(background); background.color=Color("17232d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new(); host.add_child(title); title.position=Vector2(30,20)
	title.text="APHE / delayed detonation - actual recorded fragment paths"; title.add_theme_font_size_override("font_size",22)
	var replay := ReplayView.new(); host.add_child(replay)
	check(replay.present(replay_sample,false).ok,"production replay opens actual exterior detonation")
	replay.playing=false; replay.seek(float(replay_sample.terminal.flight_time_s))
	check(replay._burst_dot.visible and replay._fragments.mesh!=null,"production replay renders actual burst and traced fragments")
	check(target.state.damage_snapshot()==before,"replay presentation cannot repeat damage transactions")
	var args := OS.get_cmdline_user_args(); var index := args.find("--fuze-capture-dir")
	if index>=0 and index+1<args.size():
		check(DisplayServer.get_name()!="headless","capture requires real window renderer")
		if DisplayServer.get_name()!="headless":
			replay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); replay.position=Vector2(30,70); replay.size=Vector2(1060,580)
			(replay.viewport.get_parent() as SubViewportContainer).custom_minimum_size=Vector2(960,400)
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			var directory: String=args[index+1]; DirAccess.make_dir_recursive_absolute(directory)
			var picture := root.get_texture().get_image()
			check(picture!=null and not picture.is_empty() and picture.save_png(directory.path_join("delayed_external_replay.png"))==OK,"actual rendered replay screenshot saved")
	host.queue_free(); await process_frame

func _run() -> void:
	world=Node3D.new(); root.add_child(world)
	var defs:=VehicleDefs.new(); check(defs.load_defaults().ok,"definitions load")
	target=VehicleActor.new(); world.add_child(target)
	check(target.setup(defs,"player_tank","target",2,Transform3D(Basis.IDENTITY,Vector3(0,10,-20)),4,null).ok,"real target loads")
	target.set_physics_process(false); target.tank.set_physics_process(false)
	manager=ProjectileManager.new(); manager.presentation_enabled=false; world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler=Callable(self,"apply_damage")
	await physics_frame
	validation_cases(); timing_cases(); await external_cases(); await natural_pause_case()
	await presentation_case()
	world.queue_free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("FUZE_CHECKS_PASS" if failed==0 else "FUZE_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
