extends "res://tests/run_armor_checks.gd"
## TEST ONLY full-caliber response and actual separated plate contacts.
var profile := {"version":"wt012-full-caliber-v1","family":"AP","normalization_deg":4.0,
	"overmatch_ratio":3.0,"ricochet_deg":75.0,"material_coefficients":{"rolled":1.0,"cast":0.95},
	"provenance":"game_rule","reason":"TEST ONLY response constants"}

func response(thickness: float, angle: float, power: float, material: String = "rolled", caliber: float = 75.0, policy: Dictionary = {}) -> Dictionary:
	var event := _contact(thickness,angle); event.material_kind=material
	var selected := profile if policy.is_empty() else policy
	return ArmorResolver.resolve(event,Vector3.FORWARD,{"base_mm":power,"impact_profile":selected,"caliber_mm":caliber,
		"effect_policy":"internal_burst" if selected.family=="APHE" else "kinetic","fragment":selected.family=="fragment"})

func numeric_cases() -> void:
	var r := response(40,0,39)
	_ok(r.result=="stopped" and _near(r.effective_mm,40),"rolled plate consumes independent game RHA budget")
	r=response(40,0,39,"cast")
	_ok(r.result=="penetrated" and _near(r.effective_mm,38) and _near(r.after_mm,1),"same 40mm cast plate has explicit 38mm game resistance")
	_ok(_near(r.path_thickness_mm,40) and r.budget_unit==ArmorImpactProfile.UNIT,"geometric LOS remains separate from material budget")
	r=response(40,60,74)
	_ok(r.result=="penetrated" and _near(r.effective_mm,71.531665998856) and _near(r.path_thickness_mm,80),"AP angle response matches independent 40/cos56 constant, geometric path remains80")
	var aphe := profile.duplicate(true); aphe.family="APHE"; aphe.normalization_deg=2.0
	r=response(40,60,74,"rolled",75,aphe)
	_ok(r.result=="stopped" and _near(r.effective_mm,75.483196591994),"APHE separate angle response matches independent 40/cos58 constant")
	for caliber in [74.9,75.0,75.1]:
		r=response(25,78,1000,"rolled",caliber)
		_ok(r.result==("ricochet" if caliber<75 else "penetrated"),"diameter/nominal plate threshold: "+str(caliber))
	r=response(40,78,1000,"rolled",75)
	_ok(r.result=="ricochet" and r.adjusted_angle_deg<75,"ricochet uses actual incidence before resistance normalization")
	r=response(40,78,1000,"unknown")
	_ok(r.result=="unknown_material" and r.after_mm==1000 and not r.continue_flight,"unknown material cannot borrow rolled resistance or trigger ricochet")
	_ok(response(-1,0,100,"rolled").result=="unknown_armor","known material cannot fill unknown thickness")
	_ok(response(40,90,100).result=="grazing_unresolved","exact grazing retains bounded unresolved result")
	var fragment := ArmorImpactProfile.fragment_profile(profile)
	r=response(1,78,1000,"rolled",75,fragment)
	_ok(r.result=="ricochet" and not r.overmatch and _near(r.adjusted_angle_deg,78),"fragments do not inherit parent caliber or normalization")
	var fuze_state := ProjectileState.new(); fuze_state.age_s=0.1
	fuze_state.fuze_policy={"arming_thickness_mm":39.0,"delay_s":0.003}
	ShellFuze.arm(fuze_state,{"entity_id":"test"},response(40,0,100,"cast",75,aphe))
	_ok(fuze_state.fuze_due_age_s>0,"fuze threshold reads actual40mm path, not cast38mm budget")
	for invalid in [null,[],profile.merged({"family":"APFSDS"},true),profile.merged({"version":"future"},true),
		profile.merged({"normalization_deg":INF},true),profile.merged({"normalization_deg":-1},true),
		profile.merged({"overmatch_ratio":0.1},true),profile.merged({"ricochet_deg":90},true),
		profile.merged({"material_coefficients":{"rolled":1.0,"cast":0.0}},true),
		profile.merged({"material_coefficients":{"unknown":1.0,"cast":1.0}},true),profile.merged({"provenance":"historical_verified"},true)]:
		_ok(not ArmorImpactProfile.validate(invalid,"kinetic").is_empty(),"invalid profile rejected: "+str(invalid))
		var result := mgr.try_spawn({"round_id":12,"shooter_id":"test","shot_id":999,"shell_id":"test_profile",
			"velocity_world":Vector3.FORWARD,"max_age_s":1,"max_distance_m":10,"penetration_curve":PackedVector2Array([Vector2(0,100)]),
			"impact_profile":invalid,"caliber_mm":75})
		_ok(not result.ok and result.reason=="invalid_impact_profile","invalid profile cannot enter actual manager")
	var budget := {"base_mm":74,"impact_profile":profile.duplicate(true),"caliber_mm":75}
	var original := budget.duplicate(true)
	ArmorResolver.resolve(_contact(20),Vector3.FORWARD,budget)
	_ok(budget==original,"response leaves shared configuration and budget immutable")

func spawn_profile(power: float, selected: Dictionary = {}) -> ProjectileState:
	shot+=1
	var source := profile if selected.is_empty() else selected
	var result := mgr.try_spawn({"round_id":12,"shooter_id":"test","shooter_life_id":1,"shot_id":shot,"shell_id":"test_profile",
		"position_world":Vector3(0,20,0),"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,"max_age_s":1,"max_distance_m":10,
		"penetration_curve":PackedVector2Array([Vector2(0,power)]),"impact_profile":source,"caliber_mm":75})
	_ok(result.ok,"real manager accepts complete response profile")
	return mgr.get_projectile_state(result.projectile_id)

func material_plates(specs: Array, materials: Array) -> Array:
	var result := _plates(specs)
	for i in materials.size(): result[0].layout.armor_patches[i].material_kind=materials[i]
	return result

func runtime_cases() -> void:
	for material in ["rolled","cast","unknown"]:
		_clear()
		var st := spawn_profile(39)
		var snapshots := material_plates([{"thickness":40}],[material]); _step(st,snapshots)
		_ok(st.contacts.size()==1,"same two-triangle plate resolves exactly once: "+material)
		_ok(st.contacts[0].result=={"rolled":"stopped","cast":"penetrated","unknown":"unknown_material"}[material],"actual shot response uses queried material: "+material)
		var record := mgr.shot_records.get_record(mgr.shot_records.count()-1)
		_ok(not record.is_empty() and ShotRecordBuilder.validate(record).ok,"actual material shot replay validates")
		_ok(record.launch.impact_profile==profile and record.launch.caliber_mm==75 and record.frames[0].patches[0].material_kind==material,"replay freezes impact policy, caliber and actual geometry material")
		var explanation := ShotExplanation.describe(record,null)
		_ok(explanation.contains("材质未知") if material=="unknown" else explanation.contains("沿弹道厚度"),"normal explanation distinguishes unknown material and geometric thickness")
	_clear()
	var st := spawn_profile(70)
	_step(st,material_plates([{"thickness":40},{"thickness":40,"distance":2}],["cast","rolled"]))
	_ok(st.contacts.size()==2 and st.terminal_reason=="armor_stopped" and _near(st.contacts[0].after_mm,32) and _near(st.contacts[1].before_mm,32),"separate cast and rolled layers consume one common residual budget in order")
	_clear()
	st=spawn_profile(100)
	_step(st,material_plates([{"thickness":10,"distance":1},{"thickness":10,"distance":1.0001}],["rolled","cast"]))
	_ok(st.contacts.size()==2 and _near(st.consumed_mm,19.5),"submillimeter separate layers retain distinct material costs")
	_clear()
	var mutable := profile.duplicate(true); st=spawn_profile(39,mutable); mutable.material_coefficients.cast=2.0
	_step(st,material_plates([{"thickness":40}],["cast"]))
	_ok(st.contacts[0].result=="penetrated" and st.impact_profile.material_coefficients.cast==0.95,"accepted shot freezes material table against later source edits")
	_clear()
	st=spawn_profile(1000)
	_step(st,material_plates([{"thickness":25,"angle":78}],["rolled"]))
	_ok(st.contacts.size()==1 and st.contacts[0].overmatch and st.ricochets==0,"actual barrel-caliber response bypasses ricochet at exact ratio")
	_clear()
	st=spawn_profile(1000)
	_step(st,material_plates([{"thickness":26,"angle":78}],["rolled"]))
	_ok(st.contacts.size()==1 and not st.contacts[0].overmatch and st.ricochets==1,"slightly thicker actual plate retains reflected trajectory")

func content_and_arming_cases() -> void:
	for id in VehicleCatalog.IDS:
		var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://configs/vehicles/historical/"+id+".json"))
		var layout := HistoricalVehicleGeometry.build(packet)
		var supported := true
		for patch in layout.armor_patches:
			if patch.material_kind not in ["rolled","cast"]: supported=false
		_ok(supported,id+": actual production geometry uses explicit supported material")
	var legacy: VehicleLayoutDefinition = load("res://configs/layouts/test_player_vehicle_layout.tres")
	_ok(legacy.armor_patches[0].material_kind=="unknown" and DamageTrainingLayout.build().armor_patches[0].material_kind=="rolled","unknown source fixture retained; playable damage exercise explicitly authors game rolled steel")
	for plates in [[{"thickness":40}],[{"thickness":20},{"thickness":20}]]:
		_clear(); shot+=1
		var aphe := profile.duplicate(true); aphe.family="APHE"; aphe.normalization_deg=2.0
		var result := mgr.try_spawn({"round_id":12,"shooter_id":"test","shot_id":shot,"shell_id":"arming_material",
			"position_world":Vector3(0,20,0),"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,
			"max_age_s":1.0,"max_distance_m":100.0,"penetration_curve":PackedVector2Array([Vector2(0,100)]),
			"impact_profile":aphe,"caliber_mm":75,"effect_policy":"internal_burst",
			"fuze_policy":{"mode":"penetration_delay","arming_thickness_mm":39.0,"delay_s":0.05,"provenance":"game_rule","reason":"TEST ONLY single plate arming threshold"}})
		_ok(result.ok,"actual manager accepts material and single-plate arming fixture")
		var st := mgr.get_projectile_state(result.projectile_id)
		var materials: Array=[]
		for _plate in plates: materials.append("cast")
		_step(st,material_plates(plates,materials),0.005)
		_ok(st.contacts.size()==plates.size() and st.contacts.back().result=="penetrated","actual APHE traverses all explicit cast plates")
		_ok((st.fuze_due_age_s>=0)==(plates.size()==1),"40mm path arms despite38mm resistance; separated20+20mm never accumulate trigger")
	_clear()

func _run() -> void:
	world=Node3D.new(); root.add_child(world)
	mgr=ProjectileManager.new(); mgr.presentation_enabled=false; world.add_child(mgr); mgr.set_physics_process(false)
	mgr.projectile_finished.connect(func(r: Dictionary) -> void: records.append(r))
	mgr.projectile_contact.connect(func(r: Dictionary) -> void: contacts.append(r))
	await physics_frame
	numeric_cases(); runtime_cases(); content_and_arming_cases()
	world.queue_free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("MATERIAL_RESPONSE_CHECKS_PASS" if failed==0 else "MATERIAL_RESPONSE_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
