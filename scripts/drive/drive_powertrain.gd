class_name DrivePowertrain
extends RefCounted
## Fixed-step longitudinal simulation shared by local, AI and authority actors.
var gear := 0 # Equivalent power bands; negative is reverse, not historical gear ratios.
var shift_left := 0.0
var rpm_fraction := 0.0
var traction_acceleration := 0.0
var braking := false
func reset() -> void:
	gear=0; shift_left=0; rpm_fraction=0; traction_acceleration=0; braking=false
func step(speed: float, throttle: float, grade: float, grounded: bool, delta: float, definition: VehicleDefinition) -> float:
	var p: DriveProfile=definition.drive_profile
	var limit := definition.forward_max_speed if throttle>=0 else definition.reverse_max_speed
	var fraction := clampf(absf(speed)/maxf(limit,0.001),0,1)
	traction_acceleration=0
	braking=throttle!=0 and speed*throttle<0
	shift_left=maxf(0,shift_left-delta)
	if braking:
		# Brake to zero first; the reverse engine cannot borrow the stronger brake rate.
		gear=0; shift_left=0; rpm_fraction=0
		return move_toward(speed,0,definition.brake_decel*delta)
	if throttle==0:
		if absf(speed)<0.001: reset(); return 0
		# Automatic holding brake: releasing controls still stops and holds on a slope.
		var uphill_drag := maxf(0,grade*signf(speed))*p.grade_acceleration if grounded else 0.0
		return move_toward(speed,0,(definition.coast_decel+uphill_drag)*delta)
	if throttle<0:
		gear=-1
	else:
		if gear<1: gear=1
		if shift_left==0:
			if gear<p.gear_count and fraction>float(gear)/p.gear_count:
				gear+=1; shift_left=p.shift_seconds
			elif gear>1 and fraction<float(gear-1)/p.gear_count-p.downshift_hysteresis:
				gear-=1; shift_left=p.shift_seconds
	rpm_fraction=clampf(fraction*p.gear_count-float(maxi(gear,1)-1),0,1) if gear>0 else fraction
	var acceleration := definition.forward_accel if throttle>0 else definition.reverse_accel
	var power := acceleration*(1.0-p.power_falloff*fraction*fraction)
	if shift_left>0: power*=p.shift_power
	var load := grade*signf(throttle)*p.grade_acceleration if grounded else 0.0
	traction_acceleration=power*absf(throttle)-load
	var target := absf(throttle)*limit
	var magnitude := absf(speed)
	if magnitude>target: magnitude=move_toward(magnitude,target,definition.coast_decel*delta)
	else: magnitude=clampf(magnitude+traction_acceleration*delta,0,target)
	return magnitude*signf(throttle)
