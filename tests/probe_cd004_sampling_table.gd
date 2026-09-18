extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD04 implementation order step three: sample the weapon's effective range and write the table down.
##
## Part A repeats the retention measurement under zero gravity, where the drag term has the closed form v(x)=v0*e^(-k*x),
## and holds it against the FROZEN declared curve with its own tolerance - so the table and the declaration are on one page.
## Part B is the practical table: the same two profiles flown WITH the shell's own gravity, giving the time, the drop from
## the straight line and the speed at each sampled range.
##
## The ranges are the four the sub-order names. Whether they lie inside the weapon's EFFECTIVE range is checked rather than
## assumed, because the order says anything beyond it carries no performance promise.

const T05T_SEED := 10100
const T05T_STEP := 1.0/240.0
const T05T_SPEED := 1500.0
const T05T_RANGES := [200.0,500.0,1000.0,1500.0]
const T05T_ZERO_G_TOLERANCE := 0.010

func _t05t_fly(actor: VehicleActor, world: Node3D, drag_k: float, gravity: Vector3, round_id: int, capture: bool) -> Dictionary:
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var spec := {"round_id":round_id,"shooter_id":"cd004_t05t","shooter_life_id":1,"shot_id":round_id,"shell_id":shell.id+"_t05t",
		"effect_policy":"kinetic","armor_policy":"resolve","impact_profile":{},"post_penetration_profile":{},"fuze_policy":{},
		"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,"drag_k_per_m":drag_k,
		"position_world":Vector3.ZERO,"velocity_world":Vector3(0,0,-T05T_SPEED),"gravity_world":gravity,
		"max_age_s":20.0,"max_distance_m":4000.0}
	var spawned := manager.try_spawn(spec)
	if not spawned.get("ok",false):
		manager.queue_free()
		return {"ok":false,"reason":str(spawned.get("reason",""))}
	var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var space := world.get_world_3d().direct_space_state
	var rows := {}
	var previous := state.position_world
	var previous_velocity := state.velocity_world
	var elapsed := 0.0
	for i in 4000:
		if state.is_terminal(): break
		previous = state.position_world
		previous_velocity = state.velocity_world
		manager.advance_projectile(state,T05T_STEP,[],space)
		elapsed += T05T_STEP
		var travelled: float = absf(state.position_world.z-previous.z)
		for range_m in T05T_RANGES:
			if rows.has(range_m): continue
			var covered: float = absf(previous.z)-range_m
			if absf(state.position_world.z) >= range_m:
				var span: float = maxf(1e-9,absf(state.position_world.z)-absf(previous.z))
				var alpha: float = clampf((range_m-absf(previous.z))/span,0.0,1.0)
				var point := previous.lerp(state.position_world,alpha)
				var speed: float = previous_velocity.lerp(state.velocity_world,alpha).length()
				rows[range_m] = {"time_s":elapsed-T05T_STEP*(1.0-alpha),"speed":speed,"y":point.y,"drop":point.y}
		if rows.size()==T05T_RANGES.size(): break
	var result := {"ok":true,"rows":rows,"age_s":state.age_s}
	manager.queue_free()
	return result

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd004_t05t_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD004 T05t creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd004_t05t_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD004 T05t the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd004_t05t",1,Transform3D.IDENTITY,2,null).ok,"CD004 T05t the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var drag := BallisticsProfile.resolve({"ballistics_profile":{"profile":BallisticsProfile.PROFILE_QUADRATIC}})
	var drag_k := float(drag.get("drag_k_per_m",0.0))
	var curve := BallisticsProfile.retention_curve(BallisticsProfile.PROFILE_QUADRATIC)
	var tolerance := float(curve.get("tolerance",T05T_ZERO_G_TOLERANCE))

	# ── Part A: retention under zero gravity against the frozen declared curve.
	var zero_vacuum := _t05t_fly(actor,world,0.0,Vector3.ZERO,T05T_SEED+1,true)
	var zero_drag := _t05t_fly(actor,world,drag_k,Vector3.ZERO,T05T_SEED+2,true)
	check(bool(zero_vacuum.get("ok",false)) and bool(zero_drag.get("ok",false)),"CD004 T05t both zero-gravity samples fly")
	print("[CD004 T05t A] zero gravity, muzzle %.1f m/s, k=%.8f, tolerance %.3f" % [T05T_SPEED,drag_k,tolerance])
	for row in curve.get("declared_retention",[]):
		var range_m := float(row[0])
		var declared := float(row[1])
		var analytic: float = exp(-drag_k*range_m)
		var drag_row: Dictionary = zero_drag.get("rows",{}).get(range_m,{})
		var vacuum_row: Dictionary = zero_vacuum.get("rows",{}).get(range_m,{})
		if drag_row.is_empty() or vacuum_row.is_empty():
			check(false,"CD004 T05t A the %d m sample exists" % int(range_m)); continue
		var retention: float = float(drag_row.speed)/float(vacuum_row.speed)
		print("[CD004 T05t A] %4d m: declared %.3f | analytic %.3f | measured %.3f | d_table %+.4f" % [
			int(range_m),declared,analytic,retention,retention-declared])
		check(absf(retention-declared)<=tolerance,
			"CD004 T05t A the %d m retention holds against the frozen declared curve within %.3f: measured %.4f declared %.4f" % [int(range_m),tolerance,retention,declared])

	# ── Part B: the practical table with the shell's own gravity.
	var gravity := Vector3(0,-9.81,0)*shell.gravity_scale
	var g_vacuum := _t05t_fly(actor,world,0.0,gravity,T05T_SEED+3,true)
	var g_drag := _t05t_fly(actor,world,drag_k,gravity,T05T_SEED+4,true)
	check(bool(g_vacuum.get("ok",false)) and bool(g_drag.get("ok",false)),"CD004 T05t both gravity samples fly")
	print("[CD004 T05t B] with gravity %.3f m/s^2 - range | vacuum t / drop / speed | drag t / drop / speed" % gravity.y)
	for range_m in T05T_RANGES:
		var vrow: Dictionary = g_vacuum.get("rows",{}).get(range_m,{})
		var drow: Dictionary = g_drag.get("rows",{}).get(range_m,{})
		if vrow.is_empty() or drow.is_empty():
			check(false,"CD004 T05t B the %d m sample exists with gravity" % int(range_m)); continue
		print("[CD004 T05t B] %4d m | %.4f s / %+.4f m / %.3f m/s | %.4f s / %+.4f m / %.3f m/s" % [
			int(range_m),float(vrow.time_s),float(vrow.drop),float(vrow.speed),float(drow.time_s),float(drow.drop),float(drow.speed)])
		check(float(drow.time_s)>float(vrow.time_s),"CD004 T05t B the drag sample takes longer to reach %d m: %.4f s > %.4f s" % [int(range_m),float(drow.time_s),float(vrow.time_s)])
		check(float(drow.speed)<float(vrow.speed),"CD004 T05t B the drag sample is slower at %d m: %.3f < %.3f m/s" % [int(range_m),float(drow.speed),float(vrow.speed)])
		check(float(drow.drop)<float(vrow.drop),"CD004 T05t B the drag sample has dropped further by %d m: %.4f < %.4f" % [int(range_m),float(drow.drop),float(vrow.drop)])

	# ── The effective-range check the order asks for, rather than an assumption.
	var effective := float(GameConfig.GUN_RANGE)
	var within := true
	for range_m in T05T_RANGES:
		if float(range_m) > effective: within = false
	print("[CD004 T05t] effective range %.1f m ; all sampled ranges inside it: %s ; beyond it there is NO performance promise" % [effective,str(within)])
	check(effective>0.0,"CD004 T05t an effective range is declared so the sampled ranges can be judged against it")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD004_SAMPLING_TABLE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
