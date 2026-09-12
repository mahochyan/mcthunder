extends "res://tests/run_shell_checks.gd"
const RodFixture=preload("res://tests/fixtures/long_rod_profile.gd")
const SpallFixture=preload("res://tests/fixtures/spall_profile.gd")
var replay_sample: Dictionary={}

func compartment(thickness: float = 20, internals: bool = true) -> VehicleLayoutDefinition:
	var layout := ShellTrainingTargets.build(thickness,4.0,internals)
	for patch in layout.armor_patches: patch.material_kind="rolled"
	return layout

func launch_spall(layout: VehicleLayoutDefinition, post: Variant = null, power: float = 100.0) -> ProjectileState:
	manager.cancel_all("cancelled_spall_fixture"); target.set_damage_layout(layout); shot+=1
	var result := manager.try_spawn({"round_id":1312,"shooter_id":"fixture","shooter_life_id":1,"shot_id":shot,"shell_id":"test_long_rod_spall",
		"effect_policy":"long_rod","impact_profile":RodFixture.profile(),"post_penetration_profile":SpallFixture.profile() if post==null else post,"caliber_mm":120,
		"penetration_curve":PackedVector2Array([Vector2(0,power)]),"seed":2101,
		"position_world":target.tank.global_transform*Vector3(0,2,4),"velocity_world":Vector3(0,0,-1200),
		"gravity_world":Vector3.ZERO,"max_age_s":1.0,"max_distance_m":20.0})
	check(result.ok,"actual manager accepts explicit long-rod spall fixture")
	return manager.get_projectile_state(result.projectile_id)

func complete(st: ProjectileState) -> void:
	for i in 5:
		if st.is_terminal(): break
		manager.advance_projectile(st,1.0/60.0,snapshots(),world.get_world_3d().direct_space_state)
	check(st.is_terminal(),"actual finite shot reaches terminal")

func record_for(st: ProjectileState) -> Dictionary:
	var record := manager.shot_records.get_record(manager.shot_records.count()-1)
	check(not record.is_empty() and ShotRecordBuilder.validate(record).ok,"actual spall replay is complete and valid")
	if record.is_empty(): print("[DETAIL] ",ShotRecordBuilder.validate(ShotRecordBuilder.freeze(st,{"reason":st.terminal_reason,"flight_time_s":st.age_s,"impact_point":st.position_world})))
	return record

func add_plate(layout: VehicleLayoutDefinition, z: float, thickness: float, id: String) -> void:
	var patch: ArmorPatchDefinition=ArmorTrainingTargets.build([{"id":id,"center":Vector3(0,2,z),"thickness":thickness}]).layout.armor_patches[0]
	patch.material_kind="rolled"; layout.armor_patches.append(patch)

func spall_runtime_cases() -> void:
	var st := launch_spall(compartment(),{}); complete(st)
	check(st.damage_records.is_empty() and st.spall_events.is_empty(),"plain rod misses all real off-axis modules without spall")
	st=launch_spall(compartment()); complete(st)
	check(st.spall_events.size()==1 and st.fragments.size()==6 and st.burst.is_empty(),"one inward front penetration emits6 directional fragments; exit creates no APHE burst")
	check(st.damage_records.size()>0,"real directional traces damage off-axis internal modules")
	var fragments_only := true
	for event in st.damage_records:
		if event.fragment_id<0: fragments_only=false
	check(fragments_only,"all off-axis damage comes from actual fragment paths, not mother rod")
	check(st.contacts.size()==2 and is_equal_approx(st.spall_events[0].allocated_mm,24.0) and is_equal_approx(st.contacts[1].before_mm,56.0),"front100-20 splits24 to fragments, mother reaches rear with56")
	check(st.travelled_m>6 and st.terminal_reason=="expired_distance","spall does not end mother flight")
	replay_sample=record_for(st)
	var first_directions: Array=[]
	for fragment in st.fragments:
		first_directions.append(fragment.direction)
		check(fragment.direction.dot(Vector3.FORWARD)>=cos(deg_to_rad(25.0)),"every seeded fragment stays inside authored forward cone")
	st=launch_spall(compartment()); complete(st)
	var repeat: Array=[]
	for fragment in st.fragments: repeat.append(fragment.direction)
	check(repeat==first_directions,"same shot seed reproduces real directions after reset")
	for thickness in [100.0,110.0,-1.0]:
		st=launch_spall(compartment(thickness)); complete(st)
		check(st.spall_events.is_empty() and st.fragments.is_empty() and st.damage_records.is_empty(),"stopped/equal/unknown armor cannot emit internal spall: "+str(thickness))
	var unknown := compartment(); unknown.armor_patches[4].material_kind="unknown"
	st=launch_spall(unknown); complete(st)
	check(st.spall_events.is_empty() and st.terminal_reason=="armor_unknown_material","unknown front material cannot authorize spall")
	var mutable := SpallFixture.profile(); st=launch_spall(compartment(),mutable); mutable.count=1; mutable.fragment_impact_profile.material_coefficients.rolled=9.0
	complete(st); check(st.fragments.size()==6 and st.post_penetration_profile.fragment_impact_profile.material_coefficients.rolled==1.0,"accepted launch freezes full nested spall profile")
	var layered := compartment(10,false)
	for i in 5: add_plate(layered,1.5-float(i)*0.5,1.0,"layer_"+str(i))
	st=launch_spall(layered,SpallFixture.profile(),160); complete(st)
	check(st.spall_events.size()==4 and st.fragments.size()==24,"multi-layer mother shot observes4-batch limit and global24 fragment IDs")
	var sequential := true
	for i in st.fragments.size():
		if st.fragments[i].id!=i: sequential=false
	check(sequential and st.fragments[0].direction!=st.fragments[6].direction,"global IDs remain unique and second batch has its own seeded directions")
	record_for(st)
	var shielded := compartment(); add_plate(shielded,1.7,10.0,"inner_shield")
	st=launch_spall(shielded); complete(st)
	var first_blocked := true
	for i in 6:
		if st.fragments[i].reason!="armor_stopped" or not st.fragments[i].damage_indices.is_empty(): first_blocked=false
	check(first_blocked,"actual inner armor stops every first-batch fragment before off-axis modules")
	record_for(st)

func blocked_and_cancel_cases() -> void:
	var obstacle := TerrainFixtures.box(world,target.tank.global_transform*Vector3(0,2,1.7),Vector3(3.9,2.9,0.1))
	await physics_frame
	var st := launch_spall(compartment()); complete(st)
	var stopped := true
	for fragment in st.fragments:
		if fragment.reason!="world": stopped=false
	check(stopped and st.damage_records.is_empty() and st.terminal_reason=="impact_world","actual world wall blocks mother and spall without internal damage")
	record_for(st)
	obstacle.queue_free(); await physics_frame
	manager.contact_policy=func(_identity: Dictionary,event: Dictionary) -> Dictionary:
		return {"allow":event.get("kind")!="module","reason":"test_team_protection"}
	st=launch_spall(compartment()); complete(st)
	check(st.damage_records.is_empty(),"fragment damage respects actual match contact policy")
	manager.contact_policy=Callable()
	var cancel := func(_event: Dictionary) -> void:
		manager.cancel_all("cancelled_spall_callback"); target.reset_vehicle()
	manager.projectile_damage.connect(cancel)
	st=launch_spall(compartment()); complete(st)
	check(st.terminal_reason=="cancelled_spall_callback" and st.damage_records.size()==1 and st.fragments.size()<6,"first damage callback cancellation stops remaining fragments and mother")
	var restored := true
	for module in target.state.module_states.values():
		if module.integrity!=module.max_integrity: restored=false
	check(restored and manager.active_count()==0,"callback reset restores target without late damage")
	manager.projectile_damage.disconnect(cancel)

func validation_cases() -> void:
	var profile := SpallFixture.profile()
	for bad in [null,[],profile.merged({"count":9},true),profile.merged({"budget_fraction":1},true),profile.merged({"cone_deg":INF},true),
		profile.merged({"fragment_impact_profile":{}},true),profile.merged({"fragment_impact_profile":RodFixture.profile()},true),profile.merged({"provenance":"verified"},true)]:
		check(not SpallProfile.validate(bad,"long_rod").is_empty(),"reject invalid/mixed spall policy")
	check(not SpallProfile.validate(profile,"internal_burst").is_empty(),"APHE cannot acquire long-rod split policy")
	if replay_sample.is_empty(): return
	for defect in ["budget","origin","direction","link","version","frame","family","missing_fragment"]:
		var bad := replay_sample.duplicate(true)
		match defect:
			"budget": bad.spall_events[0].allocated_mm+=1
			"origin": bad.spall_events[0].point_world+=Vector3.RIGHT
			"direction": bad.fragments[0].direction=Vector3.BACK
			"link": bad.fragments[0].spall_event_id=1
			"version": bad.rules_versions.post_penetration="future"
			"frame": bad.spall_events[0].geometry_frame+=1
			"family": bad.launch.effect_policy="internal_burst"
			"missing_fragment": bad.fragments.pop_back(); bad.spall_events[0].fragment_count-=1
		check(not ShotRecordBuilder.validate(bad).ok,"reject inconsistent spall replay: "+defect)

func presentation_case() -> void:
	if replay_sample.is_empty(): return
	var before := target.state.damage_snapshot()
	var host := Control.new(); root.add_child(host); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); host.add_child(background); background.color=Color("17232d"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new(); host.add_child(label); label.position=Vector2(30,20)
	label.text="APFSDS: actual directional spall / TEST ONLY game rules"; label.add_theme_font_size_override("font_size",22)
	var replay := ReplayView.new(); host.add_child(replay)
	check(replay.present(replay_sample,false).ok,"production replay opens actual directional-spall shot")
	replay.playing=false; replay.seek(0.0)
	check(replay._fragments.mesh==null and not replay._burst_dot.visible,"replay hides unborn spall and never displays APHE burst dot")
	replay.seek(float(replay_sample.terminal.flight_time_s))
	check(replay._fragments.mesh!=null and not replay._burst_dot.visible,"production replay renders actual spall paths after their source contact")
	check(target.state.damage_snapshot()==before,"seeking spall replay never repeats live damage")
	var args := OS.get_cmdline_user_args(); var index := args.find("--spall-capture-dir")
	if index<0: index=args.find("--shot-dir")
	if index>=0 and index+1<args.size():
		check(DisplayServer.get_name()!="headless","capture requires real window renderer")
		if DisplayServer.get_name()!="headless":
			replay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); replay.position=Vector2(30,70); replay.size=Vector2(1060,580)
			(replay.viewport.get_parent() as SubViewportContainer).custom_minimum_size=Vector2(960,400)
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			var directory: String=args[index+1]; DirAccess.make_dir_recursive_absolute(directory)
			var picture := root.get_texture().get_image()
			check(picture!=null and not picture.is_empty() and picture.save_png(directory.path_join("directional_spall_replay.png"))==OK,"actual spall replay screenshot saved")
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
	spall_runtime_cases(); await blocked_and_cancel_cases(); validation_cases()
	await presentation_case()
	world.queue_free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("SPALL_CHECKS_PASS" if failed==0 else "SPALL_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
