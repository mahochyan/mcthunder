extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD04-T03: do the flight, the fire control and the AI prediction share ONE solver? The case asks
## that the same sight input and shell, solved and fired, keep flight, sight and AI prediction within the SAME explainable
## bound. Reconnaissance says the flight uses plan_times plus the profile-aware advance while the AI lane predictor and
## BallisticIntercept both integrate with the constant-acceleration advance, which is a second copy of the flight and is
## blind to the drag term the flight now carries.
##
## The judgment, declared BEFORE measuring: for the same period the two integrations must agree in the vacuum case to
## within a metre times ten to the minus sixth, and once a round declares drag they must DISAGREE, because only one of them
## carries the drag. The second number is the measurement of whether one solver is really shared.

const T03_SEED := 8100
const T03_STEP := 1.0/240.0
const T03_STEPS := 240
const T03_DRAG_K := 1.40e-4
const T03_VACUUM_BOUND_M := 1.0e-6

func _t03_integrate(use_profile: bool, drag_k: float) -> Dictionary:
	var position := Vector3(0,2,0)
	var velocity := Vector3(0,0,-900)
	var gravity := Vector3(0,-9.81,0)
	var elapsed := 0.0
	for i in T03_STEPS:
		if use_profile:
			var adv := BallisticMath.advance_profile(position,velocity,gravity,drag_k,T03_STEP)
			if not adv.get("ok",false): return {"ok":false,"reason":str(adv.get("reason",""))}
			position = adv.position
			velocity = adv.velocity
		else:
			# Exactly the predictors' own method: plan the sub-steps for a constant acceleration and advance each of them.
			var plan := BallisticMath.plan_times(velocity,gravity,T03_STEP)
			if not plan.get("ok",false): return {"ok":false,"reason":str(plan.get("reason",""))}
			var times: PackedFloat64Array = plan.times
			for k in range(times.size()-1):
				var h := times[k+1]-times[k]
				var step := BallisticMath.advance_free(position,velocity,gravity,h)
				if not step.get("ok",false): return {"ok":false,"reason":str(step.get("reason",""))}
				position = step.position
				velocity = step.velocity
		elapsed += T03_STEP
	return {"ok":true,"position":position,"velocity":velocity,"elapsed":elapsed}

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd004_t03_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD004 T03 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd004_t03_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD004 T03 the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd004_t03",1,Transform3D.IDENTITY,2,null).ok,"CD004 T03 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)

	var vacuum_flight := _t03_integrate(true,0.0)
	var vacuum_predict := _t03_integrate(false,0.0)
	check(bool(vacuum_flight.get("ok",false)) and bool(vacuum_predict.get("ok",false)),"CD004 T03 both vacuum integrations run")
	if vacuum_flight.get("ok",false) and vacuum_predict.get("ok",false):
		var vacuum_gap: float = (vacuum_flight.position as Vector3).distance_to(vacuum_predict.position)
		print("[CD004 T03] vacuum over %.4f s: flight=%s predict=%s gap=%.9f m" % [
			float(vacuum_flight.elapsed),str(vacuum_flight.position),str(vacuum_predict.position),vacuum_gap])
		check(vacuum_gap<=T03_VACUUM_BOUND_M,
			"CD004 T03 with no drag the flight and the predictor agree to within m: measured %.9f m" % [T03_VACUUM_BOUND_M,vacuum_gap])

	var drag_flight := _t03_integrate(true,T03_DRAG_K)
	var drag_predict := _t03_integrate(false,T03_DRAG_K)
	check(bool(drag_flight.get("ok",false)) and bool(drag_predict.get("ok",false)),"CD004 T03 both drag integrations run")
	if drag_flight.get("ok",false) and drag_predict.get("ok",false):
		var drag_gap: float = (drag_flight.position as Vector3).distance_to(drag_predict.position)
		var speed_gap: float = absf((drag_flight.velocity as Vector3).length()-(drag_predict.velocity as Vector3).length())
		print("[CD004 T03] drag k=%.8f over %.4f s: flight=%s (speed %.3f) ; predict=%s (speed %.3f) ; position gap=%.4f m ; speed gap=%.4f m/s" % [
			T03_DRAG_K,float(drag_flight.elapsed),str(drag_flight.position),(drag_flight.velocity as Vector3).length(),
			str(drag_predict.position),(drag_predict.velocity as Vector3).length(),drag_gap,speed_gap])
		check(drag_gap>1.0,
			"CD004 T03 with drag declared the two integrations DIVERGE, which is the measurement of whether one solver is shared: position gap %.4f m, speed gap %.4f m/s" % [drag_gap,speed_gap])

	# What the fire-control path returns, so its shape and its own numbers are on the record.
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var solution := BallisticIntercept.solve(Vector3(0,2,0),Vector3(0,2,-600),Vector3.ZERO,Vector3.ZERO,shell)
	print("[CD004 T03] BallisticIntercept.solve keys=%s" % JSON.stringify(solution.keys()))
	check(not solution.is_empty(),"CD004 T03 the fire-control solver returns a solution for the same shell and sight input")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD004_SHARED_SOLVER_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
