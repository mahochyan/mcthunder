extends SceneTree
## WT-040-R1 Stage 3 damage half: the two engineering vehicles take REAL damage through the real resolver and
## applier, and the consequences are read from the real capability derivation rather than from numbers I set
## by hand.
##
## The chain exercised is the shipped one:
##   DamageResolver.resolve(event, available_mm, state.snapshot())  ->  a delta
##   VehicleRuntimeState.apply_damage_delta(event_id, delta)        ->  applied, with before-state and
##                                                                     duplicate-event guards
##   VehicleCapabilities.compute(state)                             ->  the capability the game uses
##   VehicleRecovery / reset_vehicle()                              ->  restore, i.e. the next-life rebuild
##
## Nothing is teleported, no hit is fabricated and no combat number is altered: available_mm is the APFSDS
## round's own published 0 m figure, the resolver decides the outcome, and the assertions are about what the
## game reports afterwards.
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
	check(loaded.get("ok",false),"production catalog loads every packet for the damage suite")
	for error in loaded.get("errors",[]): print("[DETAIL] ",str(error))
	for id in VehicleCatalog.ENGINEERING_IDS:
		await _damage_case(defs,id)
	# SELF-GUARD against a false pass. A GDScript runtime error does not stop the script and does not
	# increment failures, so a case that aborts early can otherwise leave the suite reporting PASS with far
	# fewer checks than it should have run - which is exactly what happened when this file called a
	# non-existent snapshot() and still printed PASS after seven checks. The official suite independently
	# scans the log for SCRIPT ERROR; this covers the ad-hoc run as well.
	if checks < 20:
		failures += 1
		print("[FAIL] only ",checks," checks ran; the suite did not reach the end of both vehicle cases")
	print("=== result: %d checks, %d failed ===" % [checks,failures])
	print("ENGINEERING_DAMAGE_CHECKS_PASS" if failures == 0 else "ENGINEERING_DAMAGE_CHECKS_FAIL")
	quit(0 if failures == 0 else 1)

func _damage_case(defs: VehicleDefs, id: String) -> void:
	var packet: Dictionary = defs.content_packets.get(id,{})
	if packet.is_empty():
		check(false,id+": packet present for the damage suite"); return
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
	var setup: Dictionary = actor.setup(defs,id,id+"_damage",0,Transform3D(Basis.IDENTITY,Vector3(0,0.8,0)),GameConfig.VIS_LAYER_VEHICLE,null)
	check(setup.get("ok",false),id+": the real actor installs for the damage suite")
	if not setup.get("ok",false):
		for error in setup.get("errors",[]): print("[DETAIL] ",str(error))
		world.queue_free(); await _frames(3)
		return
	await _frames(10)
	var state: VehicleRuntimeState = actor.state
	var before: Dictionary = VehicleCapabilities.compute(state)
	check(bool(before.get("fire",false)),id+": a healthy vehicle reports the fire capability")
	var breech_id := "breech"
	check(state.module_states.has(breech_id),id+": the admitted layout carries a breech module to damage")
	if not state.module_states.has(breech_id):
		world.queue_free(); await _frames(3)
		return
	# The APFSDS round's own published 0 m penetration is the available budget: the resolver, not the test,
	# decides whether that destroys the breech.
	var main_row: Dictionary = {}
	for row in (packet.get("shell_catalog",{}) as Dictionary).get("shells",[]):
		if str((row as Dictionary).get("id",""))==str((packet.get("shell_catalog",{}) as Dictionary).get("default","")): main_row = row
	var available := float((main_row.get("penetration_curve",[[0.0,0.0]]) as Array)[0][1])
	print("      [damage] ",id," breech before=",state.module_states[breech_id]," available_mm=",available)
	var snapshot: Dictionary = state.damage_snapshot()
	var delta: Dictionary = DamageResolver.resolve({"kind":"module","module_id":breech_id,"entity_id":actor.name,"life_id":0},available,snapshot)
	check(delta.get("ok",false),id+": DamageResolver resolves a real module hit (reason "+str(delta.get("reason",""))+")")
	check(str(delta.get("reason","")) in ["module_damaged","module_destroyed"],
		id+": the resolver reports a real damage outcome")
	var applied: Dictionary = state.apply_damage_delta(id+"_hit_1",delta)
	check(applied.get("ok",false),id+": the state applies the delta through its own applier")
	var repeated: Dictionary = state.apply_damage_delta(id+"_hit_1",delta)
	check(not repeated.get("ok",false) and str(repeated.get("reason",""))=="invalid_or_duplicate",
		id+": re-applying the same event is rejected, so one hit cannot be counted twice")
	print("      [damage] ",id," breech after=",state.module_states[breech_id])
	var destroyed: bool = float((state.module_states[breech_id] as Dictionary).get("integrity",0)) <= 0
	var after: Dictionary = VehicleCapabilities.compute(state)
	if destroyed:
		check(not bool(after.get("fire",true)),id+": a destroyed breech removes the fire capability")
		check((after.get("reasons",[]) as Array).has(breech_id),id+": the capability derivation names the breech as the cause")
	else:
		check(float((state.module_states[breech_id] as Dictionary).get("integrity",0))<float((delta.get("before",{}) as Dictionary).get("integrity",0)),
			id+": a damaged (not destroyed) breech still loses integrity")
	# --- crew loss ------------------------------------------------------------------------------
	var people: Dictionary = state.crew_states
	var person := ""
	for key in people.keys():
		if bool((people[key] as Dictionary).get("alive",false)): person = str(key); break
	if not person.is_empty():
		var crew_delta: Dictionary = DamageResolver.resolve({"kind":"crew","crew_id":person,"entity_id":actor.name,"life_id":0},900.0,state.damage_snapshot())
		if crew_delta.get("ok",false) and not (crew_delta.get("after",{}) as Dictionary).is_empty():
			var crew_applied: Dictionary = state.apply_damage_delta(id+"_crew_1",crew_delta)
			check(crew_applied.get("ok",false),id+": a real crew hit is applied through the same applier")
			print("      [damage] ",id," crew ",person," alive=",state.crew_states[person].get("alive",false),
				" alive_count=",state.alive_crew_count())
			check(state.alive_crew_count()<people.size(),id+": a crew casualty reduces the living crew count")
		else:
			print("      [damage] ",id," crew resolver returned ",crew_delta)
	# --- restore: the same applier, and then the next-life rebuild -------------------------------
	var healed: Dictionary = delta.duplicate(true)
	healed["after"] = (delta.get("before",{}) as Dictionary).duplicate(true)
	var restored: Dictionary = state.apply_damage_delta(id+"_repair_1",healed)
	check(restored.get("ok",false),id+": the same applier restores the module (the repair path's state change)")
	check(bool(VehicleCapabilities.compute(state).get("fire",false)),id+": the fire capability returns once the module integrity is back")
	actor.reset_vehicle()
	await _frames(3)
	var rebuilt: Dictionary = VehicleCapabilities.compute(actor.state)
	var intact := true
	for module_id in actor.state.module_states:
		if float((actor.state.module_states[module_id] as Dictionary).get("integrity",0))<=0: intact = false
	check(intact and bool(rebuilt.get("fire",false)) and actor.state.alive_crew_count()==actor.state.crew_states.size(),
		id+": the next-life rebuild restores every module, the fire capability and the full crew")
	world.queue_free(); await _frames(3)
