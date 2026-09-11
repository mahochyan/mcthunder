class_name DriveProfile
extends Resource
## Design tuning, not measured historical transmission specifications.
@export var power_falloff := 0.45
@export var shift_seconds := 0.18
@export var shift_power := 0.15
@export var gear_count := 4
@export var downshift_hysteresis := 0.08
@export var grade_acceleration := 9.81
func validate() -> Array[String]:
	var errors: Array[String]=[]
	for key in ["power_falloff","shift_power","downshift_hysteresis"]:
		var value: float=get(key)
		if not is_finite(value) or value<0 or value>=1: errors.append("drive_profile."+key+": expected [0,1)")
	if not is_finite(shift_seconds) or shift_seconds<0 or shift_seconds>2: errors.append("drive_profile.shift_seconds: expected [0,2]")
	if gear_count<1 or gear_count>8: errors.append("drive_profile.gear_count: expected 1..8")
	if not is_finite(grade_acceleration) or grade_acceleration<0: errors.append("drive_profile.grade_acceleration: expected finite nonnegative")
	return errors
