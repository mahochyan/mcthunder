class_name LandingResponse
extends RefCounted
## Dissipative landing restitution for the current single-body collision model.
## This is not per-wheel suspension compression.
var pending_velocity := Vector3.ZERO
var last_impact_speed := 0.0
var impacts := 0

func reset() -> void:
	pending_velocity=Vector3.ZERO
	last_impact_speed=0.0
	impacts=0

func contact(incident: Vector3, normal: Vector3, profile: DriveProfile) -> void:
	if not incident.is_finite() or not normal.is_finite() or normal.length_squared()<0.01: return
	var up := normal.normalized()
	var speed := maxf(0,-incident.dot(up))
	if speed<profile.landing_min_speed: return
	last_impact_speed=speed
	impacts+=1
	pending_velocity=up*minf(speed*profile.landing_restitution,profile.landing_max_rebound)

func consume(velocity: Vector3) -> Vector3:
	if pending_velocity.is_zero_approx(): return velocity
	var up := pending_velocity.normalized()
	var result := velocity.slide(up)+pending_velocity
	pending_velocity=Vector3.ZERO
	return result
