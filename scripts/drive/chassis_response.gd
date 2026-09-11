class_name ChassisResponse
extends RefCounted
## Bounded critically damped longitudinal weight-transfer approximation.
## Design response, not a per-wheel spring or historical suspension simulation.
var pitch := 0.0
var pitch_rate := 0.0

func reset() -> void:
	pitch=0.0
	pitch_rate=0.0

func step(acceleration: float, delta: float, profile: DriveProfile) -> float:
	if delta<=0 or not is_finite(delta) or not is_finite(acceleration): return pitch
	var target := deg_to_rad(clampf(acceleration*profile.pitch_degrees_per_acceleration,-profile.pitch_limit_degrees,profile.pitch_limit_degrees))
	var omega := profile.pitch_response_rate
	# Exact solution for a constant target over this physics step.
	var offset := pitch-target
	var coefficient := pitch_rate+omega*offset
	var decay := exp(-omega*delta)
	pitch=target+(offset+coefficient*delta)*decay
	pitch_rate=(pitch_rate-omega*coefficient*delta)*decay
	return pitch
