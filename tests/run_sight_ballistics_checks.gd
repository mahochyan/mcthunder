extends SceneTree
## Run: godot --headless --path <project> -s res://tests/run_sight_ballistics_checks.gd
## This suite verifies inverse aiming with the production free-flight math.
## Collision queries, weapon path limits and moving launchers need integration
## coverage at their callers; none is modeled by this stationary solver.

const Solver = preload("res://scripts/projectiles/sight_ballistics.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + message)

func flight_shell(speed: float = 600.0, gravity: float = 1.0, lifetime: float = 30.0) -> ShellDefinition:
	var shell := ShellDefinition.new()
	shell.muzzle_velocity_mps = speed
	shell.gravity_scale = gravity
	shell.max_flight_time_s = lifetime
	return shell

func rejected(result: Dictionary, reason: String, label: String) -> void:
	check(not result.ok and result.reason == reason and result.direction == Vector3.ZERO and result.time_s == 0.0, label)

func run() -> void:
	# These endpoints are evaluated by a separate production forward integrator,
	# not by repeating the inverse solver's quadratic inside the assertion.
	var muzzle := Vector3(12.0, 4.0, -7.0)
	var cases: Array = [
		[50.0, Vector3(3, 0, -20), 1.0],
		[100.0, Vector3(200, 50, -300), 1.0],
		[400.0, Vector3(1200, -80, -800), 1.0],
		[619.0, Vector3(-300, 125, -1800), 1.0],
		[792.0, Vector3(1000, -125, -3600), 1.0],
		[100.0, Vector3(0, 0, -500), 2.0],
		[600.0, Vector3(0, 0, -1000), 0.0],
		[100000.0, Vector3(0, 0, -1), 1.0],
		[50.0, Vector3(0, 20, 0), 1.0],
		[50.0, Vector3(0, -20, 0), 1.0],
		[50.0, Vector3(0, 0.001, -0.001), 1.0],
		[500.0, Vector3(0, 0, -1000), 1.0e-12]
	]
	for index in cases.size():
		var data: Array = cases[index]
		var shell := flight_shell(data[0], data[2])
		var target: Vector3 = muzzle + data[1]
		var solved: Dictionary = Solver.solve(muzzle, target, shell)
		check(solved.ok, "reachable stationary trajectory %d" % index)
		if not solved.ok:
			continue
		var direction: Vector3 = solved.direction
		check(direction.is_finite() and absf(direction.length() - 1.0) < 0.000001 and solved.time_s > 0.0 and solved.time_s <= shell.max_flight_time_s, "finite unit launch direction and allowed time %d" % index)
		var gravity := Vector3(0, -9.81, 0) * shell.gravity_scale
		var endpoint := BallisticMath.advance_free(muzzle, direction * shell.muzzle_velocity_mps, gravity, solved.time_s)
		var error: float = endpoint.position.distance_to(target) if endpoint.ok else INF
		check(endpoint.ok and error < 0.003, "production analytic integrator reaches target within 3mm %d, error=%.7fm" % [index, error])
		if index in [1, 3, 4]:
			check_fixed_steps(muzzle, target, direction * shell.muzzle_velocity_mps, gravity, solved.time_s, index)
		if index in [8, 9]:
			check(direction == (Vector3.UP if index == 8 else Vector3.DOWN), "vertical target selects earliest upward/downward path %d" % index)
	check_low_arc_and_lifetime()
	check_invalid_inputs(muzzle)
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks, failures])
	print("SIGHT_BALLISTICS_CHECKS_PASS" if failures == 0 else "SIGHT_BALLISTICS_CHECKS_FAIL")
	quit(0 if failures == 0 else 1)

func check_fixed_steps(muzzle: Vector3, target: Vector3, initial_velocity: Vector3, gravity: Vector3, duration: float, index: int) -> void:
	var position := muzzle
	var velocity := initial_velocity
	var elapsed := 0.0
	var integrated := true
	# An integer bound ensures the verifier terminates even if a broken solver
	# returns a bad duration. Test cases finish in less than 30 simulated seconds.
	for _tick in range(1801):
		var remaining := duration - elapsed
		if remaining <= BallisticMath.TIME_EPS:
			break
		var step := minf(1.0 / 60.0, remaining)
		var plan := BallisticMath.plan_times(velocity, gravity, step)
		if not plan.ok:
			integrated = false
			break
		for segment in range(plan.times.size() - 1):
			var advanced := BallisticMath.advance_free(position, velocity, gravity, plan.times[segment + 1] - plan.times[segment])
			if not advanced.ok:
				integrated = false
				break
			position = advanced.position
			velocity = advanced.velocity
		if not integrated:
			break
		elapsed += step
	check(integrated and duration - elapsed <= BallisticMath.TIME_EPS and position.distance_to(target) < 0.05, "production 60Hz substeps reach target within 5cm %d, error=%.7fm" % [index, position.distance_to(target)])

func check_low_arc_and_lifetime() -> void:
	var flat_shell := flight_shell(100.0)
	var flat: Dictionary = Solver.solve(Vector3.ZERO, Vector3(0, 0, -500), flat_shell)
	var expected_angle := 0.5 * asin(9.81 * 500.0 / (100.0 * 100.0))
	check(flat.ok and absf(asin(float(flat.direction.y)) - expected_angle) < 0.000001 and flat.time_s < 100.0 / 9.81, "same-height solution selects analytic low arc instead of high arc")
	var maximum: Dictionary = Solver.solve(Vector3.ZERO, Vector3(0, 0, -981), flight_shell(98.1))
	check(maximum.ok and absf(float(maximum.direction.y) - sqrt(0.5)) < 0.000001, "maximum-range tangent remains a reachable 45-degree solution")
	rejected(Solver.solve(Vector3.ZERO, Vector3(0, 0, -982), flight_shell(98.1)), "unreachable", "beyond maximum range is rejected")
	rejected(Solver.solve(Vector3.ZERO, Vector3(0, 600, 0), flight_shell(100.0)), "unreachable", "vertical target above maximum apex is rejected")
	var apex: Dictionary = Solver.solve(Vector3.ZERO, Vector3(0, 490.5, 0), flight_shell(98.1))
	check(apex.ok and apex.direction == Vector3.UP and absf(apex.time_s - 10.0) < 0.000001, "vertical maximum apex accepts the single tangent solution")
	var zero: Dictionary = Solver.solve(Vector3.ZERO, Vector3(30, 40, 0), flight_shell(50.0, 0.0, 1.0))
	check(zero.ok and zero.time_s == 1.0 and zero.direction.is_equal_approx(Vector3(0.6, 0.8, 0)), "zero gravity is direct and accepts the exact lifetime endpoint")
	rejected(Solver.solve(Vector3.ZERO, Vector3(30, 40, 0), flight_shell(50.0, 0.0, 0.999)), "flight_time_exceeded", "zero-gravity path just beyond lifetime is rejected")
	if flat.ok:
		flat_shell.max_flight_time_s = flat.time_s
		check(Solver.solve(Vector3.ZERO, Vector3(0, 0, -500), flat_shell).ok, "gravitational path at exact lifetime endpoint is accepted")
		flat_shell.max_flight_time_s -= 0.000001
		rejected(Solver.solve(Vector3.ZERO, Vector3(0, 0, -500), flat_shell), "flight_time_exceeded", "gravitational path just beyond lifetime is rejected")
	var moved: Dictionary = Solver.solve(Vector3(19, -27, 33), Vector3(519, -27, 33), flight_shell(100.0))
	check(flat.ok and moved.ok and absf(flat.time_s - moved.time_s) < 0.000001 and moved.direction.is_equal_approx(flat.direction.rotated(Vector3.UP, -PI / 2.0)), "translation and horizontal bearing preserve the same trajectory")

func check_invalid_inputs(muzzle: Vector3) -> void:
	rejected(Solver.solve(muzzle, muzzle, flight_shell()), "coincident_target", "coincident target does not manufacture an aiming direction")
	rejected(Solver.solve(muzzle, Vector3.ZERO, null), "missing_shell", "missing shell is rejected")
	for vector in [Vector3.INF, Vector3(NAN, 0, 0)]:
		rejected(Solver.solve(vector, Vector3.ZERO, flight_shell()), "non_finite_position", "nonfinite muzzle is rejected")
		rejected(Solver.solve(Vector3.ZERO, vector, flight_shell()), "non_finite_position", "nonfinite target is rejected")
	var reasons := {"muzzle_velocity_mps": "invalid_muzzle_speed", "gravity_scale": "invalid_gravity", "max_flight_time_s": "invalid_flight_time"}
	for field in reasons:
		for invalid in [NAN, INF, -1.0]:
			var shell := flight_shell()
			shell.set(field, invalid)
			rejected(Solver.solve(muzzle, Vector3.ZERO, shell), reasons[field], "invalid flight parameter rejected: %s=%s" % [field, invalid])
	for field in ["muzzle_velocity_mps", "max_flight_time_s"]:
		var shell := flight_shell()
		shell.set(field, 0.0)
		rejected(Solver.solve(muzzle, Vector3.ZERO, shell), reasons[field], "zero positive-only parameter rejected: " + field)
	rejected(Solver.solve(muzzle, Vector3.ZERO, flight_shell(1.0e200)), "numeric_overflow", "overflowing finite speed is rejected")
	rejected(Solver.solve(muzzle, Vector3.ZERO, flight_shell(1.0e40)), "numeric_overflow", "launch velocity outside engine Vector3 precision is rejected")
	rejected(Solver.solve(muzzle, Vector3.ZERO, flight_shell(1.0e-200, 0.0)), "numeric_overflow", "underflowing speed squared cannot divide by zero")
	rejected(Solver.solve(muzzle, Vector3.ZERO, flight_shell(600.0, 1.0e308)), "numeric_overflow", "overflowing finite gravity is rejected")
	rejected(Solver.solve(muzzle, Vector3.ZERO, flight_shell(1.0e30, 1.0e40)), "numeric_overflow", "acceleration outside engine Vector3 precision is rejected")
