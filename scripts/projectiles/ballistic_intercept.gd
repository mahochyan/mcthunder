class_name BallisticIntercept
extends RefCounted
## Constant-gravity interception of a point moving at a constant world velocity.
## direction is the barrel-relative unit vector: Gunner still adds own_velocity
## exactly once. No drag, target acceleration, angular muzzle velocity, obstacle
## clearance, mechanical limits or weapon cumulative-path permission is solved.
## Coincident initial points are rejected, even if a later re-encounter exists.
## Mathematical failure never supplies a fallback direction that permits firing.

const DOUBLE_EPS := 2.220446049250313e-16
const POLY_REL_EPS := 64.0 * DOUBLE_EPS
const ROOT_REL_EPS := 2.0e-14
const MAX_BISECTIONS := 192
# Forward error is measured in relative trajectory metres, independent of the
# world's origin. The relative allowance covers standard-precision Vector3.
const FORWARD_ABS_M := 1.0e-6
const FORWARD_REL_EPS := 8.0e-7
const UNIT_LENGTH_SQUARED_EPS := 2.0e-6

## CD004 design point 2: the drag the CURRENT solve resolved from the shell, so the verification inside the root check
## integrates with the same profile-aware advance the flight uses. This call path is single-threaded and the value is set
## at the top of every solve, so no caller can observe a stale coefficient.
static var _drag_k_per_m := 0.0

static func solve(muzzle: Vector3, target: Vector3, target_velocity: Vector3, own_velocity: Vector3, shell: ShellDefinition) -> Dictionary:
	if shell == null: return _failure("missing_shell")
	if not muzzle.is_finite() or not target.is_finite(): return _failure("non_finite_position")
	if not target_velocity.is_finite() or not own_velocity.is_finite(): return _failure("non_finite_velocity")
	var speed := shell.muzzle_velocity_mps
	var gravity_scale := shell.gravity_scale
	_drag_k_per_m = float(BallisticsProfile.resolve(shell).get("drag_k_per_m",0.0))
	var limit := shell.max_flight_time_s
	if not is_finite(speed) or speed <= 0.0: return _failure("invalid_muzzle_speed")
	if not is_finite(gravity_scale) or gravity_scale < 0.0: return _failure("invalid_gravity")
	if not is_finite(limit) or limit <= 0.0: return _failure("invalid_flight_time")
	if muzzle == target: return _failure("coincident_target")
	var gravity := SightBallistics.GRAVITY_MPS2 * gravity_scale
	var production_gravity := Vector3(0.0, -SightBallistics.GRAVITY_MPS2, 0.0) * gravity_scale
	if not is_finite(gravity) or not production_gravity.is_finite(): return _failure("numeric_overflow")
	# Avoid Vector3 subtraction, products and lengths while building coefficients:
	# a standard-precision engine could overflow before GDScript doubles do.
	var r := PackedFloat64Array([float(target.x)-float(muzzle.x), float(target.y)-float(muzzle.y), float(target.z)-float(muzzle.z)])
	var u := PackedFloat64Array([float(target_velocity.x)-float(own_velocity.x), float(target_velocity.y)-float(own_velocity.y), float(target_velocity.z)-float(own_velocity.z)])
	if target_velocity == own_velocity:
		# Relative rest is exactly the already shared stationary low-arc problem.
		var stationary := SightBallistics.solve(muzzle, target, shell)
		if not stationary.ok:
			return _failure("no_intercept_within_lifetime" if stationary.reason in ["unreachable", "flight_time_exceeded"] else stationary.reason)
		return _checked_direction(stationary.direction, stationary.time_s, muzzle, target, r, target_velocity, own_velocity, speed, production_gravity, limit)
	# Solve on x=t/limit in [0,1]. Normalize each displacement before squaring,
	# so the polynomial has dimensionless, bounded coefficients.
	var drift := PackedFloat64Array([u[0]*limit, u[1]*limit, u[2]*limit])
	var fall := 0.5 * gravity * limit * limit
	var shot_distance := speed * limit
	var distance_scale := maxf(absf(fall), absf(shot_distance))
	for i in 3:
		if not is_finite(r[i]) or not is_finite(drift[i]): return _failure("numeric_overflow")
		distance_scale = maxf(distance_scale, maxf(absf(r[i]), absf(drift[i])))
	if not is_finite(distance_scale) or distance_scale <= 0.0: return _failure("numeric_overflow")
	var a := PackedFloat64Array([r[0]/distance_scale, r[1]/distance_scale, r[2]/distance_scale])
	var b := PackedFloat64Array([drift[0]/distance_scale, drift[1]/distance_scale, drift[2]/distance_scale])
	var q := fall/distance_scale
	var s := shot_distance/distance_scale
	# Ascending powers: |a+b*x+UP*q*x^2|^2 - (s*x)^2.
	var coefficients := PackedFloat64Array([
		a[0]*a[0]+a[1]*a[1]+a[2]*a[2],
		2.0*(a[0]*b[0]+a[1]*b[1]+a[2]*b[2]),
		b[0]*b[0]+b[1]*b[1]+b[2]*b[2]+2.0*a[1]*q-s*s,
		2.0*b[1]*q,
		q*q])
	if coefficients[0] <= 0.0 or s*s <= 0.0: return _failure("numeric_resolution")
	for coefficient in coefficients:
		if not is_finite(coefficient): return _failure("numeric_overflow")
	var isolated := _roots_unit_interval(coefficients)
	if not isolated.ok: return _failure("numeric_resolution")
	var roots: PackedFloat64Array = isolated.roots
	for root in roots:
		if root <= 0.0: continue
		var time: float = root * limit
		if not is_finite(time) or time <= 0.0: return _failure("numeric_resolution")
		var direction := Vector3((r[0]/time+u[0])/speed, (r[1]/time+u[1]+0.5*gravity*time)/speed, (r[2]/time+u[2])/speed)
		# Never silently skip an uncertain earlier root and claim a later root is
		# the earliest solution. Insufficient precision is an explicit failure.
		return _checked_direction(direction, time, muzzle, target, r, target_velocity, own_velocity, speed, production_gravity, limit)
	return _failure("no_intercept_within_lifetime")

static func _checked_direction(direction: Vector3, time: float, muzzle: Vector3, target: Vector3, r: PackedFloat64Array, target_velocity: Vector3, own_velocity: Vector3, speed: float, gravity: Vector3, limit: float) -> Dictionary:
	if not direction.is_finite() or direction.length_squared() <= 0.0: return _failure("numeric_overflow")
	if not is_finite(time) or time <= 0.0 or time > limit: return _failure("numeric_resolution")
	# Normalization must not conceal a non-root produced by coefficient
	# cancellation near an ill-conditioned tangent. This check is dimensionless.
	var raw_norm_squared := float(direction.x)*float(direction.x)+float(direction.y)*float(direction.y)+float(direction.z)*float(direction.z)
	if absf(raw_norm_squared-1.0)>UNIT_LENGTH_SQUARED_EPS: return _failure("numeric_resolution")
	# A near-zero polynomial alone is insufficient. Check the actual normalized
	# Vector3 launch, including the production's inherited shooter velocity.
	direction = direction.normalized()
	var relative_launch := direction * speed
	var production_launch := relative_launch + own_velocity
	if not relative_launch.is_finite() or relative_launch == Vector3.ZERO or not production_launch.is_finite(): return _failure("numeric_overflow")
	# Relative coordinates can be well behaved while shared world motion exceeds
	# Vector3 range. Check the actual production operations before accepting it.
	var forward := BallisticMath.advance_profile(muzzle, production_launch, gravity, _drag_k_per_m, time)
	var predicted := target+target_velocity*time
	if not forward.ok or not predicted.is_finite(): return _failure("numeric_overflow")
	var length_scale := 0.0
	var error_scale := 0.0
	for i in 3:
		var movement := (float(production_launch[i])-float(target_velocity[i]))*time
		var acceleration := 0.5*float(gravity[i])*time*time
		var error := movement+acceleration-r[i]
		if not is_finite(movement) or not is_finite(acceleration) or not is_finite(error): return _failure("numeric_overflow")
		length_scale = maxf(length_scale, maxf(absf(r[i]), maxf(absf(movement), absf(acceleration))))
		error_scale = maxf(error_scale, absf(error))
	if error_scale > FORWARD_ABS_M+FORWARD_REL_EPS*length_scale: return _failure("numeric_resolution")
	# CD004 design point 2: with a declared drag the constant-acceleration root above is only a starting point. Refine the
	# direction and the time under the SAME profile-aware integration the flight uses - stepped exactly as the manager steps
	# it, so the two agree by construction rather than by tolerance - and return the refined solution. The whole block is
	# skipped when no drag is declared, which keeps every existing solve bit-identical and the AI suite as its guard.
	if _drag_k_per_m > 0.0:
		var refined_direction := direction
		var refined_time := time
		for _iteration in 8:
			var aim_point: Vector3 = target+target_velocity*refined_time
			var to_target: Vector3 = aim_point-muzzle
			if to_target.length_squared() <= 0.0: break
			refined_direction = to_target.normalized()
			var lo := maxf(1.0e-6, refined_time*0.25)
			var hi := minf(limit, maxf(refined_time*4.0, refined_time+1.0e-3))
			for _bisect_step in 40:
				var mid := lo+(hi-lo)*0.5
				var reached := _integrate_profile(muzzle, refined_direction*speed+own_velocity, gravity, _drag_k_per_m, mid)
				var along := (reached-(target+target_velocity*mid)).dot(refined_direction)
				if along < 0.0: lo = mid
				else: hi = mid
			refined_time = lo+(hi-lo)*0.5
			var final_reached := _integrate_profile(muzzle, refined_direction*speed+own_velocity, gravity, _drag_k_per_m, refined_time)
			if final_reached.distance_to(target+target_velocity*refined_time) <= 1.0e-4: break
		direction = refined_direction
		time = refined_time
	return {"ok":true, "reason":"solved", "direction":direction, "time_s":time}

## CD004 design point 2: the flight's own stepping, mirrored here so the fire control and the flight integrate identically.
static func _integrate_profile(muzzle: Vector3, launch: Vector3, gravity: Vector3, _drag_k_per_m: float, total_time: float) -> Vector3:
	const STEP := 1.0/240.0
	var position := muzzle
	var velocity := launch
	var remaining := total_time
	while remaining > BallisticMath.TIME_EPS:
		var step := minf(STEP,remaining)
		var plan := BallisticMath.plan_times(velocity,gravity,step)
		if not plan.get("ok",false): return position
		var times: PackedFloat64Array = plan.times
		for k in range(times.size()-1):
			var h := times[k+1]-times[k]
			var adv := BallisticMath.advance_profile(position,velocity,gravity,_drag_k_per_m,h)
			if not adv.get("ok",false): return position
			position = adv.position
			velocity = adv.velocity
		remaining -= step
	return position

static func _value(coefficients: PackedFloat64Array, x: float) -> float:
	var result := 0.0
	for i in range(coefficients.size()-1, -1, -1): result = result*x+coefficients[i]
	return result

static func _near_zero(coefficients: PackedFloat64Array, x: float, value: float) -> bool:
	# Roundoff threshold has the same scale as this polynomial evaluation. A
	# fixed absolute epsilon would manufacture roots for close/fast encounters.
	var magnitude := 0.0
	for i in range(coefficients.size()-1, -1, -1): magnitude = magnitude*absf(x)+absf(coefficients[i])
	return absf(value) <= POLY_REL_EPS*magnitude

static func _roots_unit_interval(input: PackedFloat64Array) -> Dictionary:
	var coefficients := input.duplicate()
	while coefficients.size() > 1 and coefficients[-1] == 0.0: coefficients.resize(coefficients.size()-1)
	var roots := PackedFloat64Array()
	var degree := coefficients.size()-1
	if degree == 0: return {"ok":coefficients[0]!=0.0, "roots":roots}
	if degree == 1:
		var root := -coefficients[0]/coefficients[1]
		if is_finite(root) and root >= 0.0 and root <= 1.0: roots.append(root)
		return {"ok":true, "roots":roots}
	var derivative := PackedFloat64Array()
	for i in range(1, coefficients.size()): derivative.append(float(i)*coefficients[i])
	var critical := _roots_unit_interval(derivative)
	if not critical.ok: return {"ok":false, "roots":roots}
	var bounds := PackedFloat64Array([0.0])
	for point in critical.roots:
		if point > 0.0 and point < 1.0: bounds.append(point)
	bounds.append(1.0)
	for i in bounds.size():
		var lo := bounds[i]
		var flo := _value(coefficients, lo)
		if _near_zero(coefficients, lo, flo): _append_distinct(roots, lo)
		if i == bounds.size()-1: break
		var hi := bounds[i+1]
		var fhi := _value(coefficients, hi)
		if _near_zero(coefficients, lo, flo) or _near_zero(coefficients, hi, fhi): continue
		if (flo < 0.0) == (fhi < 0.0): continue
		var bracket := _bisect(coefficients, lo, hi, flo)
		if not bracket.ok: return {"ok":false, "roots":roots}
		_append_distinct(roots, bracket.root)
	return {"ok":true, "roots":roots}

static func _bisect(coefficients: PackedFloat64Array, lo: float, hi: float, flo: float) -> Dictionary:
	for _iteration in MAX_BISECTIONS:
		var middle := lo+(hi-lo)*0.5
		if middle == lo or middle == hi or hi-lo <= ROOT_REL_EPS*maxf(absf(lo),absf(hi)):
			return {"ok":true, "root":middle}
		var fm := _value(coefficients, middle)
		if fm == 0.0: return {"ok":true, "root":middle}
		if (fm < 0.0) == (flo < 0.0):
			lo = middle
			flo = fm
		else: hi = middle
	return {"ok":false}

static func _append_distinct(roots: PackedFloat64Array, root: float) -> void:
	if roots.is_empty() or absf(root-roots[-1]) > ROOT_REL_EPS*maxf(absf(root), absf(roots[-1])):
		roots.append(root)

static func _failure(reason: String) -> Dictionary:
	return {"ok":false, "reason":reason, "direction":Vector3.ZERO, "time_s":0.0}
