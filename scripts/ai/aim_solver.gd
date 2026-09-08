class_name AimSolver
extends RefCounted
## Uses observable exterior motion and the shooter's own ballistic parameters.
static func solve(muzzle: Vector3, observation: Dictionary, shell: ShellDefinition, own_velocity: Vector3, angular_error: Vector2) -> Vector3:
	var point: Vector3 = observation.aim_point
	var travel := muzzle.distance_to(point)/maxf(shell.muzzle_velocity_mps,1)
	travel = minf(travel,2)
	point += (observation.velocity-own_velocity)*travel
	point.y += 0.5*9.81*shell.gravity_scale*travel*travel
	var offset := point-muzzle
	offset = offset.rotated(Vector3.UP,angular_error.x)
	var side := offset.normalized().cross(Vector3.UP).normalized()
	return muzzle+offset.rotated(side,angular_error.y)
