extends "res://tests/run_reference_admission_checks.gd"
const RodFixture=preload("res://tests/fixtures/long_rod_profile.gd")

func _shell(index: int) -> Dictionary:
	var data := super._shell(index)
	if index==0: return data
	data.label="TEST ONLY authored APFSDS"; data.family="APFSDS"
	data.source_bullet_type="game_rule_apfsds"; data.effect_policy="long_rod"
	data.impact_profile=RodFixture.profile()
	data.evidence.identity=_claim({"id":data.id,"gun":data.gun,"family":data.family,"source_bullet_type":data.source_bullet_type,"caliber_mm":data.caliber_mm},"structured")
	data.evidence.effect=_claim(data.effect_policy,"text")
	data.evidence.impact=_claim(data.impact_profile.duplicate(true),"structured")
	return data

func _run() -> void:
	var packet := _fixture(2)
	packet.sources.fixture.sha256=FileAccess.get_sha256("res://tests/run_long_rod_content_checks.gd")
	packet.sources.fixture.artifact="res://tests/run_long_rod_content_checks.gd"
	var built := VehicleShellCatalog.build(packet)
	check(built.ok and built.options.size()==2,"explicit game-rule AP and APFSDS enter one typed catalog")
	if not built.ok: print(built.errors); quit(1); return
	check(built.options[1].validate().ok and built.options[1].effect_policy=="long_rod" and built.options[1].impact_profile.family=="APFSDS","admitted definition retains separate long-rod policy")
	for defect in ["missing_profile","missing_evidence","changed_curve","fake_source","ap_relabel","old_profile","fuze","missing_curve","null_evidence"]:
		var bad := packet.duplicate(true); var shell: Dictionary=bad.shell_catalog.shells[1]
		match defect:
			"missing_profile": shell.erase("impact_profile")
			"missing_evidence": shell.evidence.erase("impact")
			"changed_curve": shell.impact_profile.angle_resistance_curve[1][1]=1.8
			"fake_source": shell.evidence.identity.origin="warthunder_reference"
			"ap_relabel": shell.effect_policy="kinetic"; shell.evidence.effect.value="kinetic"
			"old_profile": shell.impact_profile.version=ArmorImpactProfile.VERSION; shell.evidence.impact.value=shell.impact_profile.duplicate(true)
			"fuze": shell.fuze_policy={"mode":"penetration_delay","arming_thickness_mm":8,"delay_s":0.003,"provenance":"game_rule","reason":"TEST ONLY"}; shell.evidence.fuze=_claim(shell.fuze_policy,"structured")
			"missing_curve": shell.penetration_curve=[]; shell.evidence.ballistics.value.penetration_curve=[]
			"null_evidence": shell.evidence=null
		check(not VehicleShellCatalog.build(bad).ok,"reject incomplete or mislabeled APFSDS: "+defect)
	var world := Node3D.new(); root.add_child(world)
	TerrainFixtures.box(world,Vector3(0,-0.5,0),Vector3(100,1,100))
	var defs := VehicleDefs.new(); var catalog := VehicleCatalog.new()
	var admitted := catalog.register(packet,defs)
	check(admitted.ok,"complete test-only packet enters isolated catalog")
	if not admitted.ok: print(admitted.errors); world.queue_free(); quit(1); return
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"modern_ammo_fixture",1,Transform3D.IDENTITY,2,null).ok,"real actor installs mixed shell catalog")
	var manager := ProjectileManager.new(); manager.presentation_enabled=false; world.add_child(manager)
	manager.set_physics_process(false)
	manager.exclude_provider=func(_id: String,_life: int) -> Array[RID]:
		var ids: Array[RID]=[actor.tank.get_rid()]; return ids
	var gun := actor.gunner; gun.projectile_manager=manager; gun.round_provider=func() -> int: return 1202
	gun.aim_preview_enabled=false
	await _frames(20)
	check(gun.select_shell(1) and gun.inventory.chamber_shell.ends_with("_shell"),"select APFSDS while retaining chambered AP")
	var command := VehicleCommand.new(); command.fire_requested=true
	check(actor.submit_command(command),"normal command submits first AP shot")
	await _frames(2)
	var first := manager.get_projectile_state(gun.last_projectile_id)
	check(first!=null and first.effect_policy=="kinetic" and gun.rounds_remaining==47,"normal command fires chambered AP and debits it once")
	await _frames(ceili(actor.weapon.reload_time*Engine.physics_ticks_per_second)+6)
	check(gun.shell.effect_policy=="long_rod" and gun.inventory.chamber_shell.ends_with("fixture_shell_1"),"ordinary reload physically chambers selected APFSDS")
	var muzzle := actor.turret.muzzle.global_position
	check(actor.submit_command(command),"normal command submits APFSDS shot")
	await _frames(2)
	var rod := manager.get_projectile_state(gun.last_projectile_id)
	check(rod!=null and rod.effect_policy=="long_rod" and rod.impact_profile==RodFixture.profile(),"actual launch freezes separate APFSDS response")
	check(rod!=null and rod.launch_position.distance_to(muzzle)<0.02 and is_equal_approx(rod.launch_velocity.length(),620.0),"APFSDS launch uses actual muzzle and its own authored speed")
	check(gun.rounds_remaining==46 and gun.inventory.conserved(),"mixed normal firing conserves physical ammunition")
	if rod!=null:
		var direction := rod.launch_velocity.normalized()
		var target := ArmorTrainingTargets.build([
			{"center":rod.launch_position+direction*4.0,"thickness":20},
			{"center":rod.launch_position+direction*6.0,"thickness":200}],"long_rod_target",1)
		for patch in target.layout.armor_patches: patch.material_kind="rolled"
		manager.advance_projectile(rod,0.05,[target],world.get_world_3d().direct_space_state)
		check(rod.contacts.size()==2 and rod.contacts[0].result=="penetrated" and rod.terminal_reason=="armor_stopped","normally fired APFSDS penetrates actual first plate and stops at second")
		var record := manager.shot_records.get_record(manager.shot_records.count()-1)
		check(not record.is_empty() and ShotRecordBuilder.validate(record).ok,"normal selection reload and muzzle shot produce valid complete modern replay")
		inspect_modern_shot(rod,record)
	manager.cancel_all("cancelled_fixture_complete")
	actor.reset_vehicle()
	check(gun.rounds_remaining==48 and gun.inventory.conserved() and gun.shell.effect_policy=="kinetic","reset restores initial mixed loadout and original chamber")
	world.queue_free(); await _frames(3)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("LONG_ROD_CONTENT_CHECKS_PASS" if failures==0 else "LONG_ROD_CONTENT_CHECKS_FAIL")
	quit(0 if failures==0 else 1)

func inspect_modern_shot(_rod: ProjectileState, _record: Dictionary) -> void:
	pass
