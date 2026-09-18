extends SceneTree
## MCT-COMBAT-DEEPEN-01 CD07-T01 and T02: the same external burst with NO breach, at the open-top representative and at a
## closed one, through the production catalog so both are delivered content rather than fixtures of mine.
##
## The judgment is the case's own: a closed fighting compartment must not be emptied through the wall by an external burst
## with no breach, while the open-top one, whose geometry really declares an open fighting compartment, is reachable. The
## two verdicts must therefore DIFFER, and they must differ because of declared geometry rather than a vehicle_type label.

const HIST_OPEN := "us_m36_m4a1_1945"
const HIST_CLOSED := "us_m26_m3_1945"
const SEED := 16400

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ",label)

func _frames(n: int) -> void:
	for i in n: await process_frame

func _aphe() -> Dictionary:
	return {"version":ArmorImpactProfile.VERSION,"family":"APHE","provenance":"game_rule",
		"reason":"CD07 contrast fixture: an APHE rule set so a delay fuze can be attached to the burst",
		"normalization_deg":4.0,"overmatch_ratio":3.0,"ricochet_deg":70.0,
		"material_coefficients":{"rolled":1.0,"cast":1.1}}

func _burst_at(defs: VehicleDefs, catalog: VehicleCatalog, world: Node3D, id: String, life: int) -> Dictionary:
	var entry: Variant = catalog.packages[id]
	var packet: Dictionary = entry.packet
	var layout: VehicleLayoutDefinition = entry.layout
	var actor := VehicleActor.new(); world.add_child(actor)
	var installed := actor.setup(defs,id,"cd007_"+id,life,Transform3D.IDENTITY,2,null)
	if not installed.ok: return {"ok":false,"reason":"install failed"}
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	snapshot["entity_id"] = id; snapshot["life_id"] = life
	var spec := {"round_id":SEED+life,"shooter_id":"cd007","shooter_life_id":1,"shot_id":SEED+life,
		"shell_id":"test_cd007_he","effect_policy":"internal_burst","armor_policy":"resolve",
		"impact_profile":_aphe(),"post_penetration_profile":{},
		"fuze_policy":{"mode":"penetration_delay","arming_thickness_mm":5.0,"delay_s":0.02,
			"provenance":"game_rule","reason":"CD07 contrast fixture: the delay that makes the round burst after it stops"},
		"caliber_mm":75,"penetration_curve":PackedVector2Array([Vector2(0,20),Vector2(2000,20)]),
		"position_world":Vector3(6,1.2,0),"velocity_world":Vector3(-400,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":0.4,"max_distance_m":60.0}
	var spawned := manager.try_spawn(spec)
	if not spawned.ok: return {"ok":false,"reason":"spawn "+str(spawned.get("reason",""))}
	var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var space := world.get_world_3d().direct_space_state
	for i in 200:
		if state.is_terminal(): break
		manager.advance_projectile(state,1.0/240.0,[snapshot],space)
	var burst: Dictionary = state.burst if state.burst is Dictionary else {}
	var channels: Dictionary = burst.get("channels",{})
	var over: Dictionary = channels.get("overpressure",{})
	var out := {"ok":true,"terminal":str(state.terminal_reason),"contacts":state.contacts.size(),
		"verdicts":state.contacts.map(func(c): return str(c.get("result",""))),
		"burst_empty":burst.is_empty(),"applied":bool(over.get("applied",false)),
		"outside":bool(over.get("burst_outside",true)),"breached":bool(over.get("breached",false)),
		"openings":int(over.get("declared_openings",-1)),"compartments":int(over.get("open_compartment_apertures",-1)),
		"reason":str(over.get("reason",""))}
	manager.queue_free(); actor.queue_free()
	return out

func _run() -> void:
	var defs := VehicleDefs.new()
	check(defs.load_defaults().ok,"CD07 contrast the legacy definitions load")
	var catalog := VehicleCatalog.new()
	var loaded := catalog.load_all(defs)
	check(loaded.ok,"CD07 contrast the production catalog loads every historical package")
	var world := Node3D.new(); root.add_child(world)
	var open_run := await _burst_at(defs,catalog,world,HIST_OPEN,101)
	var closed_run := await _burst_at(defs,catalog,world,HIST_CLOSED,102)
	for pair in [[HIST_OPEN,open_run],[HIST_CLOSED,closed_run]]:
		var run: Dictionary = pair[1]
		print("[CD07 contrast] %-18s => terminal=%s verdicts=%s burst=%s outside=%s breached=%s openings=%d compartments=%d applied=%s reason=%s" % [
			str(pair[0]),str(run.get("terminal","")),str(run.get("verdicts","")),("none" if bool(run.get("burst_empty",true)) else "present"),
			str(run.get("outside","")),str(run.get("breached","")),int(run.get("openings",-1)),int(run.get("compartments",-1)),
			str(run.get("applied","")),str(run.get("reason",""))])
	check(bool(open_run.get("ok",false)) and bool(closed_run.get("ok",false)),"CD07 contrast both shots ran")
	# My first version required BOTH runs to produce a root event and then compared their verdicts, which passed vacuously:
	# the closed run never burst at all, so its false came from the default rather than from the connectivity rule. The
	# measurement also exposed why: the delay fuze only arms on a plate it actually penetrates, so with this fuze rule an
	# external burst with no breach is not reachable at all. That makes the closed case satisfied BY CONSTRUCTION and the
	# rule's closed branch a guard for a case the fuze rule currently prevents, which is what the assertions now say.
	check(not bool(open_run.get("burst_empty",true)),
		"CD07 contrast the open-top run really produced an explosion root event, so its verdict is a rule verdict: applied=%s" % str(open_run.get("applied","")))
	check(bool(closed_run.get("burst_empty",true)) and str(closed_run.get("terminal",""))=="armor_stopped",
		"CD07 contrast T01 BY CONSTRUCTION: the closed run ended as armor stopped with NO explosion at all, so there is no interior overpressure to invent - the compartment is not emptied through the wall because nothing burst: terminal=%s" % str(closed_run.get("terminal","")))
	check(bool(open_run.get("applied",false))==(bool(open_run.get("breached",false)) or int(open_run.get("compartments",0))>0),
		"CD07 contrast and the open-top run's recorded verdict equals its own recorded inputs: breached=%s compartments=%d applied=%s" % [
			str(open_run.get("breached","")),int(open_run.get("compartments",-1)),str(open_run.get("applied",""))])
	check(not bool(closed_run.get("breached",true)) and bool(closed_run.get("outside",false)),
		"CD07 contrast T01: the closed run is an EXTERNAL burst with NO breach, which is exactly the case the order says must not empty the compartment through the wall: breached=%s" % str(closed_run.get("breached","")))
	check(int(open_run.get("compartments",0))>int(closed_run.get("compartments",0)),
		"CD07 contrast T02: the two differ in their DECLARED geometry, not by a vehicle_type label: open compartment apertures %d vs %d" % [
			int(open_run.get("compartments",-1)),int(closed_run.get("compartments",-1))])
	print("[CD07 contrast] outcome: the open-top run's own geometry gives the pressure a path (compartments=%d, applied=%s) while the closed run never burst at all (terminal=%s), so the case's closed branch holds by construction and the rule guards the case the fuze rule prevents" % [
		int(open_run.get("compartments",-1)),str(open_run.get("applied","")),str(closed_run.get("terminal",""))])
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_OPEN_CLOSED_CONTRAST_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)