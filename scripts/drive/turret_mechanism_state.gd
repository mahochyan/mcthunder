class_name TurretMechanismState
extends RefCounted
## Fixed-step pitch/yaw actuator. Point-following is a finite-bandwidth gunner
## approximation; only configured stabilizer axes receive hull feed-forward.
var velocity := Vector2.ZERO # pitch/yaw radians per second, relative to hull.
var stabilized_axes := Vector2i.ZERO # pitch/yaw; actual enabled compensation.
var stabilizer_active := false
var stabilizer_reason := "none"
var compensation_rate := Vector2.ZERO
var _previous_hull := Basis.IDENTITY
var _pose_valid := false
var _speed_limited := false
var _last_output := Vector2.ZERO

func reset() -> void:
	velocity=Vector2.ZERO; stabilized_axes=Vector2i.ZERO
	stabilizer_active=false; stabilizer_reason="none"; compensation_rate=Vector2.ZERO
	_previous_hull=Basis.IDENTITY; _pose_valid=false; _speed_limited=false; _last_output=Vector2.ZERO

static func rigid_basis(value: Basis) -> bool:
	return value.is_finite() and absf(value.determinant()-1.0)<0.0001 and value.transposed().is_equal_approx(value.inverse())

func hold(current: Vector2, hull_basis: Basis) -> Vector2:
	velocity=Vector2.ZERO; compensation_rate=Vector2.ZERO; stabilized_axes=Vector2i.ZERO
	stabilizer_active=false; stabilizer_reason="observation_hold"
	_pose_valid=rigid_basis(hull_basis)
	if _pose_valid: _previous_hull=hull_basis
	_last_output=current if current.is_finite() else Vector2.ZERO
	return _last_output

func constrain(actual: Vector2) -> void:
	# Call after the owning rig clamps its physical yaw/pitch stops. Blocked axes
	# cannot bank motor speed and kick when the target later leaves that stop.
	if not actual.is_finite(): return
	if absf(actual.x-_last_output.x)>0.0000001: velocity.x=0
	if absf(wrapf(actual.y-_last_output.y,-PI,PI))>0.0000001: velocity.y=0
	_last_output=actual

static func direction(angles: Vector2) -> Vector3:
	return Vector3(-sin(angles.y)*cos(angles.x),sin(angles.x),-cos(angles.y)*cos(angles.x))

static func angles_for(vector: Vector3) -> Vector2:
	return Vector2(atan2(vector.y,Vector2(vector.x,vector.z).length()),atan2(-vector.x,-vector.z))

static func axis_scale(caps: Dictionary, key: String) -> float:
	var value: Variant=caps.get(key,caps.get("turret_speed",1.0))
	if not (value is int or value is float) or not is_finite(float(value)): return 0
	return clampf(float(value),0,1)

func _configure_stabilizer(profile: FireControlProfile, speed: float, scales: Vector2, caps: Dictionary) -> void:
	stabilized_axes=Vector2i.ZERO; stabilizer_active=false
	if speed>profile.speed_limit_mps: _speed_limited=true
	elif speed<=profile.speed_limit_mps-profile.speed_hysteresis_mps: _speed_limited=false
	if profile.stabilizer_mode=="none": stabilizer_reason="none"; return
	if not caps.get("stabilizer_available",true): stabilizer_reason="unavailable"; return
	if _speed_limited: stabilizer_reason="speed_limited"; return
	if scales.x>0: stabilized_axes.x=1
	if profile.stabilizer_mode=="two_axis" and scales.y>0: stabilized_axes.y=1
	stabilizer_active=stabilized_axes!=Vector2i.ZERO
	stabilizer_reason="active" if stabilizer_active else "axis_disabled"
	if profile.stabilizer_mode=="two_axis" and stabilizer_active and stabilized_axes!=Vector2i.ONE:
		stabilizer_reason="degraded_axis"

func step(current: Vector2, target: Vector2, hull_basis: Basis, profile: FireControlProfile, max_speeds: Vector2, speed_mps: float, caps: Dictionary, delta: float) -> Vector2:
	if not current.is_finite() or not target.is_finite() or not max_speeds.is_finite() or max_speeds.x<0 or max_speeds.y<0 or not is_finite(speed_mps) or not rigid_basis(hull_basis) or profile==null:
		reset(); stabilizer_reason="invalid_input"
		return current if current.is_finite() else Vector2.ZERO
	if not is_finite(delta) or delta<=0: return current
	if not profile.validate().is_empty():
		reset(); stabilizer_reason="invalid_profile"; return current
	if caps.get("observation_hold",false): return hold(current,hull_basis)
	var scales := Vector2(axis_scale(caps,"pitch_scale"),axis_scale(caps,"yaw_scale"))
	_configure_stabilizer(profile,absf(speed_mps),scales,caps)
	compensation_rate=Vector2.ZERO
	if _pose_valid and stabilizer_active and hull_basis!=_previous_hull:
		# Reproject the old world gun direction into the new hull frame. This
		# includes roll/pitch coupling at arbitrary turret yaw, unlike Euler deltas.
		# An unchanged basis has exactly zero disturbance; skip the trigonometric
		# round-trip so leaving observation cannot inject floating-point drift.
		var compensated := angles_for(hull_basis.inverse()*(_previous_hull*direction(current)))
		if stabilized_axes.x!=0: compensation_rate.x=(compensated.x-current.x)/delta
		if stabilized_axes.y!=0: compensation_rate.y=wrapf(compensated.y-current.y,-PI,PI)/delta
	_previous_hull=hull_basis; _pose_valid=true
	var yaw_error := target.y-current.y if caps.get("yaw_limited",false) else wrapf(target.y-current.y,-PI,PI)
	var errors := Vector2(target.x-current.x,yaw_error)
	var accel := profile.acceleration()*scales
	var brake := profile.braking()*scales
	var result := current
	for axis in 2:
		var max_speed := max_speeds[axis]*scales[axis]
		if max_speed<=0 or accel[axis]<=0 or brake[axis]<=0:
			velocity[axis]=0; continue
		var error := errors[axis]
		var stopping_speed := sqrt(2.0*brake[axis]*absf(error)+pow(brake[axis]*delta,2))-brake[axis]*delta
		var following := signf(error)*minf(absf(error)/profile.response_time_s,stopping_speed)
		var wanted := clampf(following+compensation_rate[axis],-max_speed,max_speed)
		var before := velocity[axis]
		if before*wanted<0:
			# Brake to rest before acquiring opposite velocity; never reverse an
			# already moving mechanism by replacing its sign in one sample.
			velocity[axis]=move_toward(before,0,brake[axis]*delta)
		else:
			var rate := accel[axis] if absf(wanted)>absf(before) else brake[axis]
			velocity[axis]=move_toward(before,wanted,rate*delta)
		velocity[axis]=clampf(velocity[axis],-max_speed,max_speed)
		var movement := (before+velocity[axis])*0.5*delta
		if compensation_rate[axis]==0 and error*movement>=0 and absf(movement)>=absf(error) and absf(before)<=brake[axis]*delta:
			movement=error; velocity[axis]=0
		result[axis]+=movement
	if not caps.get("yaw_limited",false): result.y=wrapf(result.y,-PI,PI)
	_last_output=result
	return result
