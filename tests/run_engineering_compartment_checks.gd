extends SceneTree
## Actual admitted Leopard packet and real APFSDS side shot into its bustle.
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)

func run() -> void:
	var defs := VehicleDefs.new()
	var catalog := VehicleCatalog.new()
	check(catalog.load_engineering(defs).ok,"actual engineering catalog admits the packets")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); actor.presentation_enabled = false; world.add_child(actor)
	check(actor.setup(defs,"germ_leopard_2a4","B",2,Transform3D.IDENTITY,4,null).ok,"actual Leopard Actor installs its bound model")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	var inventory := actor.gunner.inventory
	var ready: int = inventory.rack_capacities.get("ammo_ready",0)
	var reserve: int = inventory.rack_capacities.get("ammo_reserve",0)
	check(ready == 15 and reserve == 27,"actual finite stowage uses authored 15 ready / 27 reserve")
	check(actor.definition.loading_profile.replenishment_enabled,"actual loader can replenish its ready rack from reserve")
	var equipped := actor.state.module_states.has("bustle_partition") and actor.state.module_states.has("bustle_vent")
	check(equipped,"actual partition and vent modules are installed at bound anchors")
	if equipped:
		var packet: Dictionary = defs.content_packets.germ_leopard_2a4
		var layout: VehicleLayoutDefinition = defs.layouts[actor.definition.layout_id]
		var rack: Dictionary = {}
		for row in packet.modules:
			if row.id == "ammo_ready": rack = row
		var manager := ProjectileManager.new(); manager.presentation_enabled = false; world.add_child(manager)
		manager.set_physics_process(false); manager.damage_handler = Callable(actor,"apply_projectile_damage")
		actor.gunner.projectile_manager = manager
		var shell: ShellDefinition = defs.get_shell("ussr_t_80b_shell")
		var part := DamageTrainingLayout.part_node(actor,rack.part)
		var position: Vector3 = part.global_transform*HistoricalVehicleGeometry.vec(rack.position)
		var direction := part.global_basis.x.normalized()
		var launched := manager.try_spawn({"round_id":4043,"shooter_id":"A","shooter_life_id":1,"shot_id":1,"shell_id":shell.id,"armor_policy":shell.armor_policy,"effect_policy":shell.effect_policy,"impact_profile":shell.impact_profile,"post_penetration_profile":shell.post_penetration_profile,"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,"position_world":position-direction*15,"velocity_world":direction*shell.muzzle_velocity_mps,"gravity_world":Vector3.DOWN*9.81*shell.gravity_scale,"max_age_s":shell.max_flight_time_s,"max_distance_m":1000})
		check(launched.ok,"actual T-80B APFSDS launches at the authored Leopard bustle")
		if launched.ok:
			var shot := manager.get_projectile_state(launched.projectile_id)
			for i in 10:
				if shot.is_terminal(): break
				manager.advance_projectile(shot,1.0/60.0,[QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)],world.get_world_3d().direct_space_state)
			print("BUSTLE_LIVE_SHOT contacts=",shot.contacts," damage=",shot.damage_records)
			var vented := false
			for record in shot.damage_records:
				if record.has("ammo_event"): vented = AmmoCompartmentProfile.valid_record(record) and record.ammo_event.after.lost == 14
			check(vented and not actor.state.destroyed,"real penetrated bustle vents fourteen stored rounds without killing the protected crew")
			check(inventory.racks.ammo_reserve == 27 and inventory.chamber == 1 and inventory.conserved(),"separate reserve and chamber survive, finite inventory conserved")
			check(actor.state.module_states.bustle_vent.integrity == 0,"real ammunition event consumes the authored vent")
			var repair := VehicleCommand.new(); repair.repair_requested = true
			VehicleRecovery.step(actor.state,RecoveryRules.REPAIR_SECONDS+.1,0,repair)
			for i in 1200: actor._apply_command_once(VehicleCommand.new(),1.0/60)
			check(inventory.racks.ammo_ready > 0 and inventory.racks.ammo_reserve < 27 and inventory.lost == 14 and inventory.conserved(),"ordinary timed repair and replenishment move existing reserve rounds without refunding losses")
			actor.reset_vehicle()
			check(inventory.total_available() == 42 and not actor.state.destroyed,"new-life reset restores original 42-round loadout and intact compartment")
	world.free(); await process_frame
	print("=== result: %d checks, %d failed ==="%[checks,failed])
	print("ENGINEERING_COMPARTMENT_CHECKS_PASS" if failed == 0 else "ENGINEERING_COMPARTMENT_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
