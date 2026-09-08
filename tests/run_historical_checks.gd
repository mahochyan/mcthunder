extends SceneTree
var failures := 0
var checks := 0
var runtime_completed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ",label)

func _run() -> void:
	var defs := VehicleDefs.new()
	check(defs.load_defaults().ok,"legacy definitions remain available")
	var catalog := VehicleCatalog.new()
	var result := catalog.load_all(defs)
	for error in result.errors: print("[DETAIL] ",error)
	check(result.ok,"four historical packages pass evidence, compatibility, geometry and spatial admission")
	check(catalog.packages.size() == 4,"four historical configurations registered")
	for id in VehicleCatalog.IDS:
		check(defs.resolve_vehicle(id).ok,id+": common definition registry resolves actual historical package")
		if not catalog.packages.has(id): continue
		var packet: Dictionary = catalog.packages[id].packet
		for change in [["year",1943],["gun","wrong gun"],["mount","wrong mount"],["shell","wrong shell"]]:
			var bad := packet.duplicate(true); bad.assembly[change[0]] = change[1]
			check(not VehicleContentPipeline.validate_package(bad).ok,id+": rejects mismatched "+str(change[0]))
		var missing := packet.duplicate(true); missing.facts.erase("armor.hull_front_upper")
		check(not VehicleContentPipeline.validate_package(missing).ok,id+": missing critical evidence refuses admission")
		var wrong := packet.duplicate(true)
		var source: String = wrong.facts["identity.variant"].source_refs[0]
		wrong.sources[source].applies_to_identity_ids = ["another_vehicle"]
		check(not VehicleContentPipeline.validate_package(wrong).ok,id+": rejects source from another variant")
		for malformed in [{},{"geometry":[]},{"facts":[]},{"runtime":null}]:
			var bad := packet.duplicate(true)
			if malformed.is_empty(): bad.clear()
			else: bad.merge(malformed,true)
			check(not VehicleContentPipeline.validate_package(bad).ok,id+": malformed packet fails without partial assembly")
		for defect in ["roles","source_scope","width","fact_row","local_range","wheel_count","round_count","hash","optional_speed","unknown_substitute"]:
			var bad := packet.duplicate(true)
			match defect:
				"roles": bad.facts["crew.roles"].value = [1,"commander"]
				"source_scope": bad.sources[source].applies_to_identity_ids = 12
				"width": bad.facts["dimensions.width_m"].value = "wide"
				"fact_row": bad.facts["geometry.exterior"] = []
				"local_range": bad.armor.hull_front_upper.local_mm = INF
				"wheel_count": bad.geometry.wheel_count = 1; bad.facts["geometry.exterior"].value = bad.geometry.duplicate(true)
				"round_count": bad.runtime.rounds = 1.5; bad.facts["weapon.capacity"].value = 1.5; bad.facts["runtime.simulation"].value = bad.runtime.duplicate(true)
				"hash": bad.sources[source].sha256 = "x".repeat(64)
				"optional_speed": bad.runtime.turret_yaw_speed = []; bad.facts["runtime.simulation"].value = bad.runtime.duplicate(true)
				"unknown_substitute": bad.facts["armor.turret_roof"].status = "unknown"; bad.facts["armor.turret_roof"].value = null; bad.armor.turret_roof.local_mm = 15
			check(not VehicleContentPipeline.validate_package(bad).ok,id+": rejects invalid nested "+defect+" without a script error")
		await runtime_case(id)
		await battle_case(id)
	await arc_and_roster_cases(catalog)
	await garage_case()
	check(runtime_completed == 4,"all four runtime cases reached completion")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	if failures == 0: print("HISTORICAL_CHECKS_PASS")
	quit(0 if failures == 0 else 1)

func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new(); event.action = name; event.pressed = pressed
	Input.parse_input_event(event)

func runtime_case(id: String) -> void:
	var scene := BallisticsRange.new(); scene.selected_vehicle_id = id
	root.add_child(scene)
	await frames(12)
	check(scene._initialized and scene.actor.definition.id == id,id+": actual range uses selected actor definition")
	var actor := scene.actor
	var snap := scene.query_snapshots()
	check(snap.size() == 1 and snap[0].missing_parts.is_empty(),id+": hull/turret/barrel query transforms all present")
	check(actor.state.crew_states.size() == 5,id+": own documented five-person roster")
	check(actor.gunner.inventory.conserved(),id+": rack/chamber initialization conserves documented load")
	if actor.gunner.inventory.racks.has("ammo_ready"):
		check(actor.gunner.inventory.racks.ammo_ready == int(HistoricalEvidenceGate.value(scene.defs.content_packets[id],"weapon.stowage_counts").ready)-1,id+": chamber is deducted from actual ready rack")
	var count := actor.gunner.rounds_remaining
	action("fire",true); await frames(6)
	check(actor.gunner.shots_fired == 1 and actor.gunner.rounds_remaining == count-1,id+": real input consumes one shell through shared gunner")
	await frames(30)
	check(actor.gunner.shots_fired == 1,id+": held fire does not bypass historical reload")
	action("fire",false); await frames(3)
	action("fire",true); await frames(4)
	check(actor.gunner.shots_fired == 1,id+": repeated request during natural cooldown is blocked")
	action("fire",false)
	var start: Vector3 = actor.tank.global_position
	action("move_back",true); await frames(70)
	check(actor.tank.global_position.distance_to(start) > 0.35 and absf(actor.tank.forward_speed) <= actor.definition.reverse_max_speed+0.02,id+": real driving input and per-vehicle reverse limit")
	action("move_back",false)
	await frames(3)
	var second := VehicleActor.new(); scene.add_child(second)
	var setup := second.setup(scene.defs,id,"SECOND",2,Transform3D(Basis.IDENTITY,Vector3(12,0,0)),4,null)
	check(setup.ok and second.state != actor.state and second.gunner.inventory != actor.gunner.inventory and second.gunner.rounds_remaining == count,id+": shared configuration keeps ammunition/damage state independent")
	check(is_equal_approx(actor.turret.muzzle.position.z,-float(scene.defs.content_packets[id].geometry.barrel_length)),id+": muzzle agrees with visible barrel length")
	# Script-controller integration fixture: natural turret motion/reload, actual projectile and damage.
	actor.set_controller(null)
	await frames(150)
	var engine: ModuleVolumeDefinition
	for module in second.damage_layout_override.modules:
		if module.kind == "engine": engine = module
	var aim: Vector3 = second.tank.global_transform*engine.local_box_transform.origin
	for i in 620:
		var command := VehicleCommand.new(); command.has_aim_point = true; command.aim_world_point = aim
		command.fire_requested = i == 560
		actor.submit_command(command)
		await frames(1)
	check(actor.gunner.shots_fired == 2,id+": second shot waits for natural reload and turret slew")
	check(second.state.module_states.engine.integrity < engine.max_integrity,id+": actual shell penetrates side armor and damages matching engine volume")
	check(actor.state.module_states.engine.integrity == engine.max_integrity,id+": target damage does not contaminate shooter state")
	var posed := QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override)
	var same_pose := absf(actor.turret.rotation.y) > 0.1
	for part in ["hull","turret","barrel"]:
		var node := DamageTrainingLayout.part_node(actor,part)
		same_pose = same_pose and posed.part_world_transforms[part].is_equal_approx(node.global_transform)
	check(same_pose,id+": naturally rotated hull/turret/gun query and visual hierarchies share current transforms")
	var recoil := actor.turret.recoil_visual
	check(recoil != null and recoil.get_parent() == actor.turret.barrel_pivot and recoil.find_child("Cosmetic*",true,false) != null,id+": Blender cannon detail follows real elevation and recoil pivot")
	actor.reset_vehicle() # Normal range-reset command starts a fresh training state.
	check(actor.gunner.rounds_remaining == count and actor.gunner.inventory.conserved(),id+": normal training reset restores conserved historical total")
	if actor.gunner.inventory.racks.has("ammo_ready"):
		check(actor.gunner.inventory.racks.ammo_ready == int(HistoricalEvidenceGate.value(scene.defs.content_packets[id],"weapon.stowage_counts").ready)-1,id+": reset preserves ready-rack capacity and chamber deduction")
	scene.free(); await frames(2)
	runtime_completed += 1

func battle_case(id: String) -> void:
	var scene := VillageRange.new(); scene.selected_vehicle_id = id
	root.add_child(scene)
	await frames(195)
	check(scene.team_ready and scene.combat_actors().size() == 8,id+": real village initializes eight historical vehicles")
	var types := {}
	var all_real := true
	for actor in scene.combat_actors():
		types[actor.definition.id] = true
		all_real = all_real and actor.definition.id in VehicleCatalog.IDS and actor.gunner.shell.id != "team_ap120"
	check(types.size() == 4 and all_real,id+": mirrored roster uses actual historical weapons, no AP120 override")
	var actor := scene.actor
	var life := actor.life_id
	scene.abandon_vehicle() # Existing normal game command, including ticket cost and waiting UI.
	await frames(495)
	scene.request_respawn()
	await frames(8)
	check(scene.actor.life_id != life and scene.actor.definition.id == id,id+": timed respawn preserves selected historical configuration")
	scene.free(); await frames(3)

func garage_case() -> void:
	var garage := GarageShell.new(); root.add_child(garage)
	await frames(3)
	check(garage.vehicle_choice.item_count == 5,"normal garage exposes fixture plus four historical choices")
	for i in range(1,5):
		garage.vehicle_choice.select(i); garage.vehicle_choice.item_selected.emit(i)
		await frames(2)
		check(garage.preview.layout.historical_identity_id == VehicleCatalog.IDS[i-1] and not garage.dossier_button.disabled,"garage selection rebuilds matching preview and enables evidence dossier "+str(i))
		check(garage.shell_choice.get_item_text(garage.shell_choice.selected).begins_with(str(garage.catalog.packages[VehicleCatalog.IDS[i-1]].packet.assembly.shell)) and garage.rounds.value == garage.catalog.packages[VehicleCatalog.IDS[i-1]].packet.runtime.rounds,"garage ammunition controls display actual historical shell and count "+str(i))
		garage.preview.set_mode("interior")
		var hidden := true
		for extra in garage.preview._extra_nodes:
			if extra.name.begins_with("Cosmetic"): hidden = hidden and not extra.visible
		check(hidden and tracks_hidden(garage.preview),"interior inspection hides all imported Blender cosmetic meshes and dynamic tracks "+str(i))
	garage.free(); await frames(2)

func tracks_hidden(node: Node) -> bool:
	if node is MultiMeshInstance3D and node.visible: return false
	for child in node.get_children():
		if not child.is_queued_for_deletion() and not tracks_hidden(child): return false
	return true

func arc_and_roster_cases(catalog: VehicleCatalog) -> void:
	var packet: Dictionary = catalog.packages[VehicleCatalog.IDS[1]].packet.duplicate(true)
	packet.crew = packet.crew.filter(func(c: Dictionary) -> bool: return c.role != "assistant_driver_bow_gunner")
	packet.facts["crew.roles"].value.erase("assistant_driver_bow_gunner")
	packet.facts["geometry.crew"].value = packet.crew.duplicate(true)
	var configured := VehicleContentPipeline.validate_package(packet)
	check(configured.ok and configured.layout.crew_stations.size() == 4,"M24 manual's four-person combat roster is configurable without a five-person engine assumption")
	# Explicit engineering fixture for a limited-traverse gun; no historical vehicle is relabelled as a casemate.
	var defs := VehicleDefs.new(); defs.load_defaults()
	var result := VehicleCatalog.new().register(packet,defs)
	check(result.ok,"four-person configuration assembles through common registry")
	var vehicle := defs.get_vehicle(packet.id).duplicate(true) as VehicleDefinition
	vehicle.id = "test_limited_arc"; vehicle.content_tier = "test"; vehicle.verification = "estimated"
	vehicle.turret_yaw_min = -12; vehicle.turret_yaw_max = 12
	defs.vehicles[vehicle.id] = vehicle
	defs.content_packets[vehicle.id] = packet
	var actor := VehicleActor.new(); root.add_child(actor)
	var setup := actor.setup(defs,vehicle.id,"ARC",1,Transform3D.IDENTITY,2,null)
	check(setup.ok,"limited-arc engineering fixture uses real turret executor")
	for direction in [Vector3(30,3,-2),Vector3(-30,3,-2)]:
		for i in 150:
			var command := VehicleCommand.new(); command.has_aim_point = true; command.aim_world_point = direction
			actor.submit_command(command); await frames(1)
		check(absf(rad_to_deg(actor.turret.rotation.y)) <= 12.001,"script/AI command cannot aim outside fixed horizontal arc")
		actor.turret.snap_to_aim()
		check(absf(rad_to_deg(actor.turret.rotation.y)) <= 12.001,"reset/snap shares horizontal arc limit")
	var player := PlayerController.new(); actor.add_child(player); actor.set_controller(player)
	# Headless display does not capture the mouse. Test the camera-intent/player poll boundary here;
	# run_limited_arc_window.gd separately exercises actual captured mouse events in a real window.
	for yaw in [-50,50]:
		actor.cam_rig.set_aim(deg_to_rad(yaw),0)
		await frames(150)
		check(absf(rad_to_deg(actor.cam_rig.aim_yaw)) > 12 and absf(rad_to_deg(actor.turret.rotation.y)) <= 12.001,"headless player camera-intent fixture remains outside arc while cannon is constrained")
	actor.free(); await frames(2)
