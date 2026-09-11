class_name TrackDrive
extends RefCounted
## Design-level differential kinematics, not independent contact/slip simulation.
var yaw_rate := 0.0
var left_speed := 0.0
var right_speed := 0.0

func reset() -> void:
	yaw_rate=0; left_speed=0; right_speed=0

func step(speed: float, steer: float, delta: float, definition: VehicleDefinition) -> float:
	var p := definition.drive_profile
	var limit := definition.forward_max_speed if speed>=0 else definition.reverse_max_speed
	var fraction := clampf(absf(speed)/maxf(limit,0.001),0,1)
	yaw_rate=deg_to_rad(definition.hull_turn_speed)*steer*(1-p.turn_speed_falloff*fraction)
	# Vehicles without neutral steering approach zero yaw continuously at rest.
	if not p.neutral_turn: yaw_rate*=minf(absf(speed),1.0)
	var result := speed*exp(-p.turn_drag_per_second*absf(steer)*fraction*delta)
	refresh(result,p.track_spacing_m)
	return result

func refresh(speed: float, spacing: float) -> void:
	# Positive Godot yaw turns toward -X: right track travels further than left.
	left_speed=speed-yaw_rate*spacing*0.5
	right_speed=speed+yaw_rate*spacing*0.5

func single_track_pivot(steer: float, left_available: bool, definition: VehicleDefinition) -> float:
	var p := definition.drive_profile
	yaw_rate=deg_to_rad(definition.hull_turn_speed)*p.damaged_track_turn_scale*steer
	# Broken side is the stationary support; the hull center follows a slow arc.
	var speed := yaw_rate*p.track_spacing_m*0.5*(-1.0 if left_available else 1.0)
	refresh(speed,p.track_spacing_m)
	return speed
