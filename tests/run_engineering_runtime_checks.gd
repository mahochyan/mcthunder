extends SceneTree
## WT-040-R1 Stage 3 runtime half: the two engineering vehicles, admitted through the PRODUCTION catalog,
## spawned as real actors, loaded with the authored engineering rounds, fired through the real projectile
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
	var historical: Dictionary = catalog.load_all(defs)
	var engineering: Dictionary = catalog.load_engineering(defs)
	var loaded := {"ok": bool(historical.get("ok",false)) and bool(engineering.get("ok",false)),
		"errors": (historical.get("errors",[]) as Array) + (engineering.get("errors",[]) as Array)}
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
	var main_id := str(catalog_block.get("default",""))
	# CD16 expectation migration (declared, not loosened): this suite used to assert a FIXED count of two authored
	# rounds. CD07 deliberately added an HE round to the T-80B packet (commit 37afe1a9) and migrated the loadout
	# consequence but not this assertion, so the package integration gate found the stale expectation. The check now
	# asserts the manifest the packet DECLARES: every declared round must be identified and must carry the family
	# policy it declares, the default must still be the APFSDS long-rod round, and the HEAT round must still be
	# chemical. Nothing is relaxed: the Leopard still declares exactly two rounds, the T-80B now declares three, and
	# the runtime install count below is compared against the packet's own declaration instead of a literal.
	check(shells.size()>=2 and main_id!="",id+": the packet declares its authored rounds and a default (declared=%d)"%shells.size())
	if shells.size()<2: return
	var main_row: Dictionary = {}
	for row in shells:
		var row_id := str((row as Dictionary).get("id",""))
		check(row_id!="",id+": every declared round carries an identifier")
		if row_id==main_id: main_row=row
	check(not main_row.is_empty(),id+": the declared default resolves to a declared round")
	check(str(main_row.get("family",""))=="APFSDS" and str(main_row.get("effect_policy",""))=="long_rod",
		id+": the default is the APFSDS main round with the long-rod terminal effect")
	var alt_id := ""
	var alt_row: Dictionary = {}
	for row in shells:
		if str((row as Dictionary).get("id",""))!=main_id and str((row as Dictionary).get("family",""))=="HEAT":
			alt_id=str((row as Dictionary).get("id","")); alt_row=row; break
	check(alt_id!="" and str(alt_row.get("effect_policy",""))=="chemical",
		id+": the HEAT round is declared with the chemical terminal effect")
	for row in shells:
		var family := str((row as Dictionary).get("family",""))
		var expected_policy := str({"APFSDS":"long_rod","HEAT":"chemical","HE":"he_blast"}.get(family,""))
		check(expected_policy!="" and str((row as Dictionary).get("effect_policy",""))==expected_policy,
			id+": declared round "+str((row as Dictionary).get("id",""))+" carries the "+family+" family with the "+expected_policy+" policy")
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
	check(gun.shell_options.size()==shells.size() and total>0 and gun.inventory.conserved(),
		id+": every declared engineering round is installed and the rack ledger conserves stock (%d rounds)" % total)
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
	# Poll the real cooldown within a bound. The earlier T-80B residual was NOT
	# evidence of an autoloader cycle: that packet omitted its loading profile and
	# silently used the missing-loader penalty. run_engineering_loading_checks now
	# guards the exact equipment/rate and nominal cycle as well as damage/repair.
	# This shell-switching check still never clears cooldown by hand.
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
		id+": reset restores the authored declared manifest and the default chamber")
	world.queue_free(); await _frames(3)
