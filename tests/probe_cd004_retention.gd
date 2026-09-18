extends "res://tests/run_cd002_geometry_probe.gd"
## MCT-COMBAT-DEEPEN-01 CD004-T02 (first half): the engineering profile's SPEED RETENTION against its frozen declared curve.
##
## The declared curve is what the sub-order calls the frozen engineering curve, and it is a project design value rather than
## measured history. Zero gravity isolates the drag term, because the table declares drag retention and nothing else. Under
## zero gravity the model a = -k*|v|*v has the closed form v(x) = v0*e^(-k*x) - that is computed here, independently of the
## integrator, so the check is against two references at once: the frozen table and its own analytic solution.
##
## Control: with k = 0 the same rig must return retention exactly 1.0 at every range, which is the legacy vacuum curve.

const DT := 1.0/240.0
const MUZZLE_MPS := 1500.0
const RANGES_M := [200.0,500.0,1000.0,1500.0]
const CONTROL_TOLERANCE := 1.0e-6
const ANALYTIC_TOLERANCE := 0.005

func _retention_at(manager: ProjectileManager, world: Node3D, drag_k: float, ranges: Array, gravity: Vector3 = Vector3.ZERO) -> Dictionary:
	var spawned := manager.try_spawn({"round_id":4900+int(drag_k*1.0e7),"shooter_id":"cd004_t02","shooter_life_id":1,
		"shot_id":4900+int(drag_k*1.0e7),"shell_id":"cd004_retention",
		"effect_policy":str(_t02_shell.get("effect_policy","kinetic")),
		"impact_profile":(_t02_shell.get("impact_profile",{}) as Dictionary).duplicate(true),
		"post_penetration_profile":(_t02_shell.get("post_penetration_profile",{}) as Dictionary).duplicate(true),
		"fuze_policy":(_t02_shell.get("fuze_policy",{}) as Dictionary).duplicate(true),
		"caliber_mm":float(_t02_shell.get("caliber_mm",88.0)),
		"penetration_curve":PackedVector2Array([Vector2(0,500),Vector2(2000,500)]),
		"position_world":Vector3.ZERO,"velocity_world":Vector3(MUZZLE_MPS,0,0),
		"gravity_world":gravity,"drag_k_per_m":drag_k,"max_age_s":60.0,"max_distance_m":5000.0})
	if not spawned.get("ok",false):
		return {"ok":false,"reason":str(spawned.get("reason",""))}
	var projectile: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	# Copy or reference: the instance id of the held handle against a freshly fetched one, printed once so the question is
	# settled by identity rather than inference.
	var fresh := manager.get_projectile_state(spawned.projectile_id)
	print("[CD004 T02] handle identity: held=%d fresh=%d same=%s" % [
		projectile.get_instance_id(),fresh.get_instance_id(),str(projectile.get_instance_id()==fresh.get_instance_id())])
	# The frozen launch state must carry the requested coefficient; if it does not, the drag wiring is not reachable and the
	# retention table measures nothing. This is asserted, not printed, so the failure names itself.
	if absf(float(projectile.drag_k_per_m)-drag_k) > 1e-12 and drag_k > 0.0:
		print("[CD004 T02] STATE MISMATCH: requested k=%.8f but the projectile carries %.8f (gravity=%s velocity=%s)" % [
			drag_k,float(projectile.drag_k_per_m),str(projectile.gravity_world),str(projectile.velocity_world)])
	var out := {}
	var previous := projectile.position_world
	var previous_velocity := projectile.velocity_world
	for i in 20000:
		# Re-fetch the live state every step and read position, velocity and speed from THAT, so the measurement cannot be
		# reading a stale handle. With this in place the retention table reads the same object the manager advances.
		projectile = manager.get_projectile_state(spawned.projectile_id)
		if projectile == null or projectile.is_terminal(): break
		previous = projectile.position_world
		previous_velocity = projectile.velocity_world
		manager.advance_projectile(projectile,DT,[],world.get_world_3d().direct_space_state)
		for range_m in ranges:
			if not out.has(range_m) and projectile.position_world.x >= range_m:
				var span: float = maxf(1e-9,projectile.position_world.x-previous.x)
				var alpha: float = clampf((range_m-previous.x)/span,0.0,1.0)
				# The SPEED at that range, interpolated from the two velocities that bracket the crossing. My first version
				# stored the length of an interpolated POSITION, which is not a speed at all, and called manager.despawn,
				# which does not exist - that missing method aborted this function before it returned and made every later
				# check read as a launch failure that never happened.
				var speed: float = previous_velocity.lerp(projectile.velocity_world,alpha).length()
				out[range_m] = {"speed":speed,"x":range_m,"alpha":alpha}
		if out.size()==ranges.size(): break
	return {"ok":true,"retention":out}

var _t02_shell: Dictionary = {}

func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var manager := ProjectileManager.new(); manager.presentation_enabled = false
	world.add_child(manager); manager.set_physics_process(false)
	var packet := _read(PACKAGES+str(MODERN[0])+".json")
	var shells: Array = packet.get("shell_catalog",{}).get("shells",[])
	check(not shells.is_empty(),"CD004 T02 the reference packet carries shells, so a real profile can be used")
	if shells.is_empty():
		world.queue_free(); await _frames(2); quit(1); return
	_t02_shell = shells[0]

	var curve := BallisticsProfile.retention_curve(BallisticsProfile.PROFILE_QUADRATIC)
	var table: Array = curve.get("declared_retention",[])
	var tolerance := float(curve.get("tolerance",0.010))
	var drag := BallisticsProfile.resolve({"ballistics_profile":{"profile":BallisticsProfile.PROFILE_QUADRATIC}})
	var drag_k := float(drag.get("drag_k_per_m",0.0))
	print("[CD004 T02] profile=%s k=%.8f tolerance=%.3f ; muzzle=%.0f m/s, zero gravity, step=1/240 s" % [
		BallisticsProfile.PROFILE_QUADRATIC,drag_k,tolerance,MUZZLE_MPS])

	var control := _retention_at(manager,world,0.0,RANGES_M)
	check(bool(control.get("ok",false)),"CD004 T02 the control shot launches")
	var worst_control := 0.0
	for row in table:
		var range_m := float(row[0])
		var row_control: Dictionary = control.get("retention",{}).get(range_m,{})
		if row_control.is_empty(): continue
		worst_control = maxf(worst_control,absf(1.0-float(row_control.get("speed",0.0))/MUZZLE_MPS))
	check(worst_control<=CONTROL_TOLERANCE,"CD004 T02 CONTROL: with k=0 the same rig holds the muzzle speed at every range (worst deviation %.8f)" % worst_control)

	var measured := _retention_at(manager,world,drag_k,RANGES_M)
	print("[CD004 T02] measured map: %s" % JSON.stringify(measured.get("retention",{})))
	check(bool(measured.get("ok",false)),"CD004 T02 the engineering-drag shot launches")
	var worst_table := 0.0
	var worst_analytic := 0.0
	for row in table:
		var range_m := float(row[0])
		var declared := float(row[1])
		var analytic: float = exp(-drag_k*range_m)
		var row_measured: Dictionary = measured.get("retention",{}).get(range_m,{})
		if row_measured.is_empty():
			check(false,"CD004 T02 the %d m sample exists" % int(range_m)); continue
		var retention: float = float(row_measured.get("speed",0.0))/MUZZLE_MPS
		worst_table = maxf(worst_table,absf(retention-declared))
		worst_analytic = maxf(worst_analytic,absf(retention-analytic))
		print("[CD004 T02] %4d m: declared %.3f | analytic e^(-kx) %.3f | measured %.3f | d_table %+.4f d_analytic %+.4f" % [
			int(range_m),declared,analytic,retention,retention-declared,retention-analytic])
		check(absf(retention-declared)<=tolerance,"CD004 T02 the %d m retention matches the FROZEN declared curve within %.3f: measured %.4f declared %.4f" % [int(range_m),tolerance,retention,declared])
		check(absf(retention-analytic)<=ANALYTIC_TOLERANCE,"CD004 T02 the %d m retention matches the independent closed form e^(-k*x) within %.3f: measured %.4f analytic %.4f" % [int(range_m),ANALYTIC_TOLERANCE,retention,analytic])
	print("[CD004 T02] worst: table %.4f (tolerance %.3f) ; analytic %.4f (tolerance %.3f) ; control %.8f" % [
		worst_table,tolerance,worst_analytic,ANALYTIC_TOLERANCE,worst_control])
	check(not BallisticsProfile.is_validated_history(drag),
		"CD004 T02 the curve used here is a design value and is not labelled validated_history")
	world.queue_free(); await _frames(2)
	# Direct unit check of the new advance, with no manager involved: 1500 m/s under k=1.4e-4 must decay to e^(-k*x). If
	# this passes while the table does not, the arithmetic is right and the plumbing is what to look at; if it fails, the
	# arithmetic is what to look at. Either way the next step is decided by measurement rather than by reading.
	var direct_p := Vector3.ZERO
	var direct_v := Vector3(1500.0,0.0,0.0)
	while direct_p.x < 1500.0:
		var step := BallisticMath.advance_profile(direct_p,direct_v,Vector3.ZERO,1.4e-4,1.0/240.0)
		if not step.get("ok",false):
			print("[CD004 T02] direct advance refused: %s" % str(step.get("reason",""))); break
		direct_p = step.position
		direct_v = step.velocity
	var direct_retention: float = direct_v.length()/1500.0
	var direct_analytic: float = exp(-1.4e-4*direct_p.x)
	print("[CD004 T02] direct advance: after %.2f m speed=%.4f retention=%.5f analytic=%.5f" % [
		direct_p.x,direct_v.length(),direct_retention,direct_analytic])
	check(absf(direct_retention-direct_analytic)<=0.002,"CD004 T02 the drag advance itself decays the speed to the closed form: measured %.5f analytic %.5f" % [direct_retention,direct_analytic])

	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD004_RETENTION_TABLE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
