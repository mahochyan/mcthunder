extends "res://tests/run_chemical_checks.gd"
const EraFixture=preload("res://tests/fixtures/reactive_profile.gd")
const RodFixture=preload("res://tests/fixtures/long_rod_profile.gd")
const SpallFixture=preload("res://tests/fixtures/spall_profile.gd")

func era_layout() -> VehicleLayoutDefinition:
	var layout := compartment(); layout.recovery_enabled=true
	layout.armor_patches[4].reactive_profile=EraFixture.profile()
	return layout

func fire_era(layout: VehicleLayoutDefinition = null, rod: bool = false, spall: bool = false) -> ProjectileState:
	manager.cancel_all("cancelled_era_fixture")
	if layout!=null: target.set_damage_layout(layout)
	shot+=1
	var spec := {"round_id":1313,"shooter_id":"fixture","shooter_life_id":1,"shot_id":shot,"shell_id":"test_era_shot",
		"effect_policy":"long_rod" if rod else "chemical","impact_profile":RodFixture.profile() if rod else HeatFixture.impact(),
		"chemical_profile":{} if rod else HeatFixture.profile(),"post_penetration_profile":SpallFixture.profile() if spall else {},"caliber_mm":120,
		"penetration_curve":PackedVector2Array([Vector2(0,100),Vector2(1000,100)]),"seed":2101,
		"position_world":target.tank.global_transform*Vector3(0,2,4),"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,"max_age_s":2.0,"max_distance_m":1000.0}
	var accepted := manager.try_spawn(spec); check(accepted.ok,"real manager admits explicit ERA test shot")
	return manager.get_projectile_state(accepted.projectile_id)

func era_cases() -> void:
	var layout := era_layout(); var tile: String=layout.armor_patches[4].id
	var other := VehicleRuntimeState.new(); other.initialize_damage(layout)
	var first := fire_era(layout)
	var frozen_snapshots := snapshots(); var tick := Engine.get_physics_frames()
	manager.advance_projectile(first,0.05,frozen_snapshots,world.get_world_3d().direct_space_state)
	check(first.is_terminal() and first.contacts.size()==1 and first.contacts[0].result=="stopped","first actual HEAT is stopped by20 passive plus100 reactive resistance")
	check(first.contacts[0].reactive_before==1 and first.contacts[0].reactive_after==0 and target.state.reactive_armor[tile]==0,"actual contact atomically consumes only the struck tile")
	check(first.damage_records.is_empty() and target.state.module_states.jet_component.integrity==100,"first shot leaves real protected engine intact")
	check(other.reactive_armor[tile]==1 and layout.armor_patches[4].reactive_profile==EraFixture.profile(),"same resource on another vehicle retains independent unused charge")
	replay_sample=record_for(first)
	var duplicate := target.apply_projectile_armor(first.contacts[0],Vector3.FORWARD,{"base_mm":100,"impact_profile":HeatFixture.impact(),"effect_policy":"chemical","caliber_mm":120})
	check(not duplicate.ok and target.state.reactive_armor[tile]==0,"duplicate authoritative transaction cannot apply twice")
	var second := fire_era()
	manager.advance_projectile(second,0.05,frozen_snapshots,world.get_world_3d().direct_space_state)
	check(Engine.get_physics_frames()==tick and second.contacts[0].reactive_before==0 and not second.contacts[0].reactive_triggered,"second shot in same physics tick reads live charge despite reused query snapshot")
	check(is_equal_approx(second.contacts[0].effective_mm,20) and second.damage_records.size()==1 and not target.capabilities().drive,"spent ERA retains passive casing while second shot disables real engine")
	record_for(second)
	if not target.state.fires.is_empty():
		var extinguish := VehicleCommand.new(); extinguish.extinguish_requested=true
		VehicleRecovery.step(target.state,RecoveryRules.EXTINGUISH_SECONDS+0.1,0,extinguish)
	var repair := VehicleCommand.new(); repair.repair_requested=true
	VehicleRecovery.step(target.state,RecoveryRules.REPAIR_SECONDS+0.1,0,repair)
	check(target.state.recovery_reason=="module_repaired" and target.state.reactive_armor[tile]==0,"ordinary module repair cannot replenish expended ERA")
	var old_event: Dictionary=first.contacts[0].duplicate(true)
	target.reset_vehicle()
	check(target.state.reactive_armor[tile]==1,"vehicle reset restores independently initialized charge")
	check(not target.apply_projectile_armor(old_event,Vector3.FORWARD,{}).ok and target.state.reactive_armor[tile]==1,"old generation contact cannot consume new life charge")
	var rod := fire_era(era_layout(),true); complete(rod)
	check(rod.contacts[0].reactive_channel=="kinetic" and is_equal_approx(rod.contacts[0].effective_mm,30),"real APFSDS uses independent10 kinetic reduction instead of100 chemical reduction")
	record_for(rod)
	var layered := era_layout()
	var liner: ArmorPatchDefinition=ArmorTrainingTargets.build([{"center":Vector3(0,2,1.5),"thickness":1}]).layout.armor_patches[0]
	liner.id="inner_era"; liner.material_kind="rolled"; liner.reactive_profile=EraFixture.profile(); layered.armor_patches.append(liner)
	rod=fire_era(layered,true,true); complete(rod)
	var untouched_fragment_contacts := 0
	for fragment in rod.fragments:
		for contact in fragment.contacts:
			if contact.get("surface_id")=="inner_era":
				untouched_fragment_contacts+=1
				check(contact.reactive_channel=="fragment" and not contact.reactive_triggered,"real fragment obeys explicit zero ERA activation rule")
	check(untouched_fragment_contacts>0 and target.state.reactive_armor.inner_era==0,"mother rod subsequently activates tile that earlier fragments left charged")
	var record := record_for(rod)
	check(record.reactive_event_count>2,"replay retains ordered carrier and fragment armor transactions")
	for defect in ["profile","charge","version","bonus","index","count"]:
		var bad := record.duplicate(true)
		match defect:
			"profile": bad.contacts[0].reactive_profile.channels.chemical.reduction_mm=0
			"charge": bad.contacts[0].reactive_after=1
			"version": bad.rules_versions.reactive="fake"
			"bonus": bad.contacts[0].reactive_bonus_mm=100
			"index": bad.contacts[0].reactive_event_index=1
			"count": bad.reactive_event_count+=1
		check(not ShotRecordBuilder.validate(bad).ok,"replay rejects tampered reactive ledger: "+defect)
	for thickness in [-1.0]:
		var bad := era_layout()
		bad.armor_patches[4].has_thickness=false; bad.armor_patches[4].thickness_status="unknown"
		var st := fire_era(bad); complete(st)
		check(st.contacts[0].result=="unknown_armor" and target.state.reactive_armor[tile]==1,"ERA cannot fill missing passive thickness: "+str(thickness))
		record_for(st)
	manager.contact_policy=func(_shooter: Dictionary,_event: Dictionary) -> Dictionary: return {"allow":false,"reason":"test_spawn_protected"}
	var protected := fire_era(era_layout()); complete(protected)
	check(target.state.reactive_armor[tile]==1 and protected.contacts.is_empty(),"match protection rejects hit before ERA can consume")
	manager.contact_policy=Callable()
	manager.armor_handler=func(event: Dictionary,direction: Vector3,budget: Dictionary) -> Dictionary:
		var result := target.apply_projectile_armor(event,direction,budget)
		manager.cancel_all("cancelled_era_reentrant"); target.reset_vehicle(); return result
	var cancelled := fire_era(era_layout()); complete(cancelled)
	check(cancelled.terminal_reason=="cancelled_era_reentrant" and cancelled.contacts.is_empty() and cancelled.damage_records.is_empty() and target.state.reactive_armor[tile]==1,"reentrant reset prevents late records or damage after atomic armor call")
	manager.armor_handler=Callable(target,"apply_projectile_armor")
	var stale := fire_era(era_layout()); var stale_frames := snapshots()
	target.reset_vehicle()
	manager.advance_projectile(stale,0.05,stale_frames,world.get_world_3d().direct_space_state)
	check(stale.is_terminal() and stale.replay_error.contains("stale_armor_target") and stale.damage_records.is_empty() and target.state.reactive_armor[tile]==1,"stale query generation is rejected through the actual projectile authority path")
	manager.armor_handler=Callable()
	var unsupported := fire_era(era_layout()); complete(unsupported)
	check(unsupported.replay_error=="missing_reactive_authority" and unsupported.damage_records.is_empty() and target.state.reactive_armor[tile]==1,"missing authority cannot simulate reusable ERA or claim a complete replay")
	manager.armor_handler=Callable(target,"apply_projectile_armor")
	other=null

func era_profile_cases() -> void:
	check(ReactiveArmorProfile.valid_state(JSON.parse_string(JSON.stringify({"tile":1}))) and ReactiveArmorProfile.valid_state({"tile":0.0}),"JSON numeric charge values survive real integer-to-float decoding")
	for invalid in [null,[],EraFixture.profile().merged({"channels":{}},true),EraFixture.profile().merged({"provenance":"verified"},true),EraFixture.profile().merged({"max_trigger_angle_deg":90},true)]:
		check(not ReactiveArmorProfile.validate(invalid).is_empty(),"reject malformed reactive profile")
	for invalid in [{"tile":2},{"tile":-1},{"tile":true},{"tile":INF},{"tile":null},[]]:
		check(not ReactiveArmorProfile.valid_state(invalid),"reject malformed network reactive charge state")
	var profile := EraFixture.profile()
	for example in [[0,80.0,0.0,true],[1,4.0,0.0,true],[1,80.0,85.0,true],[1,80.0,0.0,false]]:
		var response := ReactiveArmorProfile.response(profile,example[0],"HEAT",example[1],example[2],example[3],false)
		check(not response.reactive_triggered,"spent/below threshold/oblique/backface hit does not activate ERA")

func _run() -> void:
	world=Node3D.new(); root.add_child(world)
	var defs:=VehicleDefs.new(); check(defs.load_defaults().ok,"definitions load")
	target=VehicleActor.new(); world.add_child(target)
	check(target.setup(defs,"player_tank","target",2,Transform3D(Basis.IDENTITY,Vector3(0,10,-20)),4,null).ok,"real ERA test actor loads")
	target.set_physics_process(false); target.tank.set_physics_process(false)
	manager=ProjectileManager.new(); manager.presentation_enabled=false; world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler=Callable(self,"apply_damage"); manager.armor_handler=Callable(target,"apply_projectile_armor")
	await physics_frame
	era_cases(); era_profile_cases()
	var before := target.state.reactive_armor.duplicate(true)
	await presentation_case()
	check(target.state.reactive_armor==before,"seeking ERA replay cannot consume or restore live vehicle charge")
	world.queue_free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("ERA_CHECKS_PASS" if failed==0 else "ERA_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
