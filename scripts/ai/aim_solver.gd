class_name AimSolver
extends RefCounted
## Uses observable exterior motion and the shooter's own ballistic parameters.
const MAX_OBSERVATION_AGE_S := 0.6

static func solve(muzzle: Vector3, observation: Dictionary, shell: ShellDefinition, own_velocity: Vector3, angular_error: Vector2) -> Vector3:
	# Compatibility for scripted training consumers. Invalid aim remains invalid
	# and is rejected by the command contract instead of authorizing fallback fire.
	var result := solve_intercept(muzzle,observation,shell,own_velocity,angular_error)
	return result.aim_point if result.ok else Vector3.INF

static func solve_intercept(muzzle: Vector3, observation: Dictionary, shell: ShellDefinition, own_velocity: Vector3, angular_error: Vector2, age_s: float = 0.0) -> Dictionary:
	if not observation.get("aim_point") is Vector3 or not observation.get("velocity") is Vector3:
		return {"ok":false,"reason":"invalid_observation"}
	if not is_finite(age_s) or age_s<0.0 or age_s>MAX_OBSERVATION_AGE_S:
		return {"ok":false,"reason":"stale_observation"}
	if not angular_error.is_finite(): return {"ok":false,"reason":"invalid_skill_error"}
	var velocity: Vector3=observation.velocity
	var current_point: Vector3=observation.aim_point+velocity*age_s
	var result := BallisticIntercept.solve(muzzle,current_point,velocity,own_velocity,shell)
	if not result.ok: return result
	var ideal: Vector3=result.direction
	var direction := ideal.rotated(Vector3.UP,angular_error.x)
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared()<=0.0: side=Vector3.RIGHT
	direction=direction.rotated(side,angular_error.y).normalized()
	var aim_distance := maxf(100.0,muzzle.distance_to(current_point))
	result["ideal_direction"]=ideal
	result["direction"]=direction
	result["aim_point"]=muzzle+direction*aim_distance
	result["aim_distance_m"]=aim_distance
	result["target_point_now"]=current_point
	result["target_velocity"]=velocity
	result["observation_age_s"]=age_s
	result["shell_id"]=shell.id
	return result
