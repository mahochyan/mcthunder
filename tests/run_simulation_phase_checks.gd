extends SceneTree
class SupplyRange extends TeamRange:
	func supply_positions(_team: int) -> Array[Vector3]: return [Vector3.ZERO]
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func run() -> void:
	var scene := SupplyRange.new()
	root.add_child(scene); current_scene = scene
	await frames(190)
	if OS.get_cmdline_user_args().has("--old-supply-order"): scene.process_physics_priority=0
	for actor in scene.combat_actors(): actor.set_controller(null)
	var actor := scene.actor
	actor.tank.global_position=Vector3(0,0.03,0)
	await frames(10)
	actor.gunner.inventory.consume_chamber() # Explicit deficit fixture; no fictitious projectile.
	var before := actor.gunner.rounds_remaining
	scene.ammunition_supply.clocks[str(actor.life_id)] = 1.99
	var cmd := VehicleCommand.new(); cmd.throttle=1
	actor.submit_command(cmd)
	await frames(1)
	check(actor.gunner.rounds_remaining==before,"same-tick driving prevents nearly-complete parked resupply")
	var snap := scene.simulation_snapshot.read()
	check(snap.version==2 and snap.match_id==scene.director.state.match_id and snap.vehicles.size()==8,"versioned snapshot identifies actual match and all live roster vehicles")
	check(snap.vehicles.all(func(row: Dictionary) -> bool: return VehicleFramePose.valid(row.get("frame_pose"))),"snapshot includes every vehicle's relative hull and running gear poses")
	var own: Dictionary = snap.vehicles.filter(func(v: Dictionary) -> bool: return v.entity_id==actor.entity_id)[0]
	check(own.suspension==actor.tank.suspension.snapshot() and own.suspension.version==1,"snapshot captures same-tick spring integration state")
	own.suspension.displacement[0]=999.0
	check(actor.tank.suspension.displacement[0]!=999.0 and scene.simulation_snapshot.read().vehicles.all(func(row: Dictionary) -> bool: return row.suspension.displacement[0]!=999.0),"spring arrays are isolated from snapshot consumers")
	check(own.position==actor.tank.global_position and own.cooldown==actor.gunner.cooldown_left and own.ammunition==actor.gunner.inventory.shell_counts(),"snapshot observes committed movement and weapon state")
	check(snap.elapsed==scene.director.state.elapsed and snap.tickets==scene.director.state.tickets,"snapshot observes current director tick rather than previous match state")
	snap.vehicles[0].position=Vector3.INF; snap.tickets[1]=-99
	check(scene.simulation_snapshot.read().vehicles[0].position.is_finite() and scene.simulation_snapshot.read().tickets[1]>=0,"consumer cannot mutate authoritative cached snapshot")
	paused=true
	var sequence := scene.simulation_snapshot.sequence
	for i in 5: await process_frame
	check(scene.simulation_snapshot.sequence==sequence,"pause stops snapshot sequence with simulation")
	paused=false
	scene.director.state.elapsed=TeamMatchState.TIME_LIMIT-0.001 # Boundary fixture, not a natural full match.
	await frames(1)
	var final_state := scene.simulation_snapshot.read()
	check(final_state.phase=="finished" and final_state.result==scene.director.state.result,"final snapshot includes same-tick match result")
	await frames(4)
	check(scene.simulation_snapshot.sequence==final_state.sequence,"finished match retains one final snapshot without endless copying")
	scene.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("SIMULATION_PHASE_CHECKS_PASS" if failed==0 else "SIMULATION_PHASE_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
