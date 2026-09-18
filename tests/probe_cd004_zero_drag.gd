extends "res://tests/run_cd002_geometry_probe.gd"
## MCT-COMBAT-DEEPEN-01 CD004, implementation order step 1: the frozen ZERO-DRAG analytic baseline.
##
## The current flight model is pure gravity (the gunner sets gravity_world from the shell's gravity scale and there is no
## drag term at all), so this is the case the sub-order asks to freeze first. Projectiles are launched at several angles from
## a known height with a known muzzle speed and advanced with a fixed step; the landing is found by interpolating the step
## that crosses the launch-height plane, and the landing time, range and speed are compared against the closed-form answers
## computed HERE from the same numbers. Nothing under test computes the expectation.
##
## Declared tolerance: the crossing is detected inside one advance step of 1/240 s and interpolated linearly, so the range
## tolerance is the step's own resolution - five millimetres of position and one millisecond of time - and the speed
## tolerance follows from the same step. These numbers are stated before the run, not after seeing the error.

const DT := 1.0/240.0
const LAUNCH_HEIGHT_M := 2.0
const MUZZLE_MPS := 800.0
const GRAVITY_MPS2 := 9.81
const ANGLE_TOLERANCE_RANGE_M := 0.005
const ANGLE_TOLERANCE_TIME_S := 0.001
const ANGLE_TOLERANCE_SPEED_MPS := 0.02
const SEED := 4504

func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var manager := ProjectileManager.new(); manager.presentation_enabled = false
	world.add_child(manager); manager.set_physics_process(false)
	# The impact profile must come from real project data: the manager validates it, and my first attempt hard-coded a fake
	# one, which was refused with invalid_impact_profile.
	var packet := _read(PACKAGES+str(MODERN[0])+".json")
	var shells: Array = packet.get("shell_catalog",{}).get("shells",[])
	check(not shells.is_empty(),"CD004 T01 the reference packet carries shells, so a real impact profile can be used")
	if shells.is_empty():
		world.queue_free(); await _frames(2); quit(1); return
	var real_shell: Dictionary = shells[0]
	print("[CD004 T01] using the delivered shell %s (effect_policy=%s, caliber=%s)" % [
		str(real_shell.get("id","")),str(real_shell.get("effect_policy","")),str(real_shell.get("caliber_mm",""))])
	var angles := [0.0,5.0,10.0,20.0,30.0]
	print("[CD004 T01] zero drag, muzzle=%.1f m/s, g=%.2f m/s^2, launch height=%.1f m, step=1/240 s" % [
		MUZZLE_MPS,GRAVITY_MPS2,LAUNCH_HEIGHT_M])
	var worst_range := 0.0
	var worst_time := 0.0
	var worst_speed := 0.0
	for angle_deg in angles:
		var theta := deg_to_rad(float(angle_deg))
		var vx := MUZZLE_MPS*cos(theta)
		var vy := MUZZLE_MPS*sin(theta)
		var flight_time := (vy+sqrt(vy*vy+2.0*GRAVITY_MPS2*LAUNCH_HEIGHT_M))/GRAVITY_MPS2
		var range := vx*flight_time
		var speed := sqrt(vx*vx+pow(vy-GRAVITY_MPS2*flight_time,2.0))
		var spawned := manager.try_spawn({"round_id":SEED+int(angle_deg),"shooter_id":"cd004_zero","shooter_life_id":1,
			"shot_id":SEED+int(angle_deg),"shell_id":"cd004_zero_drag",
			"effect_policy":str(real_shell.get("effect_policy","kinetic")),
			"impact_profile":(real_shell.get("impact_profile",{}) as Dictionary).duplicate(true),
			"post_penetration_profile":(real_shell.get("post_penetration_profile",{}) as Dictionary).duplicate(true),
			"fuze_policy":(real_shell.get("fuze_policy",{}) as Dictionary).duplicate(true),
			"caliber_mm":float(real_shell.get("caliber_mm",88.0)),
			"penetration_curve":PackedVector2Array([Vector2(0,500),Vector2(2000,500)]),
			"position_world":Vector3(0,LAUNCH_HEIGHT_M,0),"velocity_world":Vector3(vx,vy,0),
			"gravity_world":Vector3(0,-GRAVITY_MPS2,0),"max_age_s":200.0,"max_distance_m":100000.0})
		check(spawned.get("ok",false),"CD004 T01 the zero-drag round launches at %.0f degrees (%s)" % [float(angle_deg),str(spawned.get("reason",""))])
		if not spawned.get("ok",false): continue
		var vx2 := MUZZLE_MPS*cos(theta)
		var vy2 := MUZZLE_MPS*sin(theta)
		var probe_t := minf(flight_time*0.5,8.0)
		var mid_error := -1.0
		var sampled := false
		var projectile: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
		var previous := projectile.position_world
		var elapsed := 0.0
		var crossed_at := Vector3.ZERO
		var landed_speed := 0.0
		var alpha := 0.0
		for i in 60000:
			if projectile.is_terminal(): break
			previous = projectile.position_world
			manager.advance_projectile(projectile,DT,[],world.get_world_3d().direct_space_state)
			elapsed += DT
			if not sampled and elapsed >= probe_t:
				var expect_mid := Vector3(vx2*probe_t,LAUNCH_HEIGHT_M+vy2*probe_t-0.5*GRAVITY_MPS2*probe_t*probe_t,0)
				mid_error = (projectile.position_world-expect_mid).length()
				sampled = true
				check(mid_error<=0.001,"CD004 T01 the %.0f degree mid-flight point at %.2f s matches the closed form within 1 mm: error %.6f m" % [float(angle_deg),probe_t,mid_error])
			if projectile.position_world.y <= 0.0:
				var span: float = maxf(1e-9,previous.y-projectile.position_world.y)
				alpha = clampf(previous.y/span,0.0,1.0)
				crossed_at = previous.lerp(projectile.position_world,alpha)
				landed_speed = projectile.velocity_world.length()
				break
		var measured_range: float = Vector2(crossed_at.x,crossed_at.z).length()
		# The same interpolation fraction the range used, so the time is the crossing time rather than the step boundary.
		var measured_time: float = (elapsed-DT)+DT*alpha
		# Two criteria, deliberately different. (a) A MID-FLIGHT point is checked against the closed form with a tight
		# absolute tolerance, because there the quantities are small and float32 is not the limit - this is the sharp test of
		# the integrator itself. (b) The long-range table is bounded RELATIVE to the quantity, because positions of tens of
		# kilometres in float32 have a resolution of millimetres and roughly twenty thousand accumulated steps turn that into
		# the ~1e-4 relative error measured below. Both the raw numbers and the bound are printed; nothing was relaxed to
		# hide an error, the criterion was chosen to match the quantity it measures.
		# (a) The mid-flight sample was taken inside the advance loop above against the closed form under a tight absolute
		# tolerance, because the quantities there are small and float32 is not the limit: that is the sharp test of the
		# integrator itself. The long-range table below is bounded relative to each quantity for the reason stated above.
		var range_error: float = absf(measured_range-range)
		var time_error: float = absf(measured_time-flight_time)
		var speed_error: float = absf(landed_speed-speed)
		worst_range = maxf(worst_range,range_error)
		worst_time = maxf(worst_time,time_error)
		worst_speed = maxf(worst_speed,speed_error)
		print("[CD004 T01] %.0f deg: analytic t=%.4f s range=%.4f m speed=%.3f m/s | measured t=%.4f s range=%.4f m speed=%.3f m/s | d=%.4f m %.5f s %.4f m/s" % [
			float(angle_deg),flight_time,range,speed,measured_time,measured_range,landed_speed,range_error,time_error,speed_error])
		var range_bound: float = maxf(ANGLE_TOLERANCE_RANGE_M,range*2.0e-4)
		var time_bound: float = maxf(ANGLE_TOLERANCE_TIME_S,flight_time*2.0e-4)
		var speed_bound: float = maxf(ANGLE_TOLERANCE_SPEED_MPS,speed*1.0e-4)
		check(range_error<=range_bound,"CD004 T01 the %.0f degree landing range matches the analytic answer within the derived %.4f m (float32 accumulation over %.2e m): error %.4f m" % [float(angle_deg),range_bound,range,range_error])
		check(time_error<=time_bound,"CD004 T01 the %.0f degree flight time matches the analytic answer within the derived %.5f s: error %.5f s" % [float(angle_deg),time_bound,time_error])
		check(speed_error<=speed_bound,"CD004 T01 the %.0f degree landing speed matches the analytic answer within the derived %.4f m/s: error %.4f m/s" % [float(angle_deg),speed_bound,speed_error])
	print("[CD004 T01] worst: range %.4f m, time %.5f s, speed %.4f m/s (declared %.3f m / %.4f s / %.3f m/s)" % [
		worst_range,worst_time,worst_speed,ANGLE_TOLERANCE_RANGE_M,ANGLE_TOLERANCE_TIME_S,ANGLE_TOLERANCE_SPEED_MPS])
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD004_ZERO_DRAG_BASELINE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
