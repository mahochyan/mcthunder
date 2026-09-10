extends SceneTree
## Level-impact fixtures: actual shell distance loss, geometry and damage resolver.
## Gravity is zero to hold impact height constant; this is not a live aiming trial.
const APP_SCENE = preload("res://scenes/app.tscn")
var checks := 0
var failed := 0
var target: VehicleActor
var manager: ProjectileManager
var world: Node3D
var serial := 0
var rows: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func damage(event: Dictionary, budget: float) -> Dictionary:
	return target.apply_projectile_damage(event,budget)
func fire(shell: ShellDefinition, distance: float, direction: Vector3, height: float, offset: float) -> Dictionary:
	manager.cancel_all("cancelled_matrix_fixture")
	target.set_damage_layout(target.damage_layout_override)
	serial += 1
	var aim := target.tank.global_position+Vector3(0,height,0)+direction.cross(Vector3.UP)*offset
	var accepted := manager.try_spawn({"round_id":32,"shooter_id":"matrix","shooter_life_id":1,"shot_id":serial,"shell_id":shell.id,
		"armor_policy":shell.armor_policy,"effect_policy":shell.effect_policy,"penetration_curve":shell.penetration_curve,"seed":32001,
		"position_world":aim-direction*distance,"velocity_world":direction*shell.muzzle_velocity_mps,"gravity_world":Vector3.ZERO,
		"max_age_s":shell.max_flight_time_s,"max_distance_m":distance+30})
	if not accepted.ok: return {"error":accepted.reason}
	var st := manager.get_projectile_state(accepted.projectile_id)
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(target.tank,target.damage_layout_override)
	for tick in int(shell.max_flight_time_s*60)+2:
		if st.is_terminal(): break
		manager.advance_projectile(st,1.0/60.0,[snapshot],world.get_world_3d().direct_space_state)
	var contacts: Array = []
	for contact in st.contacts:
		contacts.append({"patch":contact.get("surface_id",""),"result":contact.get("result",""),"angle":contact.get("angle_deg",0),"before_mm":contact.get("before_mm",0),"after_mm":contact.get("after_mm",0)})
	var affected: Array = []
	for id in target.state.module_states:
		if target.state.module_states[id].integrity<target.state.module_states[id].max_integrity: affected.append(id)
	return {"terminal":st.terminal_reason,"contacts":contacts,"damage_events":st.damage_records.size(),"modules":affected,"crew_alive":target.state.alive_crew_count(),"burst":not st.burst.is_empty(),"fragments":st.fragments.size(),"capabilities":target.capabilities()}
func run() -> void:
	var defs := VehicleDefs.new(); defs.load_defaults()
	var catalog := VehicleCatalog.new()
	check(catalog.load_all(defs).ok,"all four production vehicle packages load")
	world = Node3D.new(); root.add_child(world)
	manager = ProjectileManager.new(); world.add_child(manager); manager.set_physics_process(false); manager.damage_handler=damage
	var directions := {"front":Vector3.BACK,"right":Vector3.LEFT,"rear":Vector3.FORWARD,"left":Vector3.RIGHT}
	for target_id in VehicleCatalog.IDS:
		target = VehicleActor.new(); world.add_child(target)
		check(target.setup(defs,target_id,"target",2,Transform3D(Basis.IDENTITY,Vector3(0,100,0)),4,null).ok,"target loads "+target_id)
		target.process_mode=Node.PROCESS_MODE_DISABLED
		check(target.definition.validate().ok and target.weapon.validate().ok and not target.damage_layout_override.armor_patches.is_empty(),"finite mobility/reload/turret and nonempty armor "+target_id)
		await physics_frame
		for shooter_id in VehicleCatalog.IDS:
			var shells: Dictionary = HistoricalShellCatalog.build(catalog.packages[shooter_id].packet,HistoricalShellCatalog.read_packet())
			for shell in shells.options:
				for distance in [100.0,500.0,1000.0]:
					for side in directions:
						for height in [1.2,2.1]:
							for offset in [-0.45,0.45]:
								var result := fire(shell,distance,directions[side],height,offset)
								result.merge({"shooter":shooter_id,"target":target_id,"shell":shell.id,"effect":shell.effect_policy,"distance_m":distance,"side":side,"height_m":height,"offset_m":offset})
								rows.append(result)
						await process_frame
		print("[matrix] target=",target_id," cumulative_cases=",rows.size())
		target.free()
	var invalid := rows.filter(func(row: Dictionary) -> bool: return row.has("error") or row.get("terminal","").is_empty())
	var contacts := rows.filter(func(row: Dictionary) -> bool: return not row.get("contacts",[]).is_empty())
	var damage_rows := rows.filter(func(row: Dictionary) -> bool: return row.get("damage_events",0)>0)
	check(rows.size()==1536 and invalid.is_empty(),"1536 actual distance/direction/aim-point shots terminate")
	check(not contacts.is_empty() and not damage_rows.is_empty(),"matrix includes real geometry contacts and committed damage")
	check(rows.all(func(row: Dictionary) -> bool: return row.get("contacts",[]).all(func(contact: Dictionary) -> bool: return not str(contact.patch).is_empty())),"every armor contact retains its actual named surface")
	var pairs := {}
	for row in rows:
		var key := JSON.stringify([row.shooter,row.target,row.distance_m,row.side,row.height_m,row.offset_m])
		if not pairs.has(key): pairs[key]={}
		pairs[key][row.effect]=row
	var advantages := {"kinetic":[],"internal_burst":[]}
	for pair in pairs.values():
		if not pair.has("kinetic") or not pair.has("internal_burst"): continue
		for effect in advantages:
			var other: String="internal_burst" if effect=="kinetic" else "kinetic"
			if pair[effect].crew_alive<pair[other].crew_alive: advantages[effect].append(pair[effect])
	check(pairs.size()==768 and not advantages.kinetic.is_empty() and not advantages.internal_burst.is_empty(),"both shell policies have an actual paired crew-damage advantage")
	var args := OS.get_cmdline_user_args(); var output := "res://logs/032-wip/matrix.json"
	var index := args.find("--report"); if index>=0 and index+1<args.size(): output=args[index+1]
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	check(file!=null,"matrix evidence destination writable")
	if file!=null:
		file.store_string(JSON.stringify({"kind":"level_impact_fixture","seed":32001,"gravity":"zero; isolates impact geometry","rows":rows,"contact_cases":contacts.size(),"damage_cases":damage_rows.size(),"paired_crew_advantages":{"ap":advantages.kinetic.size(),"aphe":advantages.internal_burst.size()}},"  ")); file.close()
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("BALANCE_MATRIX_CHECKS_PASS" if failed==0 else "BALANCE_MATRIX_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
