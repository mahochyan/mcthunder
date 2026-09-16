extends SceneTree
## WT-040-R1 Stage 3 runtime half: the two engineering vehicles, admitted through the PRODUCTION catalog,
## spawned as real actors, loaded with both authored engineering rounds, fired through the real projectile
## manager, and reset. Nothing is teleported, no cooldown is cleared, no hit is fabricated and no combat
## number is altered to make anything pass: the reload happens on real physics frames and the assertions are
## about the shipped shell set and the shipped geometry.
##
## The pattern follows run_reference_admission_checks.gd, which already spawns an actor from a registered
## packet, installs its typed loadout and fires through the actual Gunner; the difference is that this check
## uses the real engineering packets in configs/vehicles/engineering rather than a synthetic fixture.
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("[PASS] " if value else "[FAIL] ")+label)

func _frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func _run() -> void:
	var defs := VehicleDefs.new()
	var catalog := VehicleCatalog.new()
	var loaded: Dictionary = catalog.load_all(defs)
	check(loaded.get("ok",false),"production catalog loads every packet, including the two engineering vehicles")
	for error in loaded.get("errors",[]): print("[DETAIL] ",str(error))
	check(catalog.rejected.is_empty(),"no packet was rejected by the catalog")
	for id in VehicleCatalog.ENGINEERING_IDS:
		await _vehicle_case(defs,id)
	print("=== result: %d checks, %d failed ===" % [checks,failures])
	print("ENGINEERING_RUNTIME_CHECKS_PASS" if failures == 0 else "ENGINEERING_RUNTIME_CHECKS_FAIL")
	quit(0 if failures == 0 else 1)

func _vehicle_case(defs: VehicleDefs, id: String) -> void:
	var resolved: Dictionary = defs.resolve_vehicle(id)
	check(resolved.get("ok",false),id+": the admitted packet resolves to a vehicle definition")
	if not resolved.get("ok",false):
		for error in resolved.get("errors",[]): print("[DETAIL] ",str(error))
		return
	var packet: Dictionary = resolved["packet"]
	var vehicle_def: Variant = resolved["vehicle"]
	check(str(vehicle_def.get("evidence_profile"))=="game_reference" and str(vehicle_def.get("admission_status"))=="validated",
		id+": resolves as an admitted game-reference vehicle (profile/status preserved)")
	var catalog_block: Dictionary = packet.get("shell_catalog",{})
	var shells: Array = catalog_block.get("shells",[])
	check(shells.size()==2 and str(catalog_block.get("default",""))!="",id+": the packet carries exactly two authored rounds and a default")
	if shells.size()!=2: return
	var main_id := str(catalog_block.get("default",""))
	var alt_id := ""
	for row in shells:
		if str((row as Dictionary).get("id",""))!=main_id: alt_id = str((row as Dictionary).get("id",""))
	check(alt_id!="",id+": the second authored round is identified")
	var main_row: Dictionary = {}
	var alt_row: Dictionary = {}
	for row in shells:
		if str((row as Dictionary).get("id",""))==main_id: main_row = row
		if str((row as Dictionary).get("id",""))==alt_id: alt_row = row
	check(str(main_row.get("family",""))=="APFSDS" and str(main_row.get("effect_policy",""))=="long_rod",
		id+": the default is the APFSDS main round with the long-rod terminal effect")
	check(str(alt_row.get("family",""))=="HEAT" and str(alt_row.get("effect_policy",""))=="chemical",
		id+": the second round is the HEAT round with the chemical terminal effect")
	# --- spawn the real actor from the admitted definitions -------------------------------------
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameConfig.LAYER_WORLD
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(200,1,200)
	floor_shape.shape = box; floor_body.add_child(floor_shape)
	world.add_child(floor_body); floor_body.position.y = -0.5
	var actor := VehicleActor.new(); actor.presentation_enabled = false
	world.add_child(actor)
	var setup: Dictionary = actor.setup(defs,id,id+"_runtime",0,Transform3D(Basis.IDENTITY,Vector3(0,0.8,0)),GameConfig.VIS_LAYER_VEHICLE,null)
	check(setup.get("ok",false),id+": the real actor installs from the admitted packet")
	if not setup.get("ok",false):
		for error in setup.get("errors",[]): print("[DETAIL] ",str(error))
		world.queue_free(); await _frames(3)
		return
	var manager := ProjectileManager.new(); manager.presentation_enabled = false
	world.add_child(manager)
	manager.exclude_provider = func(_entity: String, _life: int) -> Array[RID]:
		var excluded: Array[RID] = [actor.tank.get_rid()]
		return excluded
	var gun := actor.gunner
	gun.projectile_manager = manager
	gun.round_provider = func() -> int: return 4040
	gun.aim_preview_enabled = false
	await _frames(30)
	var total := gun.rounds_remaining
	check(gun.shell_options.size()==2 and total>0 and gun.inventory.conserved(),
		id+": both engineering rounds are installed and the rack ledger conserves stock (%d rounds)" % total)
	var main_runtime_id: String = id+"_shell"
	check(gun.inventory.shell_counts().has(main_runtime_id) and gun.inventory.shell_counts().has(id+"_"+alt_id),
		id+": the installed inventory is keyed by the engineering round ids")
	check(gun.inventory.chamber_shell==main_runtime_id,id+": the APFSDS main round is chambered by default")
	# The game's real mechanism, as run_reference_admission_checks.gd exercises it: the NEXT round is chosen
	# BEFORE firing, the shot freezes the round already in the chamber and the reload then transfers the
	# chosen one into it. Selecting after the shot leaves the transfer unchanged, which is what my first
	# version got wrong - it was my sequence, not a defect.
	check(gun.select_shell(1),id+": the HEAT round can be selected while the APFSDS is still in the chamber")
	# --- first real launch: the chambered APFSDS ------------------------------------------------
	check(gun.request_fire(),id+": the chambered APFSDS fires through the real projectile manager")
	var first: Variant = manager.get_projectile_state(gun.last_projectile_id)
	var design_velocity := 0.0
	if first != null: design_velocity = first.launch_velocity.length()
	check(first!=null and first.shell_id==main_runtime_id and first.effect_policy=="long_rod",
		id+": the launch carries the APFSDS identity and long-rod effect")
	check(first!=null and absf(design_velocity-float(main_row.get("muzzle_velocity_mps",0.0)))<1.0,
		id+": the launch speed matches the authored engineering muzzle velocity (%.1f m/s)" % design_velocity)
	check(gun.rounds_remaining==total-1 and gun.inventory.conserved(),id+": the first launch debits exactly one round")
	# --- natural reload, then the HEAT round ----------------------------------------------------
	# Wait for the NATURAL reload within a bound, polling the real cooldown. The T-80B's autoloader cycle is
	# longer than its nominal reload time - the state print showed 2.58 s of cooldown remaining after
	# nominal + 8 frames - so a fixed frame count was the wrong instrument. Nothing clears a cooldown by
	# hand: this only waits on real physics frames, which the ruling requires.
	var waited := 0
	var limit := ceili((actor.weapon.reload_time+10.0)*Engine.physics_ticks_per_second)
	while gun.cooldown_left > 0.0 and waited < limit:
		await physics_frame
		waited += 1
	await process_frame
	print("      [state] ",id," natural reload finished after ",waited," physics frames (nominal reload ",actor.weapon.reload_time," s)")
	# Diagnostic: state after a NATURAL reload, printed rather than assumed, so a vehicle-specific loading
	# mechanism can be read off the real state instead of being guessed at.
	print("      [state] ",id," cooldown=",gun.cooldown_left," transfer=",gun.inventory.transfer_shell,
		" chamber=",gun.inventory.chamber_shell," selected=",gun.inventory.selected_shell,
		" blocked=",gun.blocked_reason," counts=",gun.inventory.shell_counts(),
		" options=",gun.shell_options.size())
	check(gun.cooldown_left==0 and gun.inventory.chamber_shell==id+"_"+alt_id,
		id+": the natural reload chambers the HEAT round without clearing any cooldown by hand")
	check(gun.request_fire(),id+": the HEAT round fires through the real projectile manager")
	var second: Variant = manager.get_projectile_state(gun.last_projectile_id)
	check(second!=null and second.shell_id==id+"_"+alt_id and second.effect_policy=="chemical",
		id+": the second launch carries the HEAT identity and chemical effect")
	if second != null:
		var flat := true
		for point in second.penetration_curve:
			if absf(point.y-float(second.penetration_curve[0].y))>0.0001: flat = false
		check(flat,id+": the HEAT curve is flat, as its constant chemical budget requires")
	check(gun.shots_fired==2 and gun.rounds_remaining==total-2 and gun.inventory.conserved(),
		id+": two real launches debit two rounds and conserve the rest")
	# --- reset restores the typed manifest ------------------------------------------------------
	manager.cancel_all("engineering_runtime_reset")
	actor.reset_vehicle()
	check(gun.rounds_remaining==total and gun.inventory.shell_counts()==gun.initial_shell_counts
		and gun.inventory.chamber_shell==main_runtime_id and gun.inventory.conserved(),
		id+": reset restores the authored two-round manifest and the default chamber")
	world.queue_free(); await _frames(3)
