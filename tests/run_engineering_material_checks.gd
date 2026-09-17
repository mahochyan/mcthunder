extends SceneTree
## Production packets, actual armor queries and an explicit side-shot fixture.
## No armor, penetration, damage or geometry overrides.
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
	var loaded := catalog.load_engineering(defs)
	check(loaded.ok,"actual engineering packets pass provenance and binding gates: "+str(loaded.errors))
	if not loaded.ok: quit(1); return
	var world := Node3D.new()
	root.add_child(world)
	var actors := {}
	for id in VehicleCatalog.ENGINEERING_IDS:
		var actor := VehicleActor.new()
		actor.presentation_enabled = false
		world.add_child(actor)
		check(actor.setup(defs,id,id,1,Transform3D.IDENTITY,2,null).ok,"actual Actor setup: "+id)
		actors[id] = actor
	for id in actors:
		var actor: VehicleActor = actors[id]
		var opponent: VehicleActor = actors["germ_leopard_2a4" if id == "ussr_t_80b" else "ussr_t_80b"]
		var layout: VehicleLayoutDefinition = defs.layouts[actor.definition.layout_id]
		var snapshots := [QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)]
		var checked := {}
		for patch in layout.armor_patches:
			if patch.part_id != "hull" or checked.has(patch.plate_group_id): continue
			var part := DamageTrainingLayout.part_node(actor,patch.part_id)
			var center := Vector3.ZERO
			for i in 3: center += patch.vertices_local_m[patch.triangles[i]]/3.0
			center = part.global_transform*center
			var normal := (part.global_basis*patch.outward_normal_local).normalized()
			var query := ShotQueryService.query({"query_id":"hull_material_probe","from_world":center+normal*.2,"to_world":center-normal*.2},snapshots)
			var contact := ExternalContactSelector.select_contact(query)
			check(contact.status == "vehicle" and contact.event.surface_id == patch.id,id+" / "+patch.plate_group_id+": probe reaches the actual authored hull face")
			if contact.status != "vehicle" or contact.event.surface_id != patch.id: continue
			checked[patch.plate_group_id] = true
			for shell in opponent.gunner.shell_options:
				var resolved := ArmorResolver.resolve(contact.event,-normal,{"base_mm":shell.penetration_curve[0].y,"impact_profile":shell.impact_profile,"effect_policy":shell.effect_policy,"caliber_mm":shell.caliber_mm})
				print("MATERIAL_PROBE ",id," ",patch.plate_group_id," ",shell.id," material=",contact.event.material_kind," result=",resolved.result)
				check(resolved.result in ["penetrated","stopped","perforated_stop","ricochet"],id+" / "+patch.plate_group_id+" / "+shell.id+": material reaches a defined battle outcome")
		check(checked.size() == 12,id+": all twelve hull zones exercised through actual query geometry")
	# A controlled real projectile, directed through the T-80B driver's actual
	# volume. This tests material integration, not normal human fire-control input.
	var target: VehicleActor = actors.ussr_t_80b
	var shooter: VehicleActor = actors.germ_leopard_2a4
	var target_layout: VehicleLayoutDefinition = defs.layouts[target.definition.layout_id]
	var station: CrewStationDefinition
	for person in target_layout.crew_stations:
		if person.role == "driver": station = person
	check(station != null,"driver volume is authored for the real-shot fixture")
	if station != null:
		var part := DamageTrainingLayout.part_node(target,station.part_id)
		var center: Vector3 = part.global_transform*station.local_box_transform.origin
		var direction := -part.global_basis.x.normalized()
		var manager := ProjectileManager.new()
		manager.presentation_enabled = false
		world.add_child(manager)
		manager.set_physics_process(false)
		manager.damage_handler = func(event: Dictionary, budget: float) -> Dictionary: return target.apply_projectile_damage(event,budget)
		var shot_id := 0
		for shell in shooter.gunner.shell_options:
			manager.cancel_all("cancelled_reset")
			target.reset_vehicle()
			shot_id += 1
			var launched := manager.try_spawn({"round_id":4042,"shooter_id":shooter.entity_id,"shooter_life_id":shooter.life_id,"shot_id":shot_id,"shell_id":shell.id,"armor_policy":shell.armor_policy,"effect_policy":shell.effect_policy,"impact_profile":shell.impact_profile,"post_penetration_profile":shell.post_penetration_profile,"chemical_profile":shell.chemical_profile,"fuze_policy":shell.fuze_policy,"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,"position_world":center-direction*15,"velocity_world":direction*shell.muzzle_velocity_mps,"gravity_world":Vector3.DOWN*9.81*shell.gravity_scale,"max_age_s":shell.max_flight_time_s,"max_distance_m":shooter.weapon.gun_range})
			check(launched.ok,"real manager accepts unchanged opponent shell: "+shell.id)
			if launched.ok:
				var shot := manager.get_projectile_state(launched.projectile_id)
				for i in 10:
					if shot.is_terminal(): break
					manager.advance_projectile(shot,1.0/60.0,[QuerySnapshotBuilder.build_from_vehicle(target.tank,target_layout)],world.get_world_3d().direct_space_state)
				print("HULL_LIVE_SHOT shell=",shell.id," contacts=",shot.contacts," damage=",shot.damage_records)
				check(not shot.contacts.is_empty() and not shot.damage_records.is_empty(),"actual side shot commits internal damage: "+shell.id)
	if not OS.get_cmdline_user_args().has("--baseline"):
		var packet: Dictionary = defs.content_packets.ussr_t_80b
		var unknowns := 0
		for key in packet.facts:
			if key.begins_with("raw.material.") and packet.facts[key].status == "unknown" and packet.facts[key].value == null: unknowns += 1
		check(unknowns == 12,"all raw missing material facts remain unknown independently of gameplay defaults")
		var invalid := packet.duplicate(true)
		invalid.armor.hull_floor_front.material = "cast"
		check(not VehicleContentPipeline.validate_package(invalid,catalog.model_sources).ok,"changing a gameplay material without its registered policy is rejected")
	world.free()
	await process_frame
	check(checks >= 80,"both complete geometry matrices and the real-shot fixture reached their checks")
	print("=== result: %d checks, %d failed ==="%[checks,failed])
	print("ENGINEERING_MATERIAL_CHECKS_PASS" if failed == 0 else "ENGINEERING_MATERIAL_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
