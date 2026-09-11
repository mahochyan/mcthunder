class_name DriveProfile
extends Resource
## Design tuning, not measured historical transmission specifications.
@export var power_falloff := 0.45
@export var shift_seconds := 0.18
@export var shift_power := 0.15
@export var gear_count := 4
@export var downshift_hysteresis := 0.08
@export var grade_acceleration := 9.81
@export var brake_scale := 1.0
@export var coast_scale := 1.0
@export var turn_speed_falloff := 0.35
@export var turn_drag_per_second := 0.35
@export var track_spacing_m := 2.5
@export var neutral_turn := true
@export var damaged_track_turn_scale := 0.25
@export var pitch_degrees_per_acceleration := 0.18
@export var pitch_limit_degrees := 1.5
@export var pitch_response_rate := 8.0
func validate() -> Array[String]:
	var errors: Array[String]=[]
	for key in ["pitch_degrees_per_acceleration","pitch_limit_degrees","pitch_response_rate"]:
		var value: float=get(key)
		var ceiling: float={"pitch_degrees_per_acceleration":1.0,"pitch_limit_degrees":3.0,"pitch_response_rate":30.0}[key]
		if not is_finite(value) or value<=0 or value>ceiling: errors.append("drive_profile."+key+": outside response tuning range")
	for key in ["brake_scale","coast_scale"]:
		var value: float=get(key)
		if not is_finite(value) or value<=0 or value>3: errors.append("drive_profile."+key+": expected (0,3]")
	for key in ["power_falloff","shift_power","downshift_hysteresis","turn_speed_falloff","damaged_track_turn_scale"]:
		var value: float=get(key)
		if not is_finite(value) or value<0 or value>=1: errors.append("drive_profile."+key+": expected [0,1)")
	if not is_finite(shift_seconds) or shift_seconds<0 or shift_seconds>2: errors.append("drive_profile.shift_seconds: expected [0,2]")
	if gear_count<1 or gear_count>8: errors.append("drive_profile.gear_count: expected 1..8")
	if not is_finite(grade_acceleration) or grade_acceleration<0: errors.append("drive_profile.grade_acceleration: expected finite nonnegative")
	if not is_finite(turn_drag_per_second) or turn_drag_per_second<0 or turn_drag_per_second>3: errors.append("drive_profile.turn_drag_per_second: expected [0,3]")
	if not is_finite(track_spacing_m) or track_spacing_m<=0 or track_spacing_m>10: errors.append("drive_profile.track_spacing_m: expected (0,10]")
	return errors
