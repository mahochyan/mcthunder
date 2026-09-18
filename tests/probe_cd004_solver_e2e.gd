extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD04-T03, end to end: at the time the fire-control solver itself predicts, does the method the
## FLIGHT uses arrive at the target? Two different code paths are compared, so neither is checking itself:
##   * the fire control runs BallisticIntercept.solve, its own root finding with its own verification;
##   * the flight's method is the step integration the manager uses, plan_times plus the profile-aware advance.
## The judgment, declared before measuring: in the vacuum case the flight must reach the target within a hundredth of a
## metre at the solver's own time, and with a declared drag profile it must do the SAME, because both now resolve their
## coefficient from the same shell field. Before the shared-solver change the drag case was fifty-two metres out.

const T03_E2E_BOUND_M := 0.01
const T03_E2E_STEP := 1.0/240.0

## The flight's own method, stopped exactly at the requested time.
func _t03_e2e_fly(muzzle: Vector3, velocity: Vector3, gravity: Vector3, drag_k: float, total_time: float) -> Vector3:
	var position := muzzle
	var current := velocity
	var remaining := total_time
	while remaining > BallisticMath.TIME_EPS:
		var step := minf(T03_E2E_STEP,remaining)
		var plan := BallisticMath.plan_times(current,gravity,step)
		if not plan.get("ok",false): return position
		var times: PackedFloat64Array = plan.times
		for k in range(times.size()-1):
			var h := times[k+1]-times[k]
			var adv := BallisticMath.advance_profile(position,current,gravity,drag_k,h)
			if not adv.get("ok",false): return position
			position = adv.position
			current = adv.velocity
		remaining -= step
	return position

func _t03_e2e_case(actor: VehicleActor, shell: ShellDefinition, label: String, profile_name: String) -> Dictionary:
	shell.ballistics_profile = profile_name
	var drag_k := float(BallisticsProfile.resolve(shell).get("drag_k_per_m",0.0))
	var muzzle := Vector3(0,2,0)
	var target := Vector3(0,2,-600)
	var solution := BallisticIntercept.solve(muzzle,target,Vector3.ZERO,Vector3.ZERO,shell)
	if not bool(solution.get("ok",false)):
		print("[CD004 T03 e2e %s] solver refused: %s" % [label,str(solution.get("reason",""))])
		return {"ok":false}
	var when := float(solution.time_s)
	var launch := (solution.direction as Vector3)*shell.muzzle_velocity_mps
	var gravity := Vector3(0,-9.81,0)*shell.gravity_scale
	var flown := _t03_e2e_fly(muzzle,launch,gravity,drag_k,when)
	var miss := flown.distance_to(target)
	print("[CD004 T03 e2e %s] profile=%s drag_k=%.8f ; solver time=%.6f s ; flown=%s ; target=%s ; miss=%.6f m" % [
		label,(profile_name if not profile_name.is_empty() else "(vacuum)"),drag_k,when,str(flown),str(target),miss])
	return {"ok":true,"miss":miss,"when":when,"drag_k":drag_k}

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd004_t03e_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD004 T03 e2e creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd004_t03e_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD004 T03 e2e the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd004_t03e",1,Transform3D.IDENTITY,2,null).ok,"CD004 T03 e2e the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var original_profile := shell.ballistics_profile

	var vacuum := _t03_e2e_case(actor,shell,"vacuum","")
	check(bool(vacuum.get("ok",false)),"CD004 T03 e2e the solver returns a solution in the vacuum case")
	if vacuum.get("ok",false):
		check(float(vacuum.miss)<=T03_E2E_BOUND_M,
			"CD004 T03 e2e the flight reaches the target at the solver's own time in the vacuum case: miss %.6f m within %.3f m" % [float(vacuum.miss),T03_E2E_BOUND_M])

	var drag := _t03_e2e_case(actor,shell,"drag",BallisticsProfile.PROFILE_QUADRATIC)
	check(bool(drag.get("ok",false)),"CD004 T03 e2e the solver returns a solution with a declared drag profile")
	if drag.get("ok",false):
		check(float(drag.drag_k)>0.0,"CD004 T03 e2e the declared profile really carries a drag coefficient: %.8f" % float(drag.drag_k))
		check(float(drag.miss)<=T03_E2E_BOUND_M,
			"CD004 T03 e2e the flight reaches the target at the solver's own time WITH drag declared, because both resolve the same coefficient: miss %.6f m within %.3f m" % [float(drag.miss),T03_E2E_BOUND_M])
		check(absf(float(drag.when)-float(vacuum.when))>0.01,
			"CD004 T03 e2e the drag case is genuinely different rather than a no-op: solver time %.6f s vs vacuum %.6f s" % [float(drag.when),float(vacuum.when)])
	shell.ballistics_profile = original_profile
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD004_SOLVER_E2E_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
