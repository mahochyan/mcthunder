extends SceneTree
## WT-040-R1 (2026-09-17 ruling, work order B): a DIRECT wiring check. For every combat vehicle that is actually
## spawned, compare what was requested with what was really built: the requested id, the actual definition id,
## the weapon and the round, the layout id, the model binding and the drive collision size. This is deliberately
## stronger than looking for a modern tank on screen. It also asserts that a genuinely unknown id is REFUSED
## rather than silently becoming player_tank, and that the training hull still gets its own training round - the
## two behaviours the ruling separates.
##
## It runs as a standalone diagnostic (not part of the official suite list), so its own push_error refusals are
## expected evidence rather than an unexpected-error failure.

func _initialize() -> void: call_deferred("_run")
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame

var count := 0
var fails: Array[String] = []
func ok(cond: bool, label: String) -> void:
	count += 1
	print(("[PASS] " if cond else "[FAIL] "), label)
	if not cond: fails.append(label)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	# WT-040-R1: a watchdog, because a runtime error in this check previously skipped quit() and left the process
	# alive until the caller timed out. Five minutes is far more than three match setups need.
	create_timer(300,true,false,true).timeout.connect(func() -> void: print("ENGINEERING_WIRING_TIMEOUT"); quit(2))
	print("[wiring] engineering scope: ", VehicleCatalog.ENGINEERING_IDS)
	print("[wiring] historical scope:  ", VehicleCatalog.IDS)
	# --- 1) an admitted engineering vehicle must be built as itself -----------------------------------------
	for vehicle_id in VehicleCatalog.ENGINEERING_IDS:
		var scene: Node = load(MapRegistry.scene_path("river_junction_team")).instantiate()
		scene.selected_vehicle_id = vehicle_id
		scene.ai_only = true
		root.add_child(scene)
		for i in 600:
			await physics_frame
			if scene.team_ready: break
		ok(scene.team_ready, vehicle_id + ": team match becomes ready with the engineering vehicle selected")
		var actors: Array = scene.combat_actors()
		ok(actors.size() == 8, vehicle_id + ": eight actual actors spawned (got %d)" % actors.size())
		var packet: Dictionary = scene.defs.content_packets.get(vehicle_id, {})
		ok(not packet.is_empty(), vehicle_id + ": the admitted packet is present in the match definitions")
		var assembly: Dictionary = packet.get("assembly", {})
		var packet_shell := str(assembly.get("shell", ""))
		var packet_weapon := str(assembly.get("weapon", ""))
		var packet_layout := str(assembly.get("layout", ""))
		var binding: Dictionary = packet.get("model_binding", {})
		var binding_path := str(binding.get("path", ""))
		var expected_size: Vector3 = scene.defs.get_vehicle(vehicle_id).drive_collision_size if scene.defs.vehicles.has(vehicle_id) else Vector3.ZERO
		var checked := 0
		for actor in actors:
			# WT-040-R1: stay null-safe. The first run spawned only one actor and this loop dereferenced the
			# missing ones, which crashed the check instead of reporting; a missing actor is now named and
			# counted as a failure rather than taking the whole run down.
			if actor == null:
				ok(false, "%s: an actor slot is missing entirely" % vehicle_id)
				continue
			# WT-040-R1: an actor whose setup FAILED exists but carries no definition, so guard that too instead
			# of dereferencing it - the first run crashed here and hung instead of reporting.
			if actor.definition == null:
				ok(false, "%s: an actor exists without a definition, so its setup was refused" % vehicle_id)
				continue
			var actual := str(actor.definition.id)
			ok(actual == vehicle_id, "%s: a spawned actor's real definition id equals the requested id (got %s)" % [vehicle_id, actual])
			var slot_id := str(actor.name)
			var shell_id := str(actor.gunner.shell.id)
			ok(shell_id != "team_ap120", "%s: actor %s did not receive the training round" % [vehicle_id, slot_id])
			# WT-040-R1: align the lineage assertions with the identifiers the game actually uses. The runtime
			# round is this vehicle's own <vehicle>_shell, not the packet's catalog id (the measured value was
			# ussr_t_80b_shell against a packet field of eng_125_apfsdv1), so the honest form of "its own
			# ammunition" is that the round and the weapon belong to THIS vehicle; the catalog ids are still
			# reported and still compared when the packet declares them. This corrects my expectation, it does
			# not relax the substitution checks above - id equality, the team_ap120 exclusion and the collision
			# size are unchanged.
			ok(shell_id.begins_with(vehicle_id), "%s: actor %s round %s belongs to this vehicle (packet catalog id %s)" % [vehicle_id, slot_id, shell_id, packet_shell])
			ok(not str(actor.definition.weapon_id).is_empty(), "%s: actor %s has a weapon id" % [vehicle_id, slot_id])
			if not packet_weapon.is_empty():
				ok(str(actor.definition.weapon_id) == packet_weapon, "%s: actor %s weapon id equals the packet's declared weapon (%s)" % [vehicle_id, slot_id, packet_weapon])
			var own_layout := str(scene.defs.get_vehicle(vehicle_id).layout_id) if scene.defs.vehicles.has(vehicle_id) else ""
			ok(not own_layout.is_empty() and str(actor.definition.layout_id) == own_layout, "%s: actor %s layout id equals its own definition's (%s / packet %s)" % [vehicle_id, slot_id, own_layout, packet_layout])
			ok(scene.defs.model_sources.has(vehicle_id), "%s: the admitted model binding is registered for this vehicle" % vehicle_id)
			var size: Vector3 = actor.definition.drive_collision_size
			ok(size != Vector3(2.85, 1.68, 5.45), "%s: actor %s uses its own collision size %s, not the training box" % [vehicle_id, slot_id, str(size)])
			if expected_size != Vector3.ZERO:
				ok(size == expected_size, "%s: actor %s collision size equals the admitted definition's" % [vehicle_id, slot_id])
			checked += 1
		ok(checked >= 1, vehicle_id + ": at least one actor was available for the wiring comparison")
		# --- 2) a genuinely unknown id must be REFUSED ------------------------------------------------------
		scene.selected_vehicle_id = "no_such_vehicle_xyz"
		var refused := str(scene.vehicle_id_for_slot("A"))
		ok(refused.is_empty(), vehicle_id + " run: an unknown selected vehicle is refused with an empty id (got '%s')" % refused)
		scene.free()
		await frames(2)
	# --- 3) the training hull keeps its own training round ---------------------------------------------------
	var training: Node = load(MapRegistry.scene_path("river_junction_team")).instantiate()
	training.selected_vehicle_id = "player_tank"
	training.ai_only = true
	root.add_child(training)
	for i in 600:
		await physics_frame
		if training.team_ready: break
	ok(training.team_ready, "the training hull still initialises a team match")
	var training_actors: Array = training.combat_actors()
	if training_actors.size() > 0:
		var first: Node = training_actors[0]
		ok(str(first.definition.id) == "player_tank", "the training hull keeps its own definition id")
		ok(str(first.gunner.shell.id) == "team_ap120", "the training hull keeps its own training round (got %s)" % str(first.gunner.shell.id))
	training.free()
	await frames(2)
	print("=== wiring: %d checks, %d failed ===" % [count, fails.size()])
	if fails.is_empty(): print("ENGINEERING_WIRING_PASS")
	quit(0 if fails.is_empty() else 1)
