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
@export var landing_min_speed := 2.0
@export var landing_restitution := 0.12
@export var landing_max_rebound := 1.0
@export var suspension_enabled := false
## CD11: the recoil response is a per weapon and per vehicle value rather than one global kick. The defaults ARE the values
## the global constants already used, so a profile that declares nothing behaves exactly as before and the previous uniform
## behaviour is retained as the legacy strategy rather than deleted. The damping stays global, exactly as the code reads it.
@export var recoil_speed_mps: float = GameConfig.CHASSIS_RECOIL_SPEED_MPS
@export var recoil_max_mps: float = GameConfig.CHASSIS_RECOIL_MAX_MPS
@export var suspension_compression_m := 0.18
@export var suspension_extension_m := 0.30
@export var suspension_response_rate := 10.0
@export var suspension_impact_scale := 0.28
@export var suspension_angle_limit_degrees := 8.0
@export var suspension_point_speed_limit := 4.0
@export var suspension_contact_margin_m := 0.02
func validate() -> Array[String]:
	var errors: Array[String]=[]
	for key in ["suspension_compression_m","suspension_extension_m","suspension_response_rate","suspension_impact_scale","suspension_angle_limit_degrees","suspension_point_speed_limit","suspension_contact_margin_m"]:
		var value: float=get(key)
		var limits: Vector2={"suspension_compression_m":Vector2(0.02,0.3),"suspension_extension_m":Vector2(0.02,0.4),"suspension_response_rate":Vector2(2,30),"suspension_impact_scale":Vector2(0,0.5),"suspension_angle_limit_degrees":Vector2(1,12),"suspension_point_speed_limit":Vector2(0.5,8),"suspension_contact_margin_m":Vector2(0,0.05)}[key]
		if not is_finite(value) or value<limits.x or value>limits.y: errors.append("drive_profile."+key+": invalid suspension tuning")
	if not is_finite(landing_min_speed) or landing_min_speed<1 or landing_min_speed>10: errors.append("drive_profile.landing_min_speed: expected [1,10]")
	if not is_finite(landing_restitution) or landing_restitution<0 or landing_restitution>0.3: errors.append("drive_profile.landing_restitution: expected [0,0.3]")
	if not is_finite(landing_max_rebound) or landing_max_rebound<=0 or landing_max_rebound>2: errors.append("drive_profile.landing_max_rebound: expected (0,2]")
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
