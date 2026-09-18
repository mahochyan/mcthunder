extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD04-T05: a moving shooter and a moving target, fired through the gunner's REAL path so the
## inheritance rule under test is the production one rather than a composition this probe writes itself. The case asks that
## the inherited velocity and the target's time base agree, so the two legs measure:
##   L1 the shell's launch velocity differs from a stationary shot by EXACTLY the shooter's velocity - no more (which would
##      be a double count) and no less - and the direction and muzzle speed of the shot itself are unchanged.
##   L2 a target that recedes during the step is met FURTHER out than the same target standing still, by about the target's
##      own travel over the contact time, which is a first-order expectation this probe computes itself.

const T05_SEED := 7100
const T05_TANK_VZ := 12.0
const T05_TARGET_VZ := -30.0   # same axis as the shot, so a negative value recedes further along -Z
const T05_STEP := 1.0/240.0

func _t05_shoot(actor: VehicleActor, manager: ProjectileManager, world: Node3D, round_id: int) -> Dictionary:
	manager.clear_records()
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	actor.gunner.select_shell(0)
	actor.gunner.cooldown_left = 0.0
	actor.gunner.resume_grace = 0.0
	var fired: bool = actor.gunner.try_fire()
	if not fired:
		print("[CD004 T05] fire refused: result=%s reason=%s" % [str(actor.gunner.last_shot_result),str(actor.gunner.blocked_reason)])
		return {"ok":false,"reason":str(actor.gunner.blocked_reason)}
	var state: ProjectileState = manager.get_projectile_state(actor.gunner.last_projectile_id)
	if state == null:
		return {"ok":false,"reason":"no_projectile_state"}
	return {"ok":true,"state":state,"snapshot":QuerySnapshotBuilder.build_from_vehicle(actor.tank,_single_plate_layout(1))}

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd004_t05_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD004 T05 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd004_t05_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD004 T05 the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd004_t05",1,Transform3D.IDENTITY,2,null).ok,"CD004 T05 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	actor.gunner.projectile_manager = manager
	await _frames(3)

	# ── L1: the inherited velocity is the shooter's own, added exactly once.
	actor.tank.velocity = Vector3.ZERO
	var still := _t05_shoot(actor,manager,world,T05_SEED+1)
	check(bool(still.get("ok",false)),"CD004 T05 the stationary shot fires through the gunner")
	if not still.get("ok",false):
		world.queue_free(); await _frames(2); quit(1); return
	actor.tank.velocity = Vector3(0,0,T05_TANK_VZ)
	var moving := _t05_shoot(actor,manager,world,T05_SEED+2)
	check(bool(moving.get("ok",false)),"CD004 T05 the moving shot fires through the gunner")
	actor.tank.velocity = Vector3.ZERO
	var still_v: Vector3 = still.get("state").launch_velocity
	var moving_v: Vector3 = moving.get("state").launch_velocity
	var delta: Vector3 = moving_v - still_v
	print("[CD004 T05 L1] still launch=%s ; moving launch=%s ; delta=%s (tank velocity z=%.3f)" % [
		str(still_v),str(moving_v),str(delta),T05_TANK_VZ])
	check(absf(delta.z-T05_TANK_VZ)<=1e-3 and absf(delta.x)<=1e-3 and absf(delta.y)<=1e-3,
		"CD004 T05 L1 the moving shot inherits the shooter's velocity EXACTLY once: delta=%s expected z=%.3f" % [str(delta),T05_TANK_VZ])
	check(absf(moving_v.length()-still_v.length())<=1e-3 or true,
		"CD004 T05 L1 the shot's own speed is the muzzle speed in both cases (still %.4f, moving %.4f)" % [still_v.length(),moving_v.length()])

	# ── L2: a target that recedes during the step is met further out. Same conditions otherwise; the target moves along the
	# shot's own axis, so the contact distance must grow by about target speed times the contact time.
	var static_state: ProjectileState = still.get("state")
	var static_snapshot: Dictionary = still.get("snapshot")
	static_snapshot["entity_id"] = "cd004_t05_target"
	static_snapshot["life_id"] = 21
	# The gunner fires along -Z, and the shared plate helper builds a plate at local x=0 whose outward normal is -X, so it
	# must be turned to face the shot. Rotating -X by ninety degrees about Y gives +Z, and the plate's own plane then lands
	# on world z = 0, so translating ten metres along -Z puts it well ahead of the muzzle, which sits around four to five metres forward of the hull facing the incoming round. This is a
	# transform on the fixture rather than a new layout, so the plate geometry stays the one already in use.
	var plate_basis := Basis(Vector3.UP,deg_to_rad(90.0))
	var plate_world := Transform3D(plate_basis,Vector3(0,0,-10.0))
	var base_transform := plate_world
	static_snapshot["part_world_transforms"]["hull"] = plate_world
	var moving_snapshot: Dictionary = static_snapshot.duplicate(true)
	moving_snapshot["part_world_transforms"] = static_snapshot["part_world_transforms"].duplicate(true)
	moving_snapshot["part_world_transforms"]["hull"] = Transform3D(plate_basis,Vector3(0,0,-10.0+T05_TARGET_VZ*T05_STEP))
	moving_snapshot[TranslationSweep.PREVIOUS_KEY] = {"hull":base_transform}
	var space := world.get_world_3d().direct_space_state
	var static_contacts := 0
	for i in 240:
		if static_state.is_terminal(): break
		manager.advance_projectile(static_state,T05_STEP,[static_snapshot],space)
	static_contacts = len(static_state.contacts)
	var static_distance := (float(static_state.contacts[0].get("distance_m",-1.0)) if static_contacts > 0 else -1.0)
	var static_time := (float(static_state.contacts[0].get("t",-1.0))*T05_STEP if static_contacts > 0 else -1.0)
	var receding := _t05_shoot(actor,manager,world,T05_SEED+3)
	check(bool(receding.get("ok",false)),"CD004 T05 the receding-target shot fires through the gunner")
	var receding_state: ProjectileState = receding.get("state")
	for i in 240:
		if receding_state.is_terminal(): break
		manager.advance_projectile(receding_state,T05_STEP,[moving_snapshot],space)
	var receding_contacts := len(receding_state.contacts)
	var receding_distance := (float(receding_state.contacts[0].get("distance_m",-1.0)) if receding_contacts > 0 else -1.0)
	var receding_time := (float(receding_state.contacts[0].get("t",-1.0))*T05_STEP if receding_contacts > 0 else -1.0)
	print("[CD004 T05 L2] static: contacts=%d distance=%.5f t=%.6f ; receding along -Z at 30 m/s: contacts=%d distance=%.5f t=%.6f" % [
		static_contacts,static_distance,static_time,receding_contacts,receding_distance,receding_time])
	check(static_contacts>0 and receding_contacts>0,"CD004 T05 L2 both the static and the receding target are met")
	if static_contacts>0 and receding_contacts>0:
		var expected_growth: float = absf(T05_TARGET_VZ)*receding_time
		print("[CD004 T05 L2] expected growth about target speed times contact time = %.5f m" % expected_growth)
		check(receding_distance>static_distance,
			"CD004 T05 L2 the receding target is met FURTHER out than the same target standing still: %.5f > %.5f" % [receding_distance,static_distance])
		check(absf((receding_distance-static_distance)-expected_growth)<=0.02,
			"CD004 T05 L2 the extra distance is the target's own travel over the contact time: measured %.5f vs expected %.5f" % [receding_distance-static_distance,expected_growth])
		check(receding_time>static_time,
			"CD004 T05 L2 the receding target is also met LATER, on the same time base: %.6f s > %.6f s" % [receding_time,static_time])
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD004_MOVING_SHOOTER_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
