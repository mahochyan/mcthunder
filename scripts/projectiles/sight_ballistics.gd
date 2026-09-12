class_name SightBallistics
extends RefCounted
## Stationary-muzzle, stationary-target solution for the production constant-
## gravity projectile. No drag, target lead or tank-velocity compensation.
## Weapon cumulative range, obstructions and mechanical limits belong to the
## caller; a mathematical solution does not authorize a shot.

const GRAVITY_MPS2 := 9.81 # Same projectile acceleration as Gunner.request_fire.
const ROOT_RELATIVE_EPS := 1.0e-12

## Returns the earliest positive flight time (the low arc for a nonvertical
## target), including a target exactly at the shell's flight-time limit.
## Only flight parameters are required; metadata validation stays with loading.
static func solve(muzzle: Vector3, target: Vector3, shell: ShellDefinition) -> Dictionary:
	if shell == null:
		return _failure("missing_shell")
	if not muzzle.is_finite() or not target.is_finite():
		return _failure("non_finite_position")
	var speed := shell.muzzle_velocity_mps
	var scale := shell.gravity_scale
	var limit := shell.max_flight_time_s
	if not is_finite(speed) or speed <= 0.0:
		return _failure("invalid_muzzle_speed")
	if not is_finite(scale) or scale < 0.0:
		return _failure("invalid_gravity")
	if not is_finite(limit) or limit <= 0.0:
		return _failure("invalid_flight_time")
	var offset := target - muzzle
	if not offset.is_finite():
		return _failure("numeric_overflow")
	# Scalar products use GDScript doubles instead of Vector3.length_squared(),
	# which can overflow in a standard-precision engine before the scalar does.
	var dx := float(offset.x)
	var dy := float(offset.y)
	var dz := float(offset.z)
	var range_squared := dx * dx + dy * dy + dz * dz
	if range_squared == 0.0:
		return _failure("coincident_target")
	var speed_squared := speed * speed
	var gravity := GRAVITY_MPS2 * scale
	if not is_finite(range_squared) or not is_finite(speed_squared) or speed_squared <= 0.0 or not is_finite(gravity):
		return _failure("numeric_overflow")
	if not (Vector3(0.0, -GRAVITY_MPS2, 0.0) * scale).is_finite():
		return _failure("numeric_overflow")
	var time_squared: float
	if gravity == 0.0:
		time_squared = range_squared / speed_squared
	else:
		# u=t^2: 0.25*g^2*u^2 - (speed^2-g*height)*u + |offset|^2 = 0.
		# Rationalizing the smaller root avoids cancellation at short range,
		# high speed and near-zero gravity, and needs no horizontal division.
		var b := speed_squared - gravity * dy
		var b_squared := b * b
		var gravity_term := gravity * gravity * range_squared
		if not is_finite(b_squared) or not is_finite(gravity_term):
			return _failure("numeric_overflow")
		if b <= 0.0:
			return _failure("unreachable")
		var discriminant := b_squared - gravity_term
		var tolerance := ROOT_RELATIVE_EPS * maxf(b_squared, gravity_term)
		if discriminant < -tolerance:
			return _failure("unreachable")
		var denominator := b + sqrt(maxf(0.0, discriminant))
		if not is_finite(denominator) or denominator <= 0.0:
			return _failure("numeric_overflow")
		time_squared = 2.0 * range_squared / denominator
	if not is_finite(time_squared) or time_squared <= 0.0:
		return _failure("numeric_overflow")
	var time := sqrt(time_squared)
	if time > limit:
		return _failure("flight_time_exceeded")
	# Divide in double precision before constructing a Vector3 so a large or
	# small intermediate launch velocity cannot silently ruin normalization.
	var direction := Vector3(dx / time / speed, (dy + 0.5 * gravity * time_squared) / time / speed, dz / time / speed)
	if not direction.is_finite() or direction.length_squared() <= 0.0:
		return _failure("numeric_overflow")
	direction = direction.normalized()
	var production_velocity := direction * speed
	if not production_velocity.is_finite() or production_velocity == Vector3.ZERO:
		return _failure("numeric_overflow")
	return {"ok": true, "reason": "solved", "direction": direction, "time_s": time}

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "direction": Vector3.ZERO, "time_s": 0.0}
