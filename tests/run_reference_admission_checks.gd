extends SceneTree
## Explicit game-rule fixtures copy an existing authored layout; they add no real vehicle.
const SOURCE := "res://tests/run_reference_admission_checks.gd"
const HISTORICAL := "res://configs/vehicles/historical/us_m24_m6_t85e1_1951.json"
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1
	print(("[PASS] " if value else "[FAIL] ")+label)

func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _claim(value: Variant, unit: String) -> Dictionary:
	return {"value":value,"status":"estimated","origin":"game_rule","source_refs":["fixture"],
		"location":"_fixture/_shell: explicit test data in run_reference_admission_checks.gd",
		"note":"TEST ONLY authored admission fixture; not historical or real vehicle performance","unit":unit}

func _shell(index: int) -> Dictionary:
	var family := "APHE" if index%2 else "AP"
	var data := {"id":"fixture_shell_"+str(index),"label":"TEST ONLY "+family+" "+str(index),
		"gun":"75-mm M6","family":family,"source_bullet_type":"aphe_tank" if family=="APHE" else "ap_tank",
		"effect_policy":"internal_burst" if family=="APHE" else "kinetic","caliber_mm":75,
		"muzzle_velocity_mps":600.0+index*20,"penetration_curve":[[0,70+index*5],[1000,50+index*5]],
		"gravity_scale":1.0,"max_flight_time_s":12.0}
	data.evidence={
		"identity":_claim({"id":data.id,"gun":data.gun,"family":data.family,"source_bullet_type":data.source_bullet_type,"caliber_mm":data.caliber_mm},"structured"),
		"ballistics":_claim({"muzzle_velocity_mps":data.muzzle_velocity_mps,"penetration_curve":data.penetration_curve.duplicate(true),"gravity_scale":data.gravity_scale,"max_flight_time_s":data.max_flight_time_s},"structured"),
		"effect":_claim(data.effect_policy,"text")}
	return data

func _fixture(count: int = 1) -> Dictionary:
	var packet := _read(HISTORICAL)
	packet.evidence_profile="game_reference"; packet.admission_status="candidate"
	packet.verification="estimated"; packet.historical_verified=false
	packet.display_name="TEST ONLY M24 geometry admission fixture"
	packet.source_binding={"source_vehicle_id":"test_reference_fixture_m24","primary_source":"fixture"}
	packet.unit_contract=ReferenceEvidenceGate.UNITS.duplicate()
	packet.sources={"fixture":{"origin":"game_rule","source_vehicle_id":"test_reference_fixture_m24",
		"applies_to_identity_ids":[packet.id],"excluded_identity_ids":[],"sha256":FileAccess.get_sha256(SOURCE),
		"artifact":SOURCE,"read_state":"authored"}}
	for field in packet.facts:
		var old: Dictionary=packet.facts[field]
		var unit := ReferenceEvidenceGate.unit_for(field)
		if unit.is_empty(): unit="structured" if old.value is Dictionary or old.value is Array else "text"
		packet.facts[field]=_claim(old.value,unit)
		if old.status=="unknown": packet.facts[field].status="unknown"
	var shells: Array=[]
	var ids: Array=[]
	for i in count:
		var shell := _shell(i); shells.append(shell); ids.append(shell.id)
	packet.shell_catalog={"schema_version":1,"default":"fixture_shell_0","shells":shells}
	packet.assembly.shell="fixture_shell_0"; packet.compatible_shells=ids
	packet.facts["weapon.ammunition"].value="fixture_shell_0"
	return packet

func _frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func _runtime_case(count: int) -> void:
	# Register only in this isolated test registry. The unchanged M24 ID resolves its
	# existing authored GLB; no candidate vehicle or global catalog is published.
	var packet := _fixture(count)
	var defs := VehicleDefs.new()
	var catalog := VehicleCatalog.new()
	var registered := catalog.register(packet,defs)
	check(registered.ok,"%d-shell fixture registers through actual VehicleCatalog/VehicleDefs"%count)
	if not registered.ok:
		for error in registered.errors: print("[DETAIL] ",error)
		return
	var resolved := defs.resolve_vehicle(packet.id)
	check(resolved.ok and resolved.packet.evidence_profile=="game_reference" and resolved.vehicle.verification=="estimated","%d-shell registered definitions preserve reference evidence on resolution"%count)
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	floor.collision_layer=GameConfig.LAYER_WORLD
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size=Vector3(100,1,100)
	collision.shape=shape; floor.add_child(collision)
	world.add_child(floor); floor.position.y=-0.5
	var actor := VehicleActor.new(); actor.presentation_enabled=false
	world.add_child(actor)
	var setup := actor.setup(defs,packet.id,"reference_fixture_"+str(count),1,Transform3D(Basis.IDENTITY,Vector3(0,0.8,0)),GameConfig.VIS_LAYER_VEHICLE,null)
	check(setup.ok,"%d-shell actual Actor.setup installs dispatcher loadout"%count)
	if not setup.ok:
		for error in setup.errors: print("[DETAIL] ",error)
		world.queue_free(); await _frames(3)
		return
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager)
	manager.exclude_provider=func(_entity: String, _life: int) -> Array[RID]:
		var excluded: Array[RID]=[actor.tank.get_rid()]
		return excluded
	var gun := actor.gunner
	gun.projectile_manager=manager; gun.round_provider=func() -> int: return 3030
	gun.aim_preview_enabled=false
	await _frames(30)
	var first_id: String=packet.id+"_shell"
	var expected := {first_id:48}
	if count==3: expected={first_id:34,packet.id+"_fixture_shell_1":7,packet.id+"_fixture_shell_2":7}
	check(gun.shell_options.size()==count and gun.initial_shell_counts==expected and gun.inventory.shell_counts()==expected,"%d-shell installed inventory has exact authored 48-round allocation"%count)
	check(gun.rounds_remaining==48 and gun.inventory.chamber_shell==first_id and gun.inventory.conserved(),"%d-shell chamber is debited once and physical rack ledger conserves stock"%count)
	var snapshot := gun.inventory.snapshot()
	check(not gun.select_shell(count) and gun.inventory.snapshot()==snapshot,"%d-shell out-of-range selection preserves installed inventory"%count)
	if count==3:
		var third_id: String=packet.id+"_fixture_shell_2"
		check(gun.select_shell(2) and gun.inventory.selected_shell==third_id and gun.inventory.chamber_shell==first_id,"actual Gunner selection of third shell cannot replace loaded first shell")
		check(gun.request_fire(),"reference fixture fires its originally chambered shell through actual Gunner")
		var first := manager.get_projectile_state(gun.last_projectile_id)
		check(first!=null and first.shell_id==first_id and first.effect_policy=="kinetic","first real launch freezes original shell despite selected third option")
		check(gun.rounds_remaining==47 and gun.inventory.transfer_shell==third_id and gun.cooldown_left>0 and gun.inventory.conserved(),"first launch debits one round and starts real transfer of selected third shell")
		check(gun.select_shell(0) and gun.inventory.transfer_shell==third_id and gun.inventory.selected_shell==first_id,"selection during third-shell transfer preserves carried shell")
		snapshot=gun.inventory.snapshot()
		check(not gun.request_fire() and gun.blocked_reason=="cooldown" and gun.inventory.snapshot()==snapshot,"real reload rejects premature fire without stock mutation")
		# Let VehicleActor advance the ordinary reload timer on actual physics frames.
		await _frames(ceili(actor.weapon.reload_time*Engine.physics_ticks_per_second)+6)
		check(gun.cooldown_left==0 and gun.inventory.chamber_shell==third_id and gun.shell.id==third_id,"natural reload chambers third option and updates actual ballistic definition")
		var launch_velocity := actor.turret.barrel_direction()*640.0+actor.tank.velocity
		check(gun.request_fire(),"reference third shell fires through the actual projectile manager")
		var third := manager.get_projectile_state(gun.last_projectile_id)
		check(third!=null and third.shell_id==third_id and third.effect_policy=="kinetic" and third.launch_velocity.distance_to(launch_velocity)<0.001 and third.penetration_curve[0]==Vector2(0,80),"third real launch freezes its own ID, 640 m/s initial speed and reference curve")
		expected[first_id]=33; expected[third_id]=6
		check(gun.shots_fired==2 and gun.rounds_remaining==46 and gun.inventory.shell_counts()==expected and gun.inventory.conserved(),"two real launches debit only original and third types and conserve all 46 remaining rounds")
	else:
		check(gun.request_fire() and gun.rounds_remaining==47 and gun.inventory.transfer_shell==first_id and gun.inventory.conserved(),"single-shell installed loadout fires and starts reload without requiring a second option")
	manager.cancel_all("cancelled_reference_fixture_reset")
	actor.reset_vehicle()
	check(gun.rounds_remaining==48 and gun.inventory.shell_counts()==gun.initial_shell_counts and gun.inventory.chamber_shell==first_id and gun.inventory.conserved(),"%d-shell actual vehicle reset restores original typed manifest"%count)
	await _garage_case(actor,packet)
	world.queue_free(); await _frames(3)

func _garage_case(actor: VehicleActor, packet: Dictionary) -> void:
	var count: int=packet.shell_catalog.shells.size()
	var service := GarageService.new()
	# Replace one package only in an isolated service. This does not modify IDS,
	# assets, ResearchGraph, the user's profile, or the normal application's catalog.
	service.definitions.vehicles.erase(packet.id)
	var registered := service.catalog.register(packet,service.definitions)
	check(registered.ok and service.has_vehicle(packet.id),"%d-shell explicit reference fixture enters isolated garage service"%count)
	if not registered.ok: return
	var original := service.default_loadout(packet.id)
	var prepared := service.build_loadout(original)
	check(prepared.ok and original.counts==actor.gunner.initial_shell_counts and prepared.inventory.available==48,"%d-shell garage default matches actual Actor dispatcher allocation"%count)
	var published := service.vehicle_ids()
	var raw := _read("res://assets/reference_data/candidates/ussr_t_80b.json")
	check(not service.catalog.register(raw,service.definitions).ok and service.vehicle_ids()==published and service.default_loadout(raw.id).is_empty(),"%d-shell garage refuses TXT candidate without changing published choices"%count)
	var saved := ProfileStore.new("",service)
	check(saved.validate(saved.snapshot()).ok,"%d-shell reference loadout survives actual profile validation"%count)
	var garage := GarageShell.new()
	garage.profile=saved; garage.initial_vehicle_id=packet.id
	root.add_child(garage); await _frames(3)
	check(garage.selected_vehicle_id()==packet.id and garage.preparation.shell_spins.size()==count and garage.preparation.first_choice.item_count==count,"%d-shell normal garage builds matching dynamic ammo and first-shell controls"%count)
	check(garage.vehicle_choice.item_count==published.size()+1 and not garage.preview_note.text.contains("文献道路速度") and garage.preview_note.text.contains("未做历史核验"),"%d-shell normal garage exposes only published vehicles and labels reference estimates accurately"%count)
	garage._show_dossier()
	await _frames(2)
	var views := garage.find_children("*","RichTextLabel",true,false)
	var dossier_text := ""
	# append_text/add_text build the RichTextLabel item tree; read displayed items,
	# including literal add_text claims, instead of only its BBCode source property.
	for view in views: dossier_text+=(view as RichTextLabel).get_parsed_text()
	var dossier_ok: bool=views.size()==1 and dossier_text.contains("当前参考弹种") and dossier_text.contains("game_rule") and dossier_text.contains("SHA256") and not dossier_text.contains("已核验 =")
	if not dossier_ok: print("[DETAIL] dossier labels=%d text=%s"%[views.size(),dossier_text.left(1800)])
	check(dossier_ok,"%d-shell actual dossier renders reference shell claims without historical-only fields"%count)
	var edited := {}
	var shell_ids: Array=original.counts.keys()
	for i in shell_ids.size():
		var amount := 2 if i==0 else (3 if i==2 else 0)
		edited[shell_ids[i]]=amount
		garage.preparation.shell_spins[shell_ids[i]].value=amount
	garage.preparation.first_choice.select(count-1)
	garage.preparation._ammo_changed()
	var committed := garage.preparation.save_settings()
	var loadout: Dictionary=saved.snapshot().garage.loadouts[packet.id]
	check(committed.ok and loadout.counts==edited and loadout.first_shell==shell_ids[count-1],"%d-shell actual garage editing commits typed counts and selected first shell"%count)
	check(service.install(actor,loadout) and actor.gunner.inventory.shell_counts()==edited and actor.gunner.inventory.chamber_shell==loadout.first_shell and actor.gunner.inventory.conserved(),"%d-shell saved garage loadout installs on real actor with one conserved chamber"%count)
	actor.reset_vehicle()
	check(actor.gunner.inventory.shell_counts()==edited and actor.gunner.inventory.chamber_shell==loadout.first_shell and actor.gunner.inventory.conserved(),"%d-shell actor reset preserves customized garage manifest"%count)
	garage.queue_free(); await _frames(3)

func _run() -> void:
	var fuze_packet := _fixture(2)
	var fuze_shell: Dictionary = fuze_packet.shell_catalog.shells[1]
	var fuze := {"mode":"penetration_delay","arming_thickness_mm":8.0,"delay_s":0.003,"provenance":"game_rule","reason":"TEST ONLY separate game rule"}
	fuze_shell.fuze_policy=fuze.duplicate(true)
	check(not VehicleShellCatalog.build(fuze_packet).ok,"reference fuze requires separate design evidence")
	fuze_shell.evidence.fuze=_claim(fuze.duplicate(true),"structured")
	var admitted := VehicleShellCatalog.build(fuze_packet)
	check(admitted.ok and admitted.options[1].fuze_policy==fuze,"reference fuze enters actual shell with matching separate design evidence")
	fuze_shell.fuze_policy.delay_s=0.01
	check(not VehicleShellCatalog.build(fuze_packet).ok,"reference fuze cannot drift from evidence value")
	fuze_shell.fuze_policy.delay_s=0.003; fuze_shell.evidence.fuze.status="verified"
	check(not VehicleShellCatalog.build(fuze_packet).ok,"game fuze design cannot claim historical verification")
	root.size=Vector2i(1280,720)
	for id in VehicleCatalog.IDS:
		var original := _read("res://configs/vehicles/historical/"+id+".json")
		var result := VehicleContentPipeline.validate_package(original)
		check(result.ok,id+": omitted profile retains original complete historical gate")
		check(VehicleShellCatalog.build(original).ok,id+": dispatcher preserves historical two-shell catalog")
	var packet := _fixture()
	var source_hash := FileAccess.get_sha256(SOURCE)
	check(source_hash.length()==64 and packet.sources.fixture.sha256==source_hash and _fixture(3).sources.fixture.sha256==source_hash,"local authored fixture source hash is stable across independently built packages")
	check(packet.sources.fixture.artifact==SOURCE and packet.sources.fixture.origin=="game_rule" and packet.verification=="estimated" and not packet.historical_verified,"source hash identifies authored fixture bytes without claiming historical verification")
	var result := VehicleContentPipeline.validate_package(packet)
	for error in result.errors: print("[DETAIL] ",error)
	check(result.ok,"complete explicit reference/game-rule package passes common geometry/layout/definition gates")
	if result.ok:
		check(result.definitions.vehicle.evidence_profile=="game_reference" and result.definitions.vehicle.admission_status=="validated" and result.definitions.vehicle.verification=="estimated","engineering validation never promotes historical verification")
		check(packet.admission_status=="candidate","validation does not mutate serialized candidate status")
	check(not HistoricalEvidenceGate.check(packet).ok,"new reference policy does not weaken historical evidence gate")
	for count in [1,3]:
		var multi := _fixture(count)
		var built := VehicleShellCatalog.build(multi)
		check(built.ok and built.options.size()==count,"reference catalog accepts %d implemented AP/APHE options"%count)
		check(VehicleContentPipeline.validate_package(multi).ok,"complete %d-shell reference package passes pipeline"%count)
	check(not VehicleShellCatalog.build(_fixture(0)).ok,"zero shells rejected")
	check(not VehicleShellCatalog.build(_fixture(9)).ok,"unbounded shell catalog rejected")
	for defect in ["fake_verified","top_verified","unknown_numeric","source_identity","project_identity","missing_source","missing_hash","missing_locator","missing_note","wrong_unit","unit_contract","missing_geometry","missing_module","shell_effect","shell_family","masked_heat","shell_value","shell_source","shell_locator","shell_verified","shell_duplicate","shell_default","foreign_shell","bad_profile"]:
		var bad := _fixture(3)
		match defect:
			"fake_verified": bad.facts["identity.variant"].status="verified"
			"top_verified": bad.verification="verified"
			"unknown_numeric": bad.facts["armor.turret_roof"].status="unknown"
			"source_identity": bad.sources.fixture.source_vehicle_id="another_variant"
			"project_identity": bad.sources.fixture.applies_to_identity_ids=["another_project_vehicle"]
			"missing_source": bad.sources.clear()
			"missing_hash": bad.sources.fixture.erase("sha256")
			"missing_locator": bad.facts["identity.variant"].erase("location")
			"missing_note": bad.facts["identity.variant"].erase("note")
			"wrong_unit": bad.facts["weapon.caliber_mm"].unit="m"
			"unit_contract": bad.unit_contract.angle="rad"
			"missing_geometry": bad.geometry.erase("gun_origin")
			"missing_module": bad.modules.clear(); bad.facts["geometry.modules"].value=[]
			"shell_effect": bad.shell_catalog.shells[0].effect_policy="internal_burst"
			"shell_family": bad.shell_catalog.shells[0].family="APFSDS"
			"masked_heat": bad.shell_catalog.shells[0].source_bullet_type="heat_fs_tank"
			"shell_value": bad.shell_catalog.shells[0].muzzle_velocity_mps=1600
			"shell_source": bad.shell_catalog.shells[0].evidence.ballistics.source_refs=["missing"]
			"shell_locator": bad.shell_catalog.shells[0].evidence.ballistics.erase("location")
			"shell_verified": bad.shell_catalog.shells[0].evidence.identity.status="verified"
			"shell_duplicate": bad.shell_catalog.shells[1].id=bad.shell_catalog.shells[0].id
			"shell_default": bad.shell_catalog.default="missing"
			"foreign_shell": bad.shell_catalog.shells[0].gun="another gun"
			"bad_profile": bad.evidence_profile="silently_skip_evidence"
		check(not VehicleContentPipeline.validate_package(bad).ok,"rejects malformed/incomplete reference: "+defect)
	for id in ["ussr_t_80b","germ_leopard_2a4"]:
		var raw := _read("res://assets/reference_data/candidates/"+id+".json")
		check(not raw.is_empty() and not VehicleContentPipeline.validate_package(raw).ok,id+": imported lossy TXT candidate cannot be admitted as a complete vehicle")
		var source: Dictionary=raw.get("source",{})
		var snapshot_path := "res://assets/reference_data/"+str(source.get("snapshot",""))
		check(FileAccess.file_exists(snapshot_path) and FileAccess.get_sha256(snapshot_path)==source.get("sha256") and source.get("historical_verified")==false and raw.get("historical_verified")==false,id+": local source snapshot matches recorded hash while remaining historically unverified")
	var pending: VehicleDefinition=load("res://configs/player_tank_vehicle.tres").duplicate(true)
	pending.content_tier="production"; pending.evidence_profile="game_reference"; pending.source_refs.assign([SOURCE]); pending.verification="estimated"
	check(not pending.validate().ok,"unvalidated reference VehicleDefinition cannot enter production")
	pending.admission_status="validated"
	check(pending.validate().ok,"validated reference definition is independent from historical verified")
	pending.verification="verified"
	check(not pending.validate().ok,"reference definition rejects forged historical verified even when validated")
	for count in [1,3]: await _runtime_case(count)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	if failures==0: print("REFERENCE_ADMISSION_CHECKS_PASS")
	quit(0 if failures==0 else 1)
