extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD07-T04, occlusion half: a world detonation must not deliver total damage through a wall, while an
## unshielded target at a comparable distance is still reached. One shot, two targets, so the contrast is a single run:
##
##   O1 a target BEHIND the wall takes no damage at all from the detonation;
##   O2 a target BESIDE the wall, at a distance the fragment channel can reach, DOES take damage;
##   O3 and the two therefore differ because of the geometry, not because the fragments failed to fly.

const HE_ID := "eng_125_he_v1"
const ENG := "res://configs/vehicles/engineering/ussr_t_80b.json"
const SEED := 16900

func _integrity(actor: VehicleActor) -> String:
	if actor == null: return "<none>"
	return JSON.stringify((actor.state.module_states.keys() as Array).map(func(k): return [str(k),float(actor.state.module_states[k].integrity)]))

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd007_occl_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD07 occl creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd007_occl_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var defs := VehicleDefs.new()
	check(VehicleCatalog.new(fixture_asset(packet,1.0)).register(packet,defs).ok,"CD07 occl the fixture packet registers")
	var world := Node3D.new(); root.add_child(world)

	var handle := FileAccess.open(ENG,FileAccess.READ)
	check(handle != null,"CD07 occl the engineering packet opens")
	var eng: Dictionary = JSON.parse_string(handle.get_as_text())
	check(VehicleCatalog.new(fixture_asset(eng,1.0)).register(eng,defs).ok,"CD07 occl the engineering packet registers")

	# The wall stands at the origin on the world layer, and it is what the round strikes.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(1,4,4)   # 1 m thick along X, 4 m tall and wide
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector3(0,1.2,0)
	world.add_child(wall)

	# Target A sits BEHIND the wall; target B sits BESIDE it, inside the fragment range.
	var actor_a := VehicleActor.new(); world.add_child(actor_a)
	var ok_a := actor_a.setup(defs,"ussr_t_80b","cd007_occl_a",1,Transform3D(Basis.IDENTITY,Vector3(-1.5,0,0)),2,null)
	check(ok_a.ok,"CD07 occl the shielded target installs")
	var actor_b := VehicleActor.new(); world.add_child(actor_b)
	var ok_b := actor_b.setup(defs,"ussr_t_80b","cd007_occl_b",2,Transform3D(Basis.IDENTITY,Vector3(0,0,2.5)),2,null)
	check(ok_b.ok,"CD07 occl the unshielded target installs")
	for actor in [actor_a,actor_b]:
		actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	var before_a := _integrity(actor_a)
	var before_b := _integrity(actor_b)

	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor_a,"apply_projectile_damage")
	var found: ShellDefinition = null
	for shell in actor_a.gunner.shell_options:
		if str(shell.id).contains(HE_ID): found = shell
	check(found != null,"CD07 occl the engineering HE is among the installed options")
	var snap_a := QuerySnapshotBuilder.build_from_vehicle(actor_a.tank,actor_a.state._damage_layout)
	snap_a["entity_id"] = "cd007_occl_a"; snap_a["life_id"] = 1
	var snap_b := QuerySnapshotBuilder.build_from_vehicle(actor_b.tank,actor_b.state._damage_layout)
	snap_b["entity_id"] = "cd007_occl_b"; snap_b["life_id"] = 2
	var spec := {"round_id":SEED,"shooter_id":"cd007","shooter_life_id":1,"shot_id":SEED,
		"shell_id":str(found.id),"effect_policy":"he_blast","armor_policy":"resolve",
		"impact_profile":found.impact_profile,"post_penetration_profile":found.post_penetration_profile,
		"fuze_policy":{},"caliber_mm":found.caliber_mm,"penetration_curve":found.penetration_curve,
		"seed":2101,"position_world":Vector3(9,1.2,0),"velocity_world":Vector3(-700,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":0.6,"max_distance_m":90.0}
	var spawned := manager.try_spawn(spec)
	check(spawned.ok,"CD07 occl the shot at the wall launches")
	var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var space := world.get_world_3d().direct_space_state
	for i in 400:
		if state.is_terminal(): break
		manager.advance_projectile(state,1.0/240.0,[snap_a,snap_b],space)
	var burst: Dictionary = state.burst if state.burst is Dictionary else {}
	var after_a := _integrity(actor_a)
	var after_b := _integrity(actor_b)
	var damaged_a := int(state.damage_records.size())
	print("[CD07 occl] terminal=%s burst=%s contacts=%d ; damage_records=%d" % [
		str(state.terminal_reason),("none" if burst.is_empty() else "present"),state.contacts.size(),damaged_a])
	print("[CD07 occl] shielded (behind wall)   unchanged=%s" % str(before_a==after_a))
	print("[CD07 occl] unshielded (beside wall) unchanged=%s" % str(before_b==after_b))
	check(not burst.is_empty(),"CD07 occl the shot detonated on the wall, so the fragments had a source")
	check(before_a==after_a,
		"CD07 occl O1 the target BEHIND the wall takes NO damage at all from the detonation - there is no through-wall total damage")
	check(before_b!=after_b,
		"CD07 occl O2 the target BESIDE the wall, at a reachable distance, DOES take damage, so the fragments really flew")
	check(before_a==after_a and before_b!=after_b,
		"CD07 occl O3 the two differ because of the geometry and not because nothing happened")
	manager.queue_free()
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_WALL_OCCLUSION_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
