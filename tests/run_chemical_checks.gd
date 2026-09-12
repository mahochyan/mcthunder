extends "res://tests/run_shell_checks.gd"
const HeatFixture=preload("res://tests/fixtures/chemical_profile.gd")
var replay_sample: Dictionary={}

func compartment(thickness: float = 20, internal: bool = true) -> VehicleLayoutDefinition:
	var layout := ShellTrainingTargets.build(thickness,4,false)
	for patch in layout.armor_patches: patch.material_kind="rolled"
	if internal:
		var module := ModuleVolumeDefinition.new(); module.id="jet_component"; module.kind="engine"; module.part_id="hull"
		module.local_box_transform.origin=Vector3(0,2,0.5); module.size_m=Vector3(0.5,0.5,0.5); layout.modules.append(module)
	return layout

func launch_chemical(layout: VehicleLayoutDefinition, gap: float = 2, speed: float = 600, overrides: Dictionary = {}) -> ProjectileState:
	manager.cancel_all("cancelled_chemical_fixture"); target.set_damage_layout(layout); shot+=1
	var spec := {"round_id":1313,"shooter_id":"fixture","shooter_life_id":1,"shot_id":shot,"shell_id":"test_heat",
		"effect_policy":"chemical","impact_profile":HeatFixture.impact(),"chemical_profile":HeatFixture.profile(),"caliber_mm":120,
		"penetration_curve":PackedVector2Array([Vector2(0,100),Vector2(1000,100)]),"seed":2101,
		"position_world":target.tank.global_transform*Vector3(0,2,2+gap),"velocity_world":Vector3(0,0,-speed),
		"gravity_world":Vector3.ZERO,"max_age_s":2.0,"max_distance_m":1000.0}
	spec.merge(overrides,true)
	var accepted := manager.try_spawn(spec); check(accepted.ok,"real manager accepts explicit chemical fixture")
	return manager.get_projectile_state(accepted.projectile_id)

func complete(st: ProjectileState) -> void:
	for i in 100:
		if st.is_terminal(): break
		manager.advance_projectile(st,1.0/60.0,snapshots(),world.get_world_3d().direct_space_state)
	check(st.is_terminal(),"finite carrier and terminal ray finish")

func record_for(st: ProjectileState) -> Dictionary:
	var record := manager.shot_records.get_record(manager.shot_records.count()-1)
	check(not record.is_empty() and ShotRecordBuilder.validate(record).ok,"actual chemical shot produces valid complete replay")
	if record.is_empty(): print("[DETAIL] ",ShotRecordBuilder.validate(ShotRecordBuilder.freeze(st,{"reason":st.terminal_reason,"flight_time_s":st.age_s,"impact_point":st.position_world})))
	return record

func chemical_cases() -> void:
	var st := launch_chemical(compartment()); complete(st)
	check(st.terminal_reason=="chemical_detonation" and is_equal_approx(st.travelled_m,2.0) and is_equal_approx(st.age_s,2.0/600.0),"carrier ends at first actual plate and its real flight time")
	check(st.chemical_effect.complete and is_equal_approx(st.chemical_effect.distance_m,3.0) and is_equal_approx(st.chemical_effect.remaining_mm,40.0),"separate100 budget spends20 armor,10 module and30 terminal path loss")
	check(st.contacts.size()==1 and st.contacts[0].effect_channel=="chemical_jet" and st.damage_records.size()==1,"jet resolves actual plate then internal module")
	check(target.state.module_states.jet_component.integrity==0 and not target.capabilities().drive,"actual jet damage disables actual engine propulsion")
	check(st.burst.is_empty() and st.fragments.is_empty() and st.spall_events.is_empty() and st.consumed_mm==0,"chemical terminal path cannot become APHE/spall or reuse carrier kinetic budget")
	replay_sample=record_for(st)
	st=launch_chemical(compartment(),102,300); complete(st)
	check(is_equal_approx(st.contacts[0].before_mm,100) and is_equal_approx(st.chemical_effect.remaining_mm,40) and is_equal_approx(st.age_s,102.0/300.0),"longer slower carrier flight preserves independent chemical budget")
	record_for(st)
	for gap in [1.0,2.0]:
		var layout := compartment(20,false)
		var patch: ArmorPatchDefinition=ArmorTrainingTargets.build([{"center":Vector3(0,2,2-gap),"thickness":20}]).layout.armor_patches[0]
		patch.id="spaced_plate"; patch.material_kind="rolled"; layout.armor_patches.append(patch)
		st=launch_chemical(layout); complete(st)
		check(st.contacts.size()==2 and is_equal_approx(st.contacts[1].before_mm,80-gap*10),"actual inter-plate gap consumes terminal path budget: "+str(gap))
		record_for(st)
	for thickness in [100.0,110.0,-1.0]:
		st=launch_chemical(compartment(thickness)); complete(st)
		check(st.damage_records.is_empty() and target.state.module_states.jet_component.integrity==100,"equal/stopped/unknown front prevents internal jet damage: "+str(thickness))
		record_for(st)
	var unknown := compartment(); unknown.armor_patches[4].material_kind="unknown"
	st=launch_chemical(unknown); complete(st)
	check(st.chemical_effect.reason=="armor_unknown_material" and st.damage_records.is_empty(),"unknown material cannot borrow a chemical steel coefficient")
	for angle in [60,80]:
		var layout: VehicleLayoutDefinition=ArmorTrainingTargets.build([{"center":Vector3(0,2,2),"thickness":40 if angle==60 else 1,"angle":angle}]).layout
		layout.armor_patches[0].material_kind="rolled"
		st=launch_chemical(layout); complete(st)
		check(st.contacts.size()==1 and st.contacts[0].result=="penetrated" and st.ricochets==0,"chemical ray does not inherit kinetic ricochet at angle "+str(angle))
		if angle==60: check(absf(st.contacts[0].effective_mm-80)<0.001,"40mm sloped plate consumes80 chemical game mm without normalization")
		record_for(st)
	var off_axis := compartment(20,false)
	var module := ModuleVolumeDefinition.new(); module.id="off_axis"; module.kind="engine"; module.part_id="hull"
	module.local_box_transform.origin=Vector3(1,2,0.5); module.size_m=Vector3(0.3,0.5,0.5); off_axis.modules.append(module)
	st=launch_chemical(off_axis); complete(st)
	check(st.damage_records.is_empty() and target.state.module_states.off_axis.integrity==100,"narrow jet does not apply radial APHE damage to off-axis module")

func blocking_cases() -> void:
	for z in [3.0,1.5]:
		var obstacle := TerrainFixtures.box(world,target.tank.global_transform*Vector3(0,2,z),Vector3(4,3,0.1))
		await physics_frame
		var st := launch_chemical(compartment()); complete(st)
		check(st.chemical_effect.reason=="world" and st.damage_records.is_empty() and st.contacts.size()==(0 if z>2 else 1),"world wall blocks carrier or post-contact jet at "+str(z))
		record_for(st); obstacle.queue_free(); await physics_frame
	var external := compartment()
	var module := ModuleVolumeDefinition.new(); module.id="external_screen"; module.kind="track"; module.part_id="hull"; module.external=true
	module.local_box_transform.origin=Vector3(0,2,3); module.size_m=Vector3(1,1,0.5); external.modules.append(module)
	var st := launch_chemical(external); complete(st)
	check(st.chemical_effect.trigger_kind=="damage" and st.damage_records[0].item_id=="external_screen" and is_equal_approx(st.damage_records[0].before_mm,100),"real exterior module contact triggers independent jet before hull armor")
	record_for(st)
	manager.contact_policy=func(_identity: Dictionary,event: Dictionary) -> Dictionary:
		return {"allow":event.get("kind")!="module","reason":"test_protection"}
	st=launch_chemical(compartment()); complete(st)
	check(st.damage_records.is_empty(),"jet module damage respects actual match policy")
	manager.contact_policy=Callable()
	var callback := func(_event: Dictionary) -> void:
		manager.cancel_all("cancelled_chemical_callback"); target.reset_vehicle()
	manager.projectile_damage.connect(callback)
	st=launch_chemical(compartment()); complete(st)
	check(st.terminal_reason=="cancelled_chemical_callback" and st.damage_records.size()==1 and target.state.module_states.jet_component.integrity==100,"damage callback stops jet and reset prevents late damage")
	manager.projectile_damage.disconnect(callback)

func profile_cases() -> void:
	var profile := HeatFixture.profile()
	for invalid in [{},null,[],profile.merged({"range_m":0},true),profile.merged({"path_loss_mm_per_m":-1},true),profile.merged({"penetration_mm":INF},true),profile.merged({"provenance":"verified"},true)]:
		check(not ChemicalProfile.validate(invalid,"chemical").is_empty(),"reject missing or invalid chemical profile")
	check(not ChemicalProfile.validate(profile,"internal_burst").is_empty(),"chemical profile cannot be attached to APHE")
	check(not ChemicalProfile.matches_curve(profile,PackedVector2Array([Vector2(0,100),Vector2(100,90)])),"declining carrier distance curve cannot masquerade as chemical budget")
	for invalid in [HeatFixture.impact().merged({"normalization_deg":0},true),HeatFixture.impact().merged({"ricochet_deg":80},true),HeatFixture.impact().merged({"overmatch_ratio":3},true)]:
		check(not ArmorImpactProfile.validate(invalid,"chemical").is_empty(),"chemical response rejects kinetic rules")
	if replay_sample.is_empty(): return
	for defect in ["budget","path","direction","link","time","version","damage_budget","carrier_direction","trigger_frame"]:
		var bad := replay_sample.duplicate(true)
		match defect:
			"budget": bad.chemical_effect.remaining_mm+=1
			"path": bad.chemical_effect.path[-1]+=Vector3.RIGHT
			"direction": bad.chemical_effect.direction=Vector3.BACK
			"link": bad.chemical_effect.damage_indices=[]
			"time": bad.chemical_effect.time_s+=1
			"version": bad.rules_versions.chemical="future"
			"damage_budget": bad.damage[0].before_mm+=1
			"carrier_direction": bad.terminal.impact_velocity=Vector3.RIGHT
			"trigger_frame": bad.chemical_effect.trigger_frame=-1
		check(not ShotRecordBuilder.validate(bad).ok,"reject inconsistent chemical replay: "+defect)

func presentation_case() -> void:
	if replay_sample.is_empty(): return
	var before := target.state.damage_snapshot()
	var host := Control.new(); root.add_child(host); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); host.add_child(background); background.color=Color("17232d"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new(); host.add_child(label); label.position=Vector2(30,20)
	label.text="HEAT: carrier contact / actual bounded jet / TEST ONLY game rules"; label.add_theme_font_size_override("font_size",22)
	var replay := ReplayView.new(); host.add_child(replay)
	check(replay.present(replay_sample,false).ok,"production replay opens actual carrier and jet paths")
	replay.playing=false; replay.seek(0)
	check(replay._fragments.mesh==null,"chemical path hidden before actual trigger time")
	replay.seek(float(replay_sample.terminal.flight_time_s))
	check(replay._fragments.mesh!=null and not replay._burst_dot.visible,"production replay shows jet without APHE sphere burst")
	check(target.state.damage_snapshot()==before,"viewing jet replay never repeats live damage")
	var args := OS.get_cmdline_user_args(); var index := args.find("--shot-dir")
	if index>=0 and index+1<args.size():
		check(DisplayServer.get_name()!="headless","capture requires actual window renderer")
		if DisplayServer.get_name()!="headless":
			replay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); replay.position=Vector2(30,70); replay.size=Vector2(1060,580)
			(replay.viewport.get_parent() as SubViewportContainer).custom_minimum_size=Vector2(960,400)
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			var directory: String=args[index+1]; DirAccess.make_dir_recursive_absolute(directory)
			var picture := root.get_texture().get_image()
			check(picture!=null and not picture.is_empty() and picture.save_png(directory.path_join("chemical_jet_replay.png"))==OK,"actual chemical replay screenshot saved")
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
	chemical_cases(); await blocking_cases(); profile_cases()
	await presentation_case()
	world.queue_free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("CHEMICAL_CHECKS_PASS" if failed==0 else "CHEMICAL_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
