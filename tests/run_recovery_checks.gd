extends SceneTree
var checks := 0
var failed := 0
var world: Node3D
var actor: VehicleActor
var deaths: Array[Dictionary] = []
var event_id := 0

func _initialize() -> void:
	call_deferred("_run")

func _ok(value: bool, message: String) -> void:
	checks += 1
	if not value: failed += 1
	print(("[PASS] " if value else "[FAIL] ")+message)

func _damage(id: String, kind: String = "module", source: String = "A") -> Dictionary:
	event_id += 1
	var event := {"kind":kind,"entity_id":actor.entity_id,"life_id":actor.life_id,
		"event_id":"recovery_"+str(event_id),"round_id":7,"shooter_id":source,"shooter_life_id":99,
		"shot_id":event_id,"projectile_id":event_id}
	event["module_id" if kind == "module" else "crew_id"] = id
	var result := actor.apply_projectile_damage(event,120)
	var record := event.duplicate(true)
	record.merge(result,true)
	actor.present_damage_record(record)
	return result

func _command(action: String) -> VehicleCommand:
	var cmd := VehicleCommand.new()
	match action:
		"repair": cmd.repair_requested = true
		"extinguish": cmd.extinguish_requested = true
		"replace": cmd.replace_crew_requested = true
		"cancel": cmd.cancel_recovery_requested = true
	return cmd

func _step(seconds: float, cmd: VehicleCommand = null) -> void:
	var n := ceili(seconds*60)
	for i in n:
		# Same production command consumer; deterministic time fixture, separate from window inputs.
		actor._apply_command_once(cmd if cmd != null else VehicleCommand.new(),1.0/60.0)

func _reset() -> void:
	actor.reset_vehicle()
	deaths.clear()

func _inventory_cases() -> void:
	var ammo := AmmoInventory.new()
	ammo.configure(30,["rack_a","rack_b"])
	_ok(ammo.chamber == 1 and ammo.racks.rack_a == 15 and ammo.racks.rack_b == 14,"loadout partitions chamber and two racks")
	_ok(ammo.conserved(),"initial inventory conserved")
	_ok(ammo.consume_chamber() and ammo.begin_transfer(),"shot consumes chamber then moves one round to transfer")
	_ok(ammo.total_available() == 29 and ammo.in_transfer == 1 and ammo.racks.rack_a == 14,"loading removes from rack before chamber completion")
	_ok(not ammo.begin_transfer() and not ammo.consume_chamber(),"overlapping transfer and empty chamber cannot duplicate ammunition")
	ammo.cancel_transfer()
	ammo.cancel_transfer()
	_ok(ammo.racks.rack_a == 15 and ammo.total_available() == 29 and ammo.conserved(),"repeated transfer cancellation returns exactly one round")
	ammo.begin_transfer()
	ammo.finish_transfer()
	ammo.finish_transfer()
	_ok(ammo.chamber == 1 and ammo.in_transfer == 0 and ammo.total_available() == 29 and ammo.conserved(),"double completion cannot add a round")
	for i in 29:
		ammo.consume_chamber()
		ammo.begin_transfer()
		ammo.finish_transfer()
	_ok(ammo.total_available() == 0 and ammo.fired == 30 and ammo.conserved(),"30 shots consume exactly 30 rounds")
	ammo.configure(1,["rack"])
	_ok(ammo.racks.rack == 0 and ammo.chamber == 1,"one-round loadout has an empty physical rack")
	ammo.lose_all()
	ammo.lose_all()
	_ok(ammo.lost == 1 and ammo.conserved(),"repeated destruction loss is idempotent")

func _detonation_cases() -> void:
	actor.gunner.rounds_remaining = 0
	_damage("ammo_rack")
	_ok(not actor.state.destroyed and deaths.is_empty(),"empty rack direct hit does not detonate")
	_reset()
	actor.gunner.rounds_remaining = 1
	_damage("ammo_rack")
	_ok(not actor.state.destroyed and actor.gunner.inventory.chamber == 1,"chamber-only loadout does not make empty rack explosive")
	_reset()
	var result := _damage("ammo_rack")
	_ok(result.newly_destroyed and actor.state.death_record.cause == "ammo_detonation","same full rack direct hit causes actual actor terminal state")
	_ok(deaths.size() == 1 and deaths[0].source.shooter_id == "A","one attributed death notification")
	_damage("ammo_rack")
	actor._publish_death()
	_ok(deaths.size() == 1 and actor.gunner.inventory.conserved(),"later impacts and repeated notify cannot repeat death or ammo loss")
	_ok(actor.tank.collision_layer != 0 and actor.tank.is_inside_tree(),"wreck keeps actual vehicle collision")
	_ok(not actor.capabilities().drive and not actor.capabilities().fire,"terminal vehicle cannot drive or fire")
	_reset()
	_ok(not actor.state.destroyed and actor.gunner.rounds_remaining == 30,"explicit new life/reset restores inventory and state")

func _repair_cases() -> void:
	_damage("track_left")
	_damage("breech")
	_damage("assistant_driver","crew")
	var ammo_before := actor.gunner.inventory.snapshot()
	var charges := actor.state.extinguisher_charges
	_step(3,_command("repair"))
	_ok(actor.state.recovery_action == "repair" and actor.state.action_target == "track_left","repair follows track priority and one module at a time")
	var before := actor.state.action_progress
	var move := VehicleCommand.new()
	move.throttle = 1
	_step(1,move)
	_ok(actor.state.recovery_action.is_empty() and is_equal_approx(actor.state.repair_progress.track_left,before),"movement intent interrupts repair without advancing saved progress")
	_step(9.1,_command("repair"))
	_ok(actor.state.module_states.track_left.integrity == 50 and actor.capabilities().drive,"resuming saved repair reaches configured usable threshold")
	_ok(actor.state.module_states.breech.integrity == 0 and not actor.state.crew_states.assistant_driver.alive,"repair does not fix another module or revive crew")
	_ok(actor.gunner.inventory.snapshot() == ammo_before and actor.state.extinguisher_charges == charges,"repair does not replenish ammo or extinguishers")
	_reset()
	_damage("track_left")
	_step(2,_command("repair"))
	_damage("engine")
	_ok(actor.state.recovery_action.is_empty() and not actor.state.fires.is_empty(),"actual ignition interrupts ongoing repair")
	_step(1,_command("repair"))
	_ok(actor.state.recovery_action.is_empty() and actor.state.module_states.track_left.integrity == 0,"fire prevents repair progress")
	_reset()
	_step(1,_command("repair"))
	_ok(actor.state.recovery_reason == "nothing_to_repair","healthy vehicle rejects unnecessary repair")

func _fire_cases() -> void:
	_damage("engine")
	_ok(actor.state.fires.has("engine") and actor.state.fires.engine.source.shooter_id == "A","effective engine hit ignites and freezes original source")
	_step(1,_command("extinguish"))
	_ok(actor.state.extinguisher_charges == 1 and actor.state.recovery_action == "extinguish","repeated extinguisher request spends one charge at start")
	_step(0.1,_command("cancel"))
	_ok(actor.state.extinguisher_charges == 1 and not actor.state.fires.is_empty(),"cancelled extinguisher is not refunded")
	_step(4.1,_command("extinguish"))
	_ok(actor.state.extinguisher_charges == 0 and actor.state.fires.is_empty(),"second complete extinguisher consumes final charge and stops fire")
	_damage("engine")
	_step(1,_command("extinguish"))
	_ok(not actor.state.fires.is_empty() and actor.state.recovery_reason == "no_extinguishers","new effective hit can reignite but empty consumables reject use")
	_reset()
	_damage("engine")
	_step(20.1)
	_ok(actor.state.destroyed and actor.state.death_record.cause == "fire_crew_out","declared sustained crew exposure causes fire terminal state")
	_ok(deaths.size() == 1 and deaths[0].source.shooter_id == "A" and int(deaths[0].source.round_id) == 7,"fire death retains original launch attribution")
	_step(10)
	_ok(deaths.size() == 1,"terminal fire cannot produce a second death")
	_reset()
	VehicleRecovery.ignite(actor.state,"engine",{})
	_step(20.1)
	_ok(deaths.size() == 1 and deaths[0].source.is_empty(),"environmental fire never borrows an unrelated shooter")
	_reset()

func _replacement_cases() -> void:
	_damage("gunner","crew")
	_step(8.1,_command("replace"))
	_ok(actor.state.crew_assignments.gunner == "commander" and actor.state.crew_assignments.commander == "","replacement moves one actual person out of prior role")
	_ok(not actor.state.crew_states.gunner.alive and actor.capabilities().fire,"replacement restores function without reviving original gunner")
	var holders := 0
	for person in actor.state.crew_assignments.values():
		if person == "commander": holders += 1
	_ok(holders == 1,"one person cannot occupy two roles after replacement")
	_reset()
	_damage("gunner","crew")
	_step(2,_command("replace"))
	_damage("commander","crew")
	_step(0.1)
	_ok(actor.state.recovery_action.is_empty() and not actor.capabilities().fire,"donor incapacitation cancels replacement")
	_reset()
	_damage("gunner","crew")
	_step(1,_command("replace"))
	_reset()
	_step(9)
	_ok(actor.state.crew_assignments.gunner == "gunner" and actor.state.recovery_action.is_empty(),"reset cancels replacement without delayed role changes")
	_damage("gunner","crew")
	_step(1,_command("replace"))
	_damage("ammo_rack")
	_ok(actor.state.destroyed and actor.state.recovery_action.is_empty(),"terminal state cancels replacement")
	_reset()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	actor = VehicleActor.new()
	world.add_child(actor)
	var defs := VehicleDefs.new()
	_ok(defs.load_defaults().ok,"load production definitions")
	_ok(actor.setup(defs,"player_tank","B",2,Transform3D.IDENTITY,4,null).ok,"create actual recovery vehicle")
	actor.set_physics_process(false)
	actor.set_damage_layout(DamageTrainingLayout.build(true))
	actor.vehicle_destroyed.connect(func(r: Dictionary) -> void: deaths.append(r))
	await physics_frame
	_inventory_cases()
	_detonation_cases()
	_repair_cases()
	_fire_cases()
	_replacement_cases()
	await _integration_cases(defs)
	_aim_case(defs)
	world.queue_free()
	await process_frame
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks,failed])
	print("RECOVERY_CHECKS_PASS" if failed == 0 else "RECOVERY_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)

func _aim_case(defs: VehicleDefs) -> void:
	var observer := VehicleActor.new()
	world.add_child(observer)
	observer.setup(defs,"player_tank","observer",1,Transform3D(Basis.IDENTITY,Vector3(0,0,10)),2,null)
	observer.gunner.shell = observer.gunner.shell.duplicate(true)
	observer.gunner.shell.armor_policy = "resolve"
	observer.gunner.snapshot_provider = func() -> Array: return [QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override)]
	observer.cam_rig.cam.global_position = Vector3(0,4,8)
	observer.cam_rig.cam.look_at(Vector3(-0.46,1.68,0))
	observer.cam_rig._physics_process(1.0/60)
	var point := observer.cam_rig.intent_point()
	_ok(observer.cam_rig.intent_contact.get("entity_id","") == actor.entity_id and point.y > 1.5,"precise camera intent detects turret above driving collision box")
	observer.reset_vehicle()
	_ok(observer.cam_rig.intent_contact.is_empty(),"reset clears previous-life aiming cache")
	observer.queue_free()

func _integration_cases(defs: VehicleDefs) -> void:
	var manager := ProjectileManager.new()
	world.add_child(manager)
	manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	manager.projectile_damage.connect(actor.present_damage_record)
	for loadout in [0,30]:
		_reset()
		actor.gunner.rounds_remaining = loadout
		var spawn := manager.try_spawn({"round_id":8,"shooter_id":"actual_source","shooter_life_id":123,
			"shot_id":loadout+1,"shell_id":"test_ap120","armor_policy":"resolve",
			"penetration_curve":PackedVector2Array([Vector2(0,120)]),
			"position_world":actor.tank.global_transform*Vector3(0.72,0.95,3),
			"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,"max_age_s":2,"max_distance_m":100})
		_ok(spawn.get("ok",false),"real manager accepts recovery comparison shot")
		var st := manager.get_projectile_state(spawn.projectile_id)
		manager.advance_projectile(st,1.0/60,[QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override)],world.get_world_3d().direct_space_state)
		_ok(actor.state.module_states.ammo_rack.integrity == 0 and not st.damage_records.is_empty(),"actual penetrated path reaches physical ammo rack")
		_ok(actor.state.destroyed == (loadout > 0),"same real path distinguishes loaded and empty rack")
		if loadout > 0:
			_ok(deaths.size() == 1 and deaths[0].source.shooter_id == "actual_source","real projectile death retains committed source identity")
		manager.cancel_all("cancelled_reset")
	_reset()
	var mailbox := CommandMailbox.new()
	var command := _command("extinguish")
	mailbox.submit(command)
	command.extinguish_requested = false
	mailbox.submit(_command("replace"))
	var merged := mailbox.consume()
	_ok(merged.extinguish_requested and merged.replace_crew_requested,"recovery commands are copied and merged at the same mailbox boundary")
	_ok(not mailbox.consume().extinguish_requested,"recovery request is consumed once")
	mailbox.submit(_command("repair"))
	mailbox.set_blocked(true)
	mailbox.set_blocked(false)
	_ok(not mailbox.consume().repair_requested,"pause boundary discards staged recovery request")
	var old_generation := actor.state.generation
	_reset()
	var stale := actor.apply_projectile_damage({"kind":"module","module_id":"engine","entity_id":actor.entity_id,
		"life_id":actor.life_id,"target_generation":old_generation,"event_id":"old_generation"},120)
	_ok(stale.get("reason","") == "stale_generation" and actor.state.module_states.engine.integrity == 100,"pre-reset query cannot damage new state of same vehicle")
	var registry := WreckRegistry.new()
	registry.max_count = 2
	registry.lifetime_s = 1.0
	world.add_child(registry)
	registry.set_physics_process(false)
	var wreck_actors: Array[VehicleActor] = []
	for i in 3:
		var wreck := VehicleActor.new()
		world.add_child(wreck)
		wreck.setup(defs,"player_tank","wreck_"+str(i),2,Transform3D(Basis.IDENTITY,Vector3(20+i*5,0,0)),4,null)
		wreck.state.destroy_once("test",{})
		wreck_actors.append(wreck)
		_ok(registry.register(wreck),"register actual wreck under bounded budget")
		_ok(not registry.register(wreck),"duplicate wreck registration rejected")
	_ok(registry.count() == 2 and wreck_actors[0].is_queued_for_deletion(),"third wreck evicts oldest under configured count limit")
	registry._physics_process(1.1)
	_ok(registry.count() == 0 and wreck_actors[2].is_queued_for_deletion(),"expired unprotected wrecks are removed without another death")
	await process_frame
