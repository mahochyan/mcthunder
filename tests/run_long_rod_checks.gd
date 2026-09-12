extends "res://tests/run_material_response_checks.gd"
const RodFixture=preload("res://tests/fixtures/long_rod_profile.gd")

func rod_response(thickness: float, angle: float, power: float, caliber: float = 120.0, material: String = "rolled") -> Dictionary:
	var event := _contact(thickness,angle); event.material_kind=material
	return ArmorResolver.resolve(event,Vector3.FORWARD,{"base_mm":power,"impact_profile":RodFixture.profile(),"caliber_mm":caliber,"effect_policy":"long_rod"})

func rod_spawn(power: float, rules: Dictionary = {}, curve: PackedVector2Array = PackedVector2Array()) -> ProjectileState:
	shot+=1
	var result := mgr.try_spawn({"round_id":1202,"shooter_id":"test","shot_id":shot,"shell_id":"test_long_rod",
		"position_world":Vector3(0,20,0),"velocity_world":Vector3(0,0,-1200),"gravity_world":Vector3.ZERO,
		"max_age_s":1.0,"max_distance_m":10.0,"penetration_curve":PackedVector2Array([Vector2(0,power)]) if curve.is_empty() else curve,
		"impact_profile":RodFixture.profile() if rules.is_empty() else rules,"caliber_mm":120,"effect_policy":"long_rod"})
	_ok(result.ok,"long rod accepted by actual projectile manager")
	return mgr.get_projectile_state(result.projectile_id)

func _run() -> void:
	world=Node3D.new(); root.add_child(world)
	mgr=ProjectileManager.new(); mgr.presentation_enabled=false; world.add_child(mgr); mgr.set_physics_process(false)
	await physics_frame
	for example in [[0,40.0],[30,48.0],[45,56.0],[60,64.0]]:
		var result := rod_response(40,example[0],100)
		_ok(result.result=="penetrated" and _near(result.effective_mm,example[1]),"independent authored angle resistance at "+str(example[0]))
		_ok(not result.overmatch and _near(result.adjusted_angle_deg,example[0]),"long rod never borrows full-bore normalization")
	var angled := rod_response(40,60,70)
	_ok(_near(angled.after_mm,6) and _near(angled.path_thickness_mm,80),"64 game resistance stays separate from80 geometric LOS")
	for power in [63,64,65]:
		_ok(rod_response(40,60,power).result=={63:"stopped",64:"perforated_stop",65:"penetrated"}[power],"three outcomes at same actual sloped plate: "+str(power))
	_ok(rod_response(40,0,39,120,"cast").result=="penetrated","explicit material coefficient applies to long rod")
	for caliber in [20,120,125,300]:
		_ok(rod_response(1,83,1000,caliber).result=="ricochet","weapon bore cannot create overmatch: "+str(caliber))
	_ok(rod_response(40,90,1000).result=="grazing_unresolved","grazing does not extrapolate a finite plate hit")
	_ok(rod_response(40,0,1000,120,"unknown").result=="unknown_material","unknown material is still unavailable")
	_ok(rod_response(-1,0,1000).result=="unknown_armor","unknown thickness is still unavailable")
	var rod := RodFixture.profile()
	for invalid in [{},rod.merged({"normalization_deg":0},true),rod.merged({"overmatch_ratio":0},true),
		rod.merged({"angle_resistance_curve":[[0,1],[30,2],[90,1]]},true),rod.merged({"angle_resistance_curve":[[0,1],[60,2]]},true),
		rod.merged({"angle_resistance_curve":[[0,1],[0,2],[90,4]]},true),rod.merged({"angle_resistance_curve":[[0,1],[90,INF]]},true),
		rod.merged({"angle_resistance_curve":[[0,1],null]},true),rod.merged({"family":"AP"},true)]:
		_ok(not ArmorImpactProfile.validate(invalid,"long_rod").is_empty(),"reject incomplete/mixed modern response")
	_ok(not ArmorImpactProfile.validate(rod,"kinetic").is_empty(),"APFSDS cannot silently become AP")
	_ok(not ArmorImpactProfile.validate(rod,"internal_burst").is_empty(),"APFSDS cannot silently become APHE")
	for specs in [[{"thickness":40,"angle":60}],[{"thickness":40},{"thickness":40,"distance":2}],[{"thickness":1,"angle":83}]]:
		_clear(); var st := rod_spawn(70)
		var materials: Array=[]
		for _spec in specs: materials.append("rolled")
		_step(st,material_plates(specs,materials))
		if specs.size()==2:
			_ok(st.terminal_reason=="armor_stopped" and st.contacts.size()==2 and _near(st.contacts[1].before_mm,30),"two real separated plates retain cumulative residual budget")
		elif specs[0].angle==60:
			_ok(st.contacts.size()==1 and st.contacts[0].result=="penetrated" and _near(st.contacts[0].after_mm,6),"real moving long rod penetrates sloped geometry")
		else:
			_ok(st.ricochets==1 and st.position_world.x>0.1,"actual high-angle long rod follows reflected trajectory")
		var record := mgr.shot_records.get_record(mgr.shot_records.count()-1)
		_ok(not record.is_empty() and ShotRecordBuilder.validate(record).ok,"actual complete long-rod replay validates")
		if record.is_empty(): continue
		_ok(record.rules_versions.impact==ArmorImpactProfile.LONG_ROD_VERSION and record.launch.effect_policy=="long_rod","record retains exact new effect and version")
		var bad := record.duplicate(true); bad.rules_versions.impact=ArmorImpactProfile.VERSION
		_ok(not ShotRecordBuilder.validate(bad).ok,"reject modern record labeled as old full-caliber rules")
		bad=record.duplicate(true); bad.contacts[0].angle_multiplier+=0.5
		_ok(not ShotRecordBuilder.validate(bad).ok,"replay independently catches changed angular resistance")
		_ok(st.burst.is_empty() and st.fragments.is_empty(),"kinetic long rod cannot create APHE sphere burst")
	_clear(); var mutable := RodFixture.profile(); var st := rod_spawn(70,mutable)
	mutable.angle_resistance_curve[2][1]=3.0
	_step(st,material_plates([{"thickness":40,"angle":60}],["rolled"]))
	_ok(st.contacts[0].result=="penetrated" and _near(st.contacts[0].effective_mm,64),"launch freezes nested modern angle curve")
	_clear(); st=rod_spawn(70,{},PackedVector2Array([Vector2(0,70),Vector2(10,20)]))
	_step(st,material_plates([{"thickness":40},{"thickness":25,"distance":2}],["rolled","rolled"]))
	_ok(st.terminal_reason=="armor_stopped" and _near(st.contacts[0].before_mm,65) and _near(st.contacts[1].before_mm,20),"long-rod distance loss and already consumed armor budget remain cumulative")
	world.queue_free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("LONG_ROD_CHECKS_PASS" if failed==0 else "LONG_ROD_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
