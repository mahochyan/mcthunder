extends "res://tests/run_fuze_checks.gd"
## Actual APHE flight and fragments, then corrupted copies of the immutable records.
var impact := {"version":"wt012-full-caliber-v1","family":"APHE","normalization_deg":2.0,
	"overmatch_ratio":3.0,"ricochet_deg":75.0,"material_coefficients":{"rolled":1.0,"cast":0.95},
	"provenance":"game_rule","reason":"TEST ONLY replay response"}

func material_record(material: String, thickness: float = 20.0) -> Dictionary:
	var st := launch_delayed(thickness,4,600,{"impact_profile":impact,"caliber_mm":75})
	for patch in target.damage_layout_override.armor_patches: patch.material_kind=material
	advance_until_done(st)
	var record := manager.shot_records.get_record(manager.shot_records.count()-1)
	check(not record.is_empty() and ShotRecordBuilder.validate(record).ok,"actual profiled APHE record accepted: "+material+" "+str(thickness))
	return record

func replay_cases() -> void:
	var record := material_record("cast")
	replay_sample=record
	check(record.rules_versions.impact==ArmorImpactProfile.VERSION and record.rules_versions.armor==GameConfig.ARMOR_RULES_VERSION,"new impact identity coexists with preserved legacy armor version")
	for key in ["effective_mm","path_thickness_mm","adjusted_angle_deg","material_multiplier","angle_deg","after_mm"]:
		var bad := record.duplicate(true); bad.contacts[0][key]+=0.3
		check(not ShotRecordBuilder.validate(bad).ok,"replay rejects altered contact "+key)
	for defect in ["material","patch_material","profile","overmatch","unit","version","missing_profile","nonfinite","normal","surface"]:
		var bad := record.duplicate(true)
		match defect:
			"material": bad.contacts[0].material_kind="rolled"
			"patch_material": bad.frames[0].patches[4].material_kind="rolled"
			"profile": bad.launch.impact_profile.material_coefficients.cast=1.0
			"overmatch": bad.contacts[0].overmatch=not bad.contacts[0].overmatch
			"unit": bad.contacts[0].budget_unit="historical_mm"
			"version": bad.rules_versions.impact="future"
			"missing_profile": bad.launch.erase("impact_profile")
			"nonfinite": bad.contacts[0].path_thickness_mm=INF
			"normal": bad.contacts[0].normal_world=Vector3(NAN,0,0)
			"surface": bad.contacts[0].surface_id="missing"
		check(not ShotRecordBuilder.validate(bad).ok,"replay rejects inconsistent "+defect)
	var selected := -1
	for i in record.fragments.size():
		if not record.fragments[i].contacts.is_empty(): selected=i; break
	check(selected>=0,"real burst records actual fragment armor contact")
	if selected>=0:
		for key in ["effective_mm","adjusted_angle_deg","material_multiplier","path_thickness_mm"]:
			var bad := record.duplicate(true); bad.fragments[selected].contacts[0][key]+=0.3
			check(not ShotRecordBuilder.validate(bad).ok,"fragment replay rejects altered "+key)
		var bad := record.duplicate(true); bad.fragments[selected].contacts[0].overmatch=true
		check(not ShotRecordBuilder.validate(bad).ok,"fragment cannot acquire parent overmatch in replay")
	for pair in [["rolled",20.0],["unknown",20.0],["cast",-1.0],["cast",0.0]]:
		material_record(pair[0],pair[1])
	var st := launch_delayed(); advance_until_done(st)
	var legacy := manager.shot_records.get_record(manager.shot_records.count()-1).duplicate(true)
	legacy.launch.erase("impact_profile"); legacy.launch.erase("caliber_mm")
	check(ShotRecordBuilder.validate(legacy).ok,"legacy record without optional fields remains compatible")

func material_presentation() -> void:
	var args := OS.get_cmdline_user_args(); var index := args.find("--material-capture-dir")
	if index<0 or index+1>=args.size(): return
	check(DisplayServer.get_name()!="headless","material presentation uses actual window renderer")
	if DisplayServer.get_name()=="headless": return
	root.size=Vector2i(1280,720)
	var before := target.state.damage_snapshot()
	var host := Control.new(); root.add_child(host); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); host.add_child(background); background.color=Color("17232d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var explanation := Label.new(); host.add_child(explanation); explanation.position=Vector2(30,15)
	explanation.size=Vector2(1200,130); explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	explanation.text=ShotExplanation.describe(replay_sample,null)
	CoreUI.apply(host)
	var replay := ReplayView.new(); host.add_child(replay)
	check(replay.present(replay_sample,false).ok,"production replay opens profiled material shot")
	replay.playing=false; replay.seek(float(replay_sample.terminal.flight_time_s))
	replay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); replay.position=Vector2(30,150); replay.size=Vector2(1160,550)
	(replay.viewport.get_parent() as SubViewportContainer).custom_minimum_size=Vector2(1000,350)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var directory: String=args[index+1]; DirAccess.make_dir_recursive_absolute(directory)
	var picture := root.get_texture().get_image()
	check(picture!=null and not picture.is_empty() and picture.save_png(directory.path_join("material_replay.png"))==OK,"actual material explanation and replay screenshot saved")
	check(target.state.damage_snapshot()==before,"material replay presentation never repeats damage")
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
	replay_cases()
	await material_presentation()
	world.queue_free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("MATERIAL_REPLAY_CHECKS_PASS" if failed==0 else "MATERIAL_REPLAY_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
