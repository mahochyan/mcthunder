extends "res://tests/run_modern_candidate_checks.gd"
## Actual modern target geometry and projectile damage; separate TEST ONLY art.
var shot_sequence := 0

func hit(actor: VehicleActor, id: String, kind: String = "module") -> Dictionary:
	shot_sequence+=1
	var event := {"kind":kind,"entity_id":actor.entity_id,"life_id":actor.life_id,"target_generation":actor.state.generation,"event_id":"compartment_"+str(shot_sequence),"round_id":1515,"shooter_id":"fixture","shooter_life_id":1,"shot_id":shot_sequence,"projectile_id":shot_sequence}
	event["module_id" if kind=="module" else "crew_id"]=id
	var result := actor.apply_projectile_damage(event,500)
	event.merge(result,true)
	return event

func fire_at_rack(actor: VehicleActor, manager: ProjectileManager, world: Node3D, row: Dictionary) -> ProjectileState:
	shot_sequence+=1
	var shell: ShellDefinition=actor.gunner.shell_options[0]
	var frame: Transform3D=actor.turret.global_transform if row.part=="turret" else actor.tank.global_transform
	var position := HistoricalVehicleGeometry.vec(row.position)
	position.x=-5
	var spec := {"round_id":1515,"shooter_id":"fixture","shooter_life_id":1,"shot_id":shot_sequence,"shell_id":shell.id,"effect_policy":shell.effect_policy,"impact_profile":shell.impact_profile,"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,"seed":1515,"position_world":frame*position,"velocity_world":frame.basis*Vector3(1650,0,0),"gravity_world":Vector3.ZERO,"max_age_s":0.1,"max_distance_m":100.0}
	var result := manager.try_spawn(spec)
	check(result.ok,"actual manager accepts modern APFSDS side shot")
	if not result.ok: print(result); return null
	var projectile := manager.get_projectile_state(result.projectile_id)
	for i in 20:
		if projectile.is_terminal(): break
		manager.advance_projectile(projectile,1.0/120.0,[QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override)],world.get_world_3d().direct_space_state)
	check(projectile.is_terminal() and not projectile.contacts.is_empty(),"actual projectile crosses modern armor and completes finite flight")
	return projectile

func profile_cases(packet: Dictionary) -> void:
	check(AmmoCompartmentProfile.check(packet).is_empty(),"authored partition and vent bind independently evidenced rear rack geometry")
	for defect in ["fact","missing","wall","vent","crew","kind","version"]:
		var bad := packet.duplicate(true)
		match defect:
			"fact": bad.facts.erase("protection.ammo.ammo_ready")
			"missing": bad.modules.pop_back()
			"wall": bad.modules[-2].position[2]=2
			"vent": bad.modules[-1].size[0]=0.1
			"crew": bad.crew[1].position[2]=2
			"kind": bad.modules[-2].kind="engine"
			"version":
				for row in bad.modules:
					if row.id=="ammo_ready": row.ammo_protection.version="fake"
		check(not AmmoCompartmentProfile.check(bad).is_empty(),"admission rejects invalid compartment: "+defect)

func recovery_cases(actor: VehicleActor) -> void:
	actor.reset_vehicle()
	var before := actor.gunner.inventory.snapshot()
	var result := hit(actor,"ammo_ready")
	check(result.has("ammo_event") and not actor.state.destroyed and actor.gunner.inventory.lost==14 and actor.gunner.inventory.conserved(),"closed bustle loses only fourteen stored rounds and keeps vehicle alive")
	check(actor.gunner.inventory.snapshot().rack_shells.ammo_reserve==before.rack_shells.ammo_reserve and actor.gunner.inventory.chamber==1,"reserve and already chambered round survive rack-only loss")
	check(actor.state.module_states.bustle_vent.integrity==0 and not HUDPresenter.recovery_reason("ammo_vented").is_empty(),"spent vent state and localized recovery explanation are available")
	check(AmmoCompartmentProfile.valid_record(result) and AmmoCompartmentProfile.valid_record(JSON.parse_string(JSON.stringify(result))),"ammo transaction validates both native and JSON decoded number types")
	for defect in ["negative","float","missing","reserve","health","amount"]:
		var bad := result.duplicate(true)
		match defect:
			"negative": bad.ammo_event.after.lost=-1
			"float": bad.ammo_event.before.available=42.5
			"missing": bad.ammo_event.erase("isolation")
			"reserve": bad.ammo_event.after.racks.ammo_reserve=0
			"health": bad.ammo_event.isolation.barrier.integrity=0
			"amount": bad.ammo_event.lost_shells[actor.gunner.shell_options[0].id]+=1
		check(not AmmoCompartmentProfile.valid_record(bad),"replay rejects altered rack transaction: "+defect)
	check(ShotExplanation.describe({"contacts":[],"damage":[result]},null).contains("14"),"production shot explanation reports actual frozen rack ammunition loss")
	var after := actor.gunner.inventory.snapshot()
	check(not actor.apply_projectile_damage(result,500).ok and actor.gunner.inventory.snapshot()==after,"repeated damage event cannot debit stored ammunition twice")
	var repair := VehicleCommand.new(); repair.repair_requested=true
	VehicleRecovery.step(actor.state,RecoveryRules.REPAIR_SECONDS+0.1,0,repair)
	check(actor.state.module_states.ammo_ready.integrity>0 and actor.gunner.inventory.snapshot()==after,"normal timed repair restores rack usability without creating ammunition")
	# Same command consumer as gameplay, simulated 60 Hz; actual Gunner performs timed replenishment.
	for i in 1100: actor._apply_command_once(VehicleCommand.new(),1.0/60.0)
	check(actor.gunner.inventory.racks.ammo_ready>0 and actor.gunner.inventory.racks.ammo_reserve<27 and actor.gunner.inventory.conserved(),"repaired ready rack receives real timed reserve transfer")
	actor.gunner.inventory.consume_chamber()
	check(actor.gunner.request_load(),"repaired and replenished rack feeds ordinary shot loading")
	for i in 500: actor._apply_command_once(VehicleCommand.new(),1.0/60.0)
	check(actor.gunner.inventory.chamber==1 and actor.gunner.inventory.lost==14 and actor.gunner.inventory.conserved(),"natural loading recovers firing readiness without restoring lost rounds")
	var fire := VehicleCommand.new(); fire.fire_requested=true
	var last := actor.gunner.last_projectile_id
	actor._apply_command_once(fire,1.0/60.0)
	check(actor.gunner.last_projectile_id!=last and actor.gunner.projectile_manager.get_projectile_state(actor.gunner.last_projectile_id)!=null,"normal fire command launches a real projectile after repair and replenishment")
	actor.reset_vehicle()
	check(not actor.apply_projectile_damage(result,500).ok and actor.gunner.inventory.total_available()==42,"old generation cannot damage fresh life")
	for condition in ["partition","loading","replenishing","reserve","spent_vent","empty","chamber_only"]:
		actor.reset_vehicle()
		var rack := "ammo_ready"
		match condition:
			"partition": hit(actor,"bustle_partition")
			"loading":
				actor.gunner.inventory.consume_chamber()
				check(actor.gunner.inventory.begin_transfer_from(rack,actor.gunner.shell_options[0].id),"fixture opens actual ready-rack loading transfer")
			"replenishing":
				actor.gunner.inventory.consume_chamber()
				check(actor.gunner.inventory.reserve_rack_move("ammo_reserve",rack,actor.gunner.shell_options[0].id).ok,"fixture opens actual replenishment reservation")
			"reserve": rack="ammo_reserve"
			"spent_vent": hit(actor,"bustle_vent")
			"empty": actor.gunner.rounds_remaining=0
			"chamber_only": actor.gunner.rounds_remaining=1
		var damage := hit(actor,rack)
		var lethal: bool=condition in ["partition","loading","replenishing","reserve"]
		check(actor.state.destroyed==lethal and actor.gunner.inventory.conserved(),"actual damage obeys isolation and inventory state: "+condition)
		if lethal: check(damage.newly_destroyed and actor.state.death_record.cause=="ammo_detonation","unisolated stored rack produces attributed terminal detonation")
	actor.reset_vehicle(); hit(actor,"ammo_ready")
	hit(actor,"loader","crew")
	check(not actor.state.crew_states.loader.alive,"bustle protection does not immunize separately hit crew")

func combat_case(id: String) -> void:
	var packet := _read(PACKAGES+id+".json")
	if id=="germ_leopard_2a4": profile_cases(packet)
	packet.id="test_compartment_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"modern compartment package validates with isolated TEST ONLY model")
	if not registered.ok: print(registered.errors); return
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"compartment_target",1,Transform3D.IDENTITY,2,null).ok,"actual modern target installs authored internal modules")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	var manager := ProjectileManager.new(); manager.presentation_enabled=false; world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler=Callable(actor,"apply_projectile_damage")
	actor.gunner.projectile_manager=manager
	await _frames(2)
	var rack := {}
	for row in packet.modules:
		if row.id=="ammo_ready": rack=row
	var st := fire_at_rack(actor,manager,world,rack)
	if st!=null:
		var struck := false; var vented := false
		for event in st.damage_records:
			if event.item_id=="ammo_ready": struck=true; vented=event.has("ammo_event")
		check(struck and vented==(id=="germ_leopard_2a4") and actor.state.destroyed==(id=="ussr_t_80b"),"actual modern armor/rack strike produces distinct Soviet/German survival outcome")
		var record := manager.shot_records.get_record(manager.shot_records.count()-1)
		var validated := ShotRecordBuilder.validate(record)
		check(not record.is_empty() and validated.ok,"actual compartment shot produces complete validated replay")
		if not validated.ok: print("[REPLAY] ",validated," ",st.replay_error)
		if id=="germ_leopard_2a4" and not record.is_empty():
			var bad := record.duplicate(true); bad.rules_versions.erase("ammo_compartment")
			check(not ShotRecordBuilder.validate(bad).ok,"compartment replay requires versioned optional rule")
		if not record.is_empty() and validated.ok: await capture_compartment(actor,record)
	if id=="germ_leopard_2a4": recovery_cases(actor)
	world.queue_free(); await _frames(3)

func capture_compartment(actor: VehicleActor, record: Dictionary) -> void:
	var args := OS.get_cmdline_user_args(); var index := args.find("--shot-dir")
	if index<0 or index+1>=args.size(): return
	check(DisplayServer.get_name()!="headless","compartment replay capture requires actual window")
	if DisplayServer.get_name()=="headless": return
	var before := actor.state.damage_snapshot()
	var host := Control.new(); root.add_child(host); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); host.add_child(bg); bg.color=Color("17232d"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new(); host.add_child(label); label.position=Vector2(24,18); label.add_theme_font_size_override("font_size",18)
	label.text=actor.definition.id+" / ACTUAL PROJECTILE REPLAY / TEST ART\nDestroyed: "+str(actor.state.destroyed)+"   Stored ammo lost: "+str(actor.gunner.inventory.lost)+"   Available: "+str(actor.gunner.inventory.total_available())+"\nAuthored compartment rule; dynamic roof opening and external model admission pending"
	var replay := ReplayView.new(); host.add_child(replay)
	check(replay.present(record,false).ok,"production replay opens actual modern rack damage record")
	replay.playing=false; replay.seek(float(record.terminal.flight_time_s))
	replay.position=Vector2(24,95); replay.size=Vector2(1100,580)
	(replay.viewport.get_parent() as SubViewportContainer).custom_minimum_size=Vector2(1000,380)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(args[index+1])
	check(root.get_texture().get_image().save_png(str(args[index+1]).path_join(actor.definition.id+".png"))==OK,"actual compartment replay image saved")
	check(actor.state.damage_snapshot()==before,"viewing compartment replay does not repeat damage or ammo loss")
	host.queue_free(); await process_frame

func rack_loss_cases() -> void:
	for lost_rack in ["ready","reserve"]:
		var inventory := AmmoInventory.new()
		inventory.configure_loadout({"ap":6},["ready","reserve"],{"ready":3,"reserve":3},"ap")
		inventory.consume_chamber()
		var reserved := inventory.reserve_rack_move("reserve","ready","ap")
		check(reserved.ok,"reserve real round before standalone rack-loss transaction")
		inventory.lose_rack(lost_rack)
		var after := inventory.snapshot()
		check(not inventory.commit_rack_move(reserved.token) and inventory.conserved(),"lost source or destination cancels stale transfer without duplication")
		inventory.lose_rack(lost_rack)
		check(inventory.snapshot()==after,"repeated rack loss is idempotent")

func _run() -> void:
	rack_loss_cases()
	owned_directory="res://assets/vehicles/test_compartment_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"create owned test model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	for id in MODERN: await combat_case(id)
	for path in artifact_paths: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(owned_directory.path_join(".gdignore")); DirAccess.remove_absolute(owned_directory)
	check(VehicleCatalog.IDS.size()==4,"test does not publish unadmitted modern models")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("AMMO_COMPARTMENT_CHECKS_PASS" if failures==0 else "AMMO_COMPARTMENT_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
