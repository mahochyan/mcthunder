extends SceneTree
## Explicit game-rule fixtures, not T-80B/Leopard authoring or historical values.
const SOURCE := "res://tests/run_loading_checks.gd"
const ID := "us_m24_m6_t85e1_1951"
var checks := 0
var failures := 0
var event_id := 0

func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1
	print(("[PASS] " if value else "[FAIL] ")+label)
func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame
func claim(value: Variant, unit: String) -> Dictionary:
	return {"value":value,"unit":unit,"origin":"game_rule","status":"estimated","source_refs":["fixture"],"location":"fixture() in "+SOURCE,"note":"TEST ONLY explicit loading rules; no historical vehicle claim"}

func fixture(automatic: bool = true) -> Dictionary:
	var packet: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://configs/vehicles/historical/"+ID+".json"))
	packet.evidence_profile="game_reference"; packet.admission_status="candidate"; packet.verification="estimated"; packet.historical_verified=false
	packet.display_name="TEST ONLY loading fixture on existing M24 geometry"
	packet.source_binding={"source_vehicle_id":"test_loading_fixture","primary_source":"fixture"}
	packet.unit_contract=ReferenceEvidenceGate.UNITS.duplicate()
	packet.sources={"fixture":{"origin":"game_rule","source_vehicle_id":"test_loading_fixture","applies_to_identity_ids":[ID],"excluded_identity_ids":[],"sha256":FileAccess.get_sha256(SOURCE),"artifact":SOURCE,"read_state":"authored"}}
	for key in packet.facts:
		var old: Dictionary=packet.facts[key]
		var unit := ReferenceEvidenceGate.unit_for(key)
		if unit.is_empty(): unit="structured" if old.value is Array or old.value is Dictionary else "text"
		packet.facts[key]=claim(old.value,unit)
		if old.status=="unknown": packet.facts[key].status="unknown"
	var people: Array=[]
	for person in packet.crew:
		if person.role=="assistant_driver_bow_gunner": continue
		if automatic and person.role=="loader":
			packet.modules.append({"id":"loader_mechanism","kind":"autoloader","part":person.part,"position":person.position.duplicate(),"size":person.size.duplicate(),"external":false})
		else: people.append(person)
	packet.crew=people
	var roles: Array=[]
	for person in people: roles.append(person.role)
	packet.facts["crew.roles"]=claim(roles,"roles")
	packet.facts["crew.placement"]=claim(people.duplicate(true),"structured")
	packet.facts["geometry.crew"]=claim(people.duplicate(true),"structured")
	for module in packet.modules:
		if module.id=="ammo_floor_left": module.ammo_capacity=2
		if module.id=="ammo_floor_right": module.ammo_capacity=4
	packet.facts["geometry.modules"]=claim(packet.modules.duplicate(true),"structured")
	packet.runtime.rounds=6; packet.runtime.reload_time=0.5
	packet.facts["weapon.capacity"]=claim(6,"count")
	packet.facts["runtime.simulation"]=claim(packet.runtime.duplicate(true),"structured")
	var shell := {"id":"fixture_ap","label":"TEST ONLY AP","gun":packet.assembly.gun,"family":"AP","source_bullet_type":"ap_tank","effect_policy":"kinetic","caliber_mm":75,"muzzle_velocity_mps":600.0,"penetration_curve":[[0,80],[1000,60]],"gravity_scale":1.0,"max_flight_time_s":12.0}
	shell.evidence={"identity":claim({"id":shell.id,"gun":shell.gun,"family":shell.family,"source_bullet_type":shell.source_bullet_type,"caliber_mm":shell.caliber_mm},"structured"),"ballistics":claim({"muzzle_velocity_mps":shell.muzzle_velocity_mps,"penetration_curve":shell.penetration_curve.duplicate(true),"gravity_scale":shell.gravity_scale,"max_flight_time_s":shell.max_flight_time_s},"structured"),"effect":claim(shell.effect_policy,"text")}
	packet.shell_catalog={"schema_version":1,"default":shell.id,"shells":[shell]}
	packet.assembly.shell=shell.id; packet.compatible_shells=[shell.id]; packet.facts["weapon.ammunition"].value=shell.id
	packet.loading_profile={"schema_version":1,"mode":"automatic" if automatic else "crew","crew_role":"" if automatic else "loader","origin":"game_rule","note":"TEST ONLY authored 3/4-person loading equipment fixture","required_module_ids":["loader_mechanism"] if automatic else [],"shot_feed_rack_ids":["ammo_floor_left"],"supply_rack_ids":["ammo_floor_right"],"replenishment_enabled":true,"reserve_rack_ids":["ammo_floor_right"],"replenishment_delay_s":0.2,"replenishment_interval_s":0.4,"replenishment_stationary":true}
	sync_loading(packet)
	return packet

func sync_loading(packet: Dictionary) -> void:
	packet.facts["loading.profile"]=claim(packet.loading_profile.duplicate(true),"structured")
	packet.facts["equipment.loading"]=claim({"mode":packet.loading_profile.mode,"crew_role":packet.loading_profile.crew_role,"required_module_ids":packet.loading_profile.required_module_ids.duplicate()},"structured")

func profile_cases() -> void:
	for automatic in [false,true]:
		var packet := fixture(automatic)
		var result := VehicleContentPipeline.validate_package(packet)
		for error in result.errors: print("[DETAIL] ",error)
		check(result.ok,"complete authored %s loading package enters real pipeline"%str(packet.loading_profile.mode))
		if result.ok: check(result.definitions.vehicle.loading_profile.mode==packet.loading_profile.mode and result.definitions.vehicle.verification=="estimated","serialized loading policy reaches admitted estimated definition")
	for defect in ["mode","fake_crew","empty_modules","wrong_module","wrong_kind","wrong_rack","empty_feed","overlap","nan","negative","wrong_type","unknown_field","equipment_missing","profile_mismatch","fake_verified","unknown_equipment"]:
		var packet := fixture()
		match defect:
			"mode": packet.loading_profile.mode="magic"
			"fake_crew": packet.loading_profile.crew_role="loader"
			"empty_modules": packet.loading_profile.required_module_ids=[]
			"wrong_module": packet.loading_profile.required_module_ids=["foreign_vehicle_module"]
			"wrong_kind": packet.loading_profile.required_module_ids=["engine"]
			"wrong_rack": packet.loading_profile.shot_feed_rack_ids=["engine"]
			"empty_feed": packet.loading_profile.shot_feed_rack_ids=[]
			"overlap": packet.loading_profile.reserve_rack_ids=["ammo_floor_left"]
			"nan": packet.loading_profile.replenishment_interval_s=NAN
			"negative": packet.loading_profile.replenishment_delay_s=-1
			"wrong_type": packet.loading_profile.required_module_ids=[123]
			"unknown_field": packet.loading_profile.shot_reload_time=1
		sync_loading(packet)
		match defect:
			"equipment_missing": packet.facts.erase("equipment.loading")
			"profile_mismatch": packet.loading_profile.replenishment_delay_s=9
			"fake_verified": packet.facts["equipment.loading"].status="verified"
			"unknown_equipment": packet.facts["equipment.loading"].status="unknown"; packet.facts["equipment.loading"].value=null
		check(not VehicleContentPipeline.validate_package(packet).ok,"loading package rejects "+defect)
	for id in VehicleCatalog.IDS:
		var packet: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://configs/vehicles/historical/"+id+".json"))
		check(VehicleContentPipeline.validate_package(packet).ok,id+": omitted profile preserves legacy authored crew policy")

func inventory_cases() -> void:
	var ammo := AmmoInventory.new()
	check(ammo.configure_loadout({"ap":6},["ready","reserve"],{"ready":2,"reserve":4},"ap") and ammo.conserved(),"finite six-round fixture includes chamber within declared rack capacities")
	check(not ammo.reserve_rack_move("reserve","ready","ap").ok,"full ready rack including chamber rejects reservation")
	ammo.consume_chamber()
	var move := ammo.reserve_rack_move("reserve","ready","ap")
	check(move.ok and ammo.total_available()==5 and ammo.supplied==6 and ammo.conserved(),"rack reservation retains canonical source ownership and total stock")
	check(not ammo.supply_round(1,"ready","ap") and not ammo.reserve_rack_move("reserve","ready","ap").ok,"destination reservation prevents duplicate move and external overflow")
	check(ammo.commit_rack_move(move.token) and not ammo.commit_rack_move(move.token) and ammo.racks.ready==2 and ammo.racks.reserve==3 and ammo.supplied==6 and ammo.conserved(),"internal move commits once without increasing external supplied ledger")
	check(ammo.begin_transfer_from("ready","ap") and ammo.transfer_from=="ready" and ammo.conserved(),"explicit feed-rack transaction takes exactly one round")
	ammo.finish_transfer(); ammo.consume_chamber()
	move=ammo.reserve_rack_move("reserve","ready","ap")
	var before := ammo.snapshot()
	check(move.ok and ammo.cancel_rack_move(move.token) and not ammo.cancel_rack_move(move.token) and ammo.total_available()==before.available and ammo.conserved(),"cancelling reserved move never adds a round")
	move=ammo.reserve_rack_move("reserve","ready","ap")
	ammo.lose_all()
	check(not ammo.commit_rack_move(move.token) and ammo.total_available()==0 and ammo.conserved(),"death cancels reserved move and loses ammunition once")
	ammo.configure_loadout({"ap":3},["ready","reserve"],{"ready":2,"reserve":4},"ap")
	check(not ammo.commit_rack_move(move.token) and ammo.conserved(),"reconfiguration cannot revive a stale reservation token")

func damage(actor: VehicleActor, id: String, kind: String = "module") -> Dictionary:
	event_id+=1
	var event := {"kind":kind,"entity_id":actor.entity_id,"life_id":actor.life_id,"event_id":"loading_"+str(event_id),"round_id":27,"shooter_id":"TEST_ONLY","shooter_life_id":99,"shot_id":event_id,"projectile_id":event_id}
	event["module_id" if kind=="module" else "crew_id"]=id
	return actor.apply_projectile_damage(event,120)

func trace_loading(actor: VehicleActor, stage: String) -> void:
	var gun := actor.gunner
	print("[LOADING_STATE] ",stage," ",JSON.stringify({"crew":actor.state.crew_states,"roles":actor.state.crew_assignments,"caps":actor.capabilities(),"binding_errors":actor.definition.loading_profile.validate_bindings(actor.state._damage_layout),"inventory":gun.inventory.snapshot(),"cooldown":gun.cooldown_left,"reason":gun.loading_reason,"recovery_enabled":actor.state.recovery_enabled,"recovery_action":actor.state.recovery_action,"repair_target":actor.state.action_target,"repair_progress":actor.state.action_progress,"recovery_reason":actor.state.recovery_reason,"mechanism":actor.state.module_states.get("loader_mechanism",{}),"position":str(actor.tank.global_position),"velocity":str(actor.tank.velocity)}))

func rack_policy(profile: LoadingProfile) -> Dictionary:
	return {"required":profile.required_module_ids.duplicate(),"feed":profile.shot_feed_rack_ids.duplicate(),"supply":profile.supply_rack_ids.duplicate(),"reserve":profile.reserve_rack_ids.duplicate(),"replenishment":profile.replenishment_module_ids.duplicate()}

func runtime_case(automatic: bool) -> void:
	var packet := fixture(automatic)
	var defs := VehicleDefs.new(); var catalog := VehicleCatalog.new()
	var registered := catalog.register(packet,defs)
	check(registered.ok,"runtime %s package registers with actual layout/model gate"%str(automatic))
	if not registered.ok: return
	var authored_rack_policy := rack_policy(defs.get_vehicle(ID).loading_profile)
	var world := Node3D.new(); root.add_child(world)
	var floor := StaticBody3D.new(); floor.collision_layer=GameConfig.LAYER_WORLD
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=Vector3(100,1,100); collision.shape=shape
	floor.add_child(collision); world.add_child(floor); floor.position.y=-0.5
	var actor := VehicleActor.new(); actor.presentation_enabled=false; world.add_child(actor)
	var setup := actor.setup(defs,ID,"loading_fixture",1,Transform3D(Basis.IDENTITY,Vector3(0,0.8,0)),4,null)
	check(setup.ok,"actual Actor installs serialized loading policy and rack loadout")
	if not setup.ok: world.queue_free(); await frames(3); return
	check(rack_policy(actor.definition.loading_profile)==authored_rack_policy,"Actor setup does not mutate any authored loading policy array")
	var manager := ProjectileManager.new(); manager.presentation_enabled=false; world.add_child(manager)
	var gun := actor.gunner; gun.projectile_manager=manager; gun.round_provider=func() -> int: return 27
	gun.aim_preview_enabled=false
	check(gun.configure_shell_loadout(gun.shell_options,gun.initial_shell_counts,gun.initial_shell_id) and rack_policy(actor.definition.loading_profile)==authored_rack_policy and gun.inventory.conserved(),"reconfiguring actual typed inventory preserves the authored rack policy and ledger")
	await frames(35)
	trace_loading(actor,"initial "+str(automatic))
	check(actor.state.alive_crew_count()==(3 if automatic else 4) and is_equal_approx(actor.capabilities().reload_rate,1.0),"accurate test roster has no fictitious loader or initial penalty")
	if not automatic:
		damage(actor,"loader","crew")
		trace_loading(actor,"manual casualty")
		check(is_equal_approx(actor.capabilities().reload_rate,GameConfig.DAMAGE_MISSING_LOADER_RATE),"manual loader casualty retains legacy 1/1.6 loading rate")
		check(gun.request_fire(),"manual fixture fires actual chambered round")
		await frames(34)
		check(gun.inventory.in_transfer==1 and gun.cooldown_left>0,"manual casualty cannot complete the healthy 0.5-second cycle")
		await frames(20)
		check(gun.inventory.chamber==1 and gun.cooldown_left==0 and gun.inventory.conserved(),"manual slowed cycle naturally finishes without changing ledger")
		world.queue_free(); await frames(3); return
	check(not HUDPresenter.present(actor,{}).weapon_text.contains("装填手"),"automatic three-person HUD does not claim a missing loader")
	check(gun.request_fire() and manager.get_projectile_state(gun.last_projectile_id)!=null,"automatic fixture fires through real projectile manager")
	await frames(8)
	check(damage(actor,"loader_mechanism").ok and not actor.capabilities().can_load,"actual module transaction disables automatic mechanism")
	var remaining := gun.cooldown_left; var stock := gun.inventory.snapshot()
	await frames(70)
	check(is_equal_approx(gun.cooldown_left,remaining) and gun.inventory.snapshot()==stock and not gun.try_complete_load(),"broken mechanism holds partial progress and transferred round without a completion bypass")
	check(not gun.request_fire() and gun.inventory.conserved(),"broken in-progress mechanism cannot fire an empty chamber")
	var supply := AmmunitionSupply.new(); supply.step(actor,4.0,true)
	trace_loading(actor,"disabled after supply")
	check(gun.inventory.chamber==0 and gun.inventory.in_transfer==1,"external supply cannot bypass mechanical pause")
	var repair := VehicleCommand.new(); repair.repair_requested=true
	actor.submit_command(repair)
	await frames(ceili(RecoveryRules.REPAIR_SECONDS*Engine.physics_ticks_per_second)+4)
	trace_loading(actor,"repair elapsed")
	check(actor.state.module_states.loader_mechanism.integrity==50 and actor.capabilities().can_load,"actual repair sequence restores bound mechanism at existing repair threshold")
	await frames(35)
	check(gun.inventory.chamber==1 and gun.inventory.conserved() and gun.inventory.supplied==6,"repaired mechanism naturally completes held cycle without replenishing rounds")
	damage(actor,"loader_mechanism")
	check(gun.request_fire() and gun.inventory.chamber==0 and gun.inventory.in_transfer==0,"mechanical failure permits existing chambered round once but cannot start next cycle")
	actor.reset_vehicle(); await frames(3)
	check(gun.inventory.total_available()==6 and gun.inventory.chamber==1 and actor.state.alive_crew_count()==3,"reset restores original typed loadout and three-person configuration")
	check(rack_policy(actor.definition.loading_profile)==authored_rack_policy,"actual reset preserves every authored loading policy array")
	gun.request_fire(); await frames(33); gun.request_fire()
	check(gun.inventory.chamber==0 and gun.inventory.in_transfer==0 and gun.inventory.racks.ammo_floor_right>0 and gun.cooldown_left==0,"exhausted feed rack cannot directly draw remaining reserve or start a fictitious reload")
	var supplied_before := gun.inventory.supplied
	await frames(125)
	trace_loading(actor,"replenish elapsed")
	check(gun.inventory.chamber==1 and gun.inventory.supplied==supplied_before and gun.inventory.conserved(),"independent reserve-to-feed move then full shot cycle restores a chamber without adding ammo")
	var snapshot := gun.inventory.snapshot(); var clock_before := gun.cooldown_left
	paused=true; gun.advance_timers(100.0); supply.step(actor,100.0,true)
	check(gun.inventory.snapshot()==snapshot and gun.cooldown_left==clock_before,"paused public loading/supply calls cannot advance transactions")
	paused=false
	actor.reset_vehicle(); gun.request_fire()
	# Explicit one-tick boundary fixture; ordinary timed loading was tested above.
	gun.cooldown_left=1.0/60.0
	actor.state.module_states.loader_mechanism.integrity=5.0
	actor.state.module_states.engine.fire_module_targets=PackedStringArray(["loader_mechanism"])
	VehicleRecovery.ignite(actor.state,"engine")
	actor.state.fires.engine.tick_left=RecoveryRules.FIRE_TICK_SECONDS-1.0/60.0
	actor.advance_standalone_tick(1.0/60.0)
	check(actor.state.module_states.loader_mechanism.integrity==0 and gun.inventory.chamber==0 and gun.inventory.in_transfer==1 and gun.cooldown_left>0,"same-tick recovery fire commits before loading completion and prevents a stale-capability chamber")
	world.queue_free(); await frames(3)

func _run() -> void:
	profile_cases(); inventory_cases()
	await runtime_case(false); await runtime_case(true)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	if failures==0: print("LOADING_CHECKS_PASS")
	quit(0 if failures==0 else 1)
