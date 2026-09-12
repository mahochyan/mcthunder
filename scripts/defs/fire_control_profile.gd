class_name FireControlProfile
extends Resource
## Gameplay response model, not verified historical mechanism specifications.
@export var provenance := "game_rule"
@export var pitch_accel_deg_s2 := 40.0
@export var yaw_accel_deg_s2 := 80.0
@export var pitch_brake_deg_s2 := 60.0
@export var yaw_brake_deg_s2 := 120.0
@export var response_time_s := 0.25
@export_enum("none", "vertical", "two_axis") var stabilizer_mode := "none"
@export var speed_limit_mps := 5.0
@export var speed_hysteresis_mps := 0.5

func validate() -> Array[String]:
	var errors: Array[String]=[]
	if provenance not in ["game_rule","reference_candidate","documented"]:
		errors.append("fire_control_profile.provenance: unknown source category")
	for key in ["pitch_accel_deg_s2","yaw_accel_deg_s2","pitch_brake_deg_s2","yaw_brake_deg_s2"]:
		var value := float(get(key))
		if not is_finite(value) or value<=0 or value>100000:
			errors.append("fire_control_profile."+key+": expected finite positive acceleration")
	if not is_finite(response_time_s) or response_time_s<=0 or response_time_s>10:
		errors.append("fire_control_profile.response_time_s: expected (0,10] seconds")
	if stabilizer_mode not in ["none","vertical","two_axis"]:
		errors.append("fire_control_profile.stabilizer_mode: unknown capability")
	if not is_finite(speed_limit_mps) or speed_limit_mps<0 or speed_limit_mps>200:
		errors.append("fire_control_profile.speed_limit_mps: expected [0,200]")
	if not is_finite(speed_hysteresis_mps) or speed_hysteresis_mps<0 or speed_hysteresis_mps>speed_limit_mps:
		errors.append("fire_control_profile.speed_hysteresis_mps: expected [0,speed_limit]")
	return errors

func acceleration() -> Vector2:
	return Vector2(deg_to_rad(pitch_accel_deg_s2),deg_to_rad(yaw_accel_deg_s2))

func braking() -> Vector2:
	return Vector2(deg_to_rad(pitch_brake_deg_s2),deg_to_rad(yaw_brake_deg_s2))
