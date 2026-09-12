extends SceneTree
## Pure inverse-solver checks against actual production forward integration.
## TEST ONLY flight values; no historical vehicle or real weapon performance.
## No AI permission, continuous collision, target acceleration or drag is claimed.

const Solver = preload("res://scripts/projectiles/ballistic_intercept.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)

func shell(speed: float = 300.0, gravity: float = 1.0, lifetime: float = 30.0) -> ShellDefinition:
	var value := ShellDefinition.new()
	value.muzzle_velocity_mps = speed
	value.gravity_scale = gravity
	value.max_flight_time_s = lifetime
	return value

func reject(result: Dictionary, reason: String, label: String) -> void:
	check(not result.ok and result.reason == reason and result.direction == Vector3.ZERO and result.time_s == 0.0, label)

func reaches(label: String, muzzle: Vector3, target: Vector3, target_velocity: Vector3, own_velocity: Vector3, ammunition: ShellDefinition, expected_time: float = -1.0) -> Dictionary:
	var solved := Solver.solve(muzzle, target, target_velocity, own_velocity, ammunition)
	check(solved.ok, label+": solution exists")
	if not solved.ok: return solved
	var direction: Vector3 = solved.direction
	var time: float = solved.time_s
	check(direction.is_finite() and absf(direction.length()-1.0)<1.0e-6 and time>0.0 and time<=ammunition.max_flight_time_s, label+": finite unit barrel direction within lifetime")
	var launched := direction*ammunition.muzzle_velocity_mps+own_velocity
	var gravity := Vector3(0,-9.81,0)*ammunition.gravity_scale
	var result := BallisticMath.advance_free(muzzle, launched, gravity, time)
	var predicted := target+target_velocity*time
	var error: float = result.position.distance_to(predicted) if result.ok else INF
	check(result.ok and error<0.006, label+": production constant-acceleration flight intercepts the moving point within 6 mm; error=%.8f m"%error)
	if expected_time>0.0:
		check(absf(time-expected_time)<1.0e-7*maxf(1.0,expected_time), label+": earliest time agrees with independent analytic case")
	return solved

func run() -> void:
	var muzzle := Vector3(12,4,-7)
	reaches("zero-gravity lateral relative motion", muzzle, muzzle+Vector3(0,0,-500), Vector3(25,0,0), Vector3(10,0,0), shell(100,0,10), 500.0/sqrt(10000.0-225.0))
	reaches("approaching target", Vector3.ZERO, Vector3(0,0,-500), Vector3(0,0,30), Vector3.ZERO, shell(100,0,10), 500.0/130.0)
	reaches("receding target and moving launcher", Vector3.ZERO, Vector3(0,0,-500), Vector3(0,0,-40), Vector3(0,0,-10), shell(100,0,10), 500.0/70.0)
	var vertical := reaches("mixed vertical motion and inherited own velocity", muzzle, muzzle+Vector3(300,40,-800), Vector3(22,-8,-4), Vector3(5,4,2), shell())
	if vertical.ok: fixed_steps(muzzle, muzzle+Vector3(300,40,-800), Vector3(22,-8,-4), Vector3(5,4,2), shell(), vertical)
	reaches("target below shooter", Vector3(100,80,40), Vector3(-150,5,-400), Vector3(-20,2,8), Vector3(12,-3,-7), shell(200))
	reaches("very close target retains a positive time", Vector3.ZERO, Vector3(0,0,-0.0001), Vector3(1,0,0), Vector3.ZERO, shell(1000))
	var tiny_receding := Vector3(99.999,0,0)
	reaches("almost equal forward speed", Vector3.ZERO, Vector3(0.001,0,0), tiny_receding, Vector3.ZERO, shell(100,0,2), float(Vector3(0.001,0,0).x)/(100.0-float(tiny_receding.x)))
	check_shared_stationary()
	check_long_flight()
	check_tangencies_and_roots()
	check_lifetime()
	check_constructed()
	check_invalid()
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("BALLISTIC_INTERCEPT_CHECKS_PASS" if failures==0 else "BALLISTIC_INTERCEPT_CHECKS_FAIL")
	quit(0 if failures==0 else 1)

func check_shared_stationary() -> void:
	var start := Vector3(30,20,-40)
	var target := Vector3(200,70,-800)
	var ammunition := shell(300)
	var stationary := SightBallistics.solve(start,target,ammunition)
	var common_velocity := Vector3(18,2,-6)
	var solved := reaches("equal velocities reuse the stationary relative problem",start,target,common_velocity,common_velocity,ammunition)
	check(stationary.ok and solved.ok and solved.time_s==stationary.time_s and solved.direction==stationary.direction,"relative rest uses the frozen SightBallistics low arc without duplicating its solver")
	var still := reaches("stationary interception",start,target,Vector3.ZERO,Vector3.ZERO,ammunition)
	check(still.ok and solved.ok and solved.time_s==still.time_s and solved.direction==still.direction,"adding a common velocity to both bodies preserves barrel-relative aim")

func check_long_flight() -> void:
	var target := Vector3(0,0,-700)
	var target_velocity := Vector3(20,0,0)
	var own_velocity := Vector3(-10,0,0)
	var ammunition := shell(200,1,20)
	var solved := reaches("flight longer than old two-second lead cap",Vector3.ZERO,target,target_velocity,own_velocity,ammunition)
	if not solved.ok: return
	check(solved.time_s>3.5,"long interception retains its actual flight time instead of truncating to two seconds")
	# Reproduce the specific OLD approximation only as a mutation counterexample;
	# the passing result above is checked with the independent forward integrator.
	var old_point := target+(target_velocity-own_velocity)*2.0+Vector3.UP*(0.5*9.81*4.0)
	var old_flight := BallisticMath.advance_free(Vector3.ZERO,old_point.normalized()*200.0+own_velocity,Vector3(0,-9.81,0),solved.time_s)
	check(old_flight.ok and old_flight.position.distance_to(target+target_velocity*solved.time_s)>30.0,"old two-second approximate compensation misses the same moving encounter by over 30 m")
	# Forgetting inherited velocity must also turn this case red.
	var wrong := BallisticMath.advance_free(Vector3.ZERO,solved.direction*200.0,Vector3(0,-9.81,0),solved.time_s)
	check(wrong.ok and wrong.position.distance_to(target+target_velocity*solved.time_s)>30.0,"omitting the production launcher's inherited velocity causes a measurable miss")

func check_tangencies_and_roots() -> void:
	# Exact zero-gravity tangent: 30^2+(40-50t)^2=(30t)^2.
	reaches("zero-gravity double root without a sign change",Vector3.ZERO,Vector3(30,40,0),Vector3(0,-50,0),Vector3.ZERO,shell(30,0,10),1.25)
	reject(Solver.solve(Vector3.ZERO,Vector3(30.01,40,0),Vector3(0,-50,0),Vector3.ZERO,shell(30,0,10)),"no_intercept_within_lifetime","just beyond zero-gravity tangent is not manufactured into a solution")
	# Gravity 100 m/s2 is a TEST ONLY exactly representable acceleration. The
	# target rises at 50 m/s; a 100 m/s upward launch catches its 12.5 m lead at
	# the relative apex t=0.5, a repeated root of the quartic.
	reaches("gravitational tangent with moving target",Vector3.ZERO,Vector3(0,12.5,0),Vector3(0,50,0),Vector3.ZERO,shell(100,100.0/9.81,10),0.5)
	reject(Solver.solve(Vector3.ZERO,Vector3(0,12.51,0),Vector3(0,50,0),Vector3.ZERO,shell(100,100.0/9.81,10)),"no_intercept_within_lifetime","above moving relative apex is unreachable")
	# This vertical encounter has FOUR positive roots. The first is the upward
	# interception before the approaching target crosses the muzzle; later down
	# and returning paths must never win.
	var first_time := 40.0/(130.0+sqrt(130.0*130.0-2.0*9.81*20.0))
	var four := reaches("four-positive-root vertical encounter",Vector3.ZERO,Vector3(0,20,0),Vector3(0,-80,0),Vector3.ZERO,shell(50,1,30),first_time)
	check(four.ok and four.direction==Vector3.UP and four.time_s<0.2,"four-root encounter selects earliest upward interception, not a later downward or high arc")
	reaches("degenerate zero-gravity linear equation",Vector3.ZERO,Vector3(100,0,0),Vector3(-100,0,0),Vector3.ZERO,shell(100,0,2),0.5)
	reject(Solver.solve(Vector3.ZERO,Vector3(100,0,0),Vector3(100,0,0),Vector3.ZERO,shell(100,0,20)),"no_intercept_within_lifetime","equal-speed receding target cannot be caught")
	reject(Solver.solve(Vector3.ZERO,Vector3(100,0,0),Vector3(101,0,0),Vector3.ZERO,shell(100,0,20)),"no_intercept_within_lifetime","faster receding target cannot be caught")

func check_lifetime() -> void:
	reaches("zero-gravity inclusive lifetime",Vector3.ZERO,Vector3(100,0,0),Vector3(10,0,0),Vector3.ZERO,shell(110,0,1),1.0)
	reject(Solver.solve(Vector3.ZERO,Vector3(100,0,0),Vector3(10,0,0),Vector3.ZERO,shell(110,0,0.999999)),"no_intercept_within_lifetime","one microsecond before interception does not permit a post-lifetime hit")
	reaches("gravitational inclusive lifetime",Vector3.ZERO,Vector3(30,22.5,0),Vector3(0,10,0),Vector3.ZERO,shell(100,100.0/9.81,0.5),0.5)
	reject(Solver.solve(Vector3.ZERO,Vector3(30,22.5,0),Vector3(0,10,0),Vector3.ZERO,shell(100,100.0/9.81,0.499999)),"no_intercept_within_lifetime","gravitational root after lifetime is rejected")
	reaches("tangent exactly at lifetime",Vector3.ZERO,Vector3(0,12.5,0),Vector3(0,50,0),Vector3.ZERO,shell(100,100.0/9.81,0.5),0.5)

func check_constructed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=710203
	for index in 12:
		var ammunition := shell(rng.randf_range(100,800),0.0 if index%3==0 else 1.0,20)
		var start := Vector3(rng.randf_range(-100,100),rng.randf_range(0,50),rng.randf_range(-100,100))
		var own := Vector3(rng.randf_range(-25,25),rng.randf_range(-3,3),rng.randf_range(-25,25))
		var target_velocity := Vector3(rng.randf_range(-40,40),rng.randf_range(-5,5),rng.randf_range(-40,40))
		var direction := Vector3(rng.randf_range(-1,1),rng.randf_range(-0.1,0.4),-1).normalized()
		var known_time := rng.randf_range(0.1,8.0)
		var endpoint := BallisticMath.advance_free(start,direction*ammunition.muzzle_velocity_mps+own,Vector3(0,-9.81,0)*ammunition.gravity_scale,known_time)
		var target: Vector3=endpoint.position-target_velocity*known_time
		var solved := reaches("forward-constructed encounter %d"%index,start,target,target_velocity,own,ammunition)
		check(solved.ok and solved.time_s<=known_time+0.0001,"constructed case %d chooses no later than the known feasible intercept"%index)

func fixed_steps(start: Vector3, target: Vector3, target_velocity: Vector3, own_velocity: Vector3, ammunition: ShellDefinition, solved: Dictionary) -> void:
	var position := start
	var velocity: Vector3=solved.direction*ammunition.muzzle_velocity_mps+own_velocity
	var gravity := Vector3(0,-9.81,0)*ammunition.gravity_scale
	var elapsed := 0.0
	var valid := true
	for _tick in 1801:
		var remaining: float=solved.time_s-elapsed
		if remaining<=BallisticMath.TIME_EPS: break
		var step := minf(1.0/60.0,remaining)
		var plan := BallisticMath.plan_times(velocity,gravity,step)
		if not plan.ok:
			valid=false
			break
		for part in range(plan.times.size()-1):
			var advanced := BallisticMath.advance_free(position,velocity,gravity,plan.times[part+1]-plan.times[part])
			if not advanced.ok:
				valid=false
				break
			position=advanced.position
			velocity=advanced.velocity
		if not valid: break
		elapsed+=step
	check(valid and solved.time_s-elapsed<=BallisticMath.TIME_EPS and position.distance_to(target+target_velocity*solved.time_s)<0.05,"actual production 60 Hz subdivided flight meets the moving point within 5 cm")

func check_invalid() -> void:
	reject(Solver.solve(Vector3.ZERO,Vector3.ONE,Vector3.ZERO,Vector3.ZERO,null),"missing_shell","missing flight definition is rejected")
	reject(Solver.solve(Vector3.ONE,Vector3.ONE,Vector3(10,0,0),Vector3.ZERO,shell()),"coincident_target","coincident target rejects direction even when a future re-encounter exists")
	for bad in [Vector3.INF,Vector3(NAN,0,0)]:
		reject(Solver.solve(bad,Vector3.ONE,Vector3.ZERO,Vector3.ZERO,shell()),"non_finite_position","nonfinite muzzle rejected")
		reject(Solver.solve(Vector3.ZERO,bad,Vector3.ZERO,Vector3.ZERO,shell()),"non_finite_position","nonfinite target rejected")
		reject(Solver.solve(Vector3.ZERO,Vector3.ONE,bad,Vector3.ZERO,shell()),"non_finite_velocity","nonfinite observed target velocity rejected")
		reject(Solver.solve(Vector3.ZERO,Vector3.ONE,Vector3.ZERO,bad,shell()),"non_finite_velocity","nonfinite inherited launcher velocity rejected")
	var reasons := {"muzzle_velocity_mps":"invalid_muzzle_speed","gravity_scale":"invalid_gravity","max_flight_time_s":"invalid_flight_time"}
	for field in reasons:
		for value in [NAN,INF,-1.0]:
			var ammunition := shell()
			ammunition.set(field,value)
			reject(Solver.solve(Vector3.ZERO,Vector3.ONE,Vector3.ONE,Vector3.ZERO,ammunition),reasons[field],"invalid field %s rejected: %s"%[field,value])
	for field in ["muzzle_velocity_mps","max_flight_time_s"]:
		var ammunition := shell()
		ammunition.set(field,0.0)
		reject(Solver.solve(Vector3.ZERO,Vector3.ONE,Vector3.ONE,Vector3.ZERO,ammunition),reasons[field],"zero positive-only flight field rejected: "+field)
	reject(Solver.solve(Vector3.ZERO,Vector3.ONE,Vector3.ONE,Vector3.ZERO,shell(300,1.0e100)),"numeric_overflow","gravity beyond production Vector3 range is rejected")
	var underflow := Solver.solve(Vector3.ZERO,Vector3.ONE,Vector3.ONE,Vector3.ZERO,shell(1.0e-200,0))
	check(not underflow.ok and underflow.reason=="numeric_resolution" and underflow.direction==Vector3.ZERO,"underflowed shot displacement cannot create a plausible direction")
	var extreme_common := Vector3(0,1.0e38,0)
	reject(Solver.solve(Vector3.ZERO,Vector3(1000,0,0),extreme_common,extreme_common,shell(100,0,20)),"numeric_overflow","finite relative intercept rejects shared world displacement that overflows production Vector3")
	var large_origin := Vector3(0,2.0e38,0)
	var finite_motion := Vector3(0,2.0e38,0)
	reject(Solver.solve(large_origin,Vector3(1000,large_origin.y,0),finite_motion,finite_motion,shell(1000,0,2)),"numeric_overflow","world position plus finite common displacement must remain finite in production")
	reject(Solver.solve(Vector3.ZERO,Vector3(0,-20,0),Vector3(0,-1.0e8,0),Vector3.ZERO,shell(10,1,1.0e9)),"numeric_resolution","ill-conditioned near-tangent coefficients cannot normalize a nonunit candidate into a claimed earliest intercept")
