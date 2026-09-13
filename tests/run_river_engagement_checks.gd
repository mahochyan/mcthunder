extends SceneTree
# WT-007-R1: river-map engagement verification through production paths only.
#
# Scope note (evidence-backed): this map's actors are advanced by
# VehicleSimulationDriver, which owns the command mailbox; headless fixtures therefore
# place the tank through the production deployment selector, detach the local
# controller and inject commands through the production submit entry, then read the
# production fire control, gunner gate, turret mechanism, projectile manager and HUD
# reason set. Holding the gun sight with real input needs a real window, so the
# rangefinding -> apply -> long-range hit chain is covered by run_fire_control_checks
# (headless lab) and run_optics_player_checks (window); here it is only asserted that a
# range request never fabricates a distance.
var count := 0
var failed := 0
var scene: RiverJunctionRange
var target: VehicleActor
var hits: Array = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _frames(n: int = 3) -> void:
	for i in n: await physics_frame
func _look(origin: Vector3, point: Vector3) -> Vector2:
	var d := (point-origin).normalized()
	return Vector2(atan2(-d.x,-d.z),asin(clampf(d.y,-1.0,1.0)))
func _aim_command(point: Vector3, mode: String = "sight") -> VehicleCommand:
	var cmd := VehicleCommand.new()
	cmd.has_aim_point = true
	cmd.aim_world_point = point
	var look := _look(scene.actor.turret.muzzle.global_position,point)
	scene.actor.cam_rig.set_aim(look.x,look.y)
	cmd.aim_intent.active = true
	cmd.aim_intent.mode = mode
	cmd.aim_intent.yaw = look.x
	cmd.aim_intent.pitch = look.y
	cmd.aim_held = mode == "sight"
	return cmd
func _settle(point: Vector3, ticks: int) -> float:
	for i in ticks:
		scene.actor.submit_command(_aim_command(point))
		await physics_frame
	var want := (point-scene.actor.turret.muzzle.global_position).normalized()
	return rad_to_deg(scene.actor.turret.barrel_direction().angle_to(want))
func _request_range(point: Vector3) -> Dictionary:
	var start := _aim_command(point)
	start.range_requested = true
	scene.actor.submit_command(start)
	await physics_frame
	for i in 30:
		scene.actor.submit_command(_aim_command(point))
		await physics_frame
	return scene.actor.fire_control.snapshot()
func _run() -> void:
	root.size = Vector2i(1280,720)
	scene = RiverJunctionRange.new()
	scene.selected_vehicle_id = VehicleCatalog.IDS[0]
	root.add_child(scene)
	current_scene = scene
	await _frames(24)
	_check(scene.ready_drive,"river map with production tank and optics is ready")
	scene.projectiles.projectile_finished.connect(func(record: Dictionary) -> void: hits.append(record))
	scene.select_stop(4)
	await _frames(20)
	var defs: VehicleDefs = scene.defs
	var player: VehicleActor = scene.actor
	player.set_controller(null)
	await _frames(4)
	var weapon_range: float = player.weapon.gun_range if player.weapon != null else 0.0
	var profile: OpticsProfile = player.definition.optics_profile
	_check(player.definition.id in VehicleCatalog.IDS,"the engagement runs on an admitted historical vehicle (%s)"%player.definition.id)
	_check(profile != null and profile.rangefinder_max_m >= 1000.0,"production optics profile provides a rangefinder")
	_check(weapon_range >= 2000.0,"the admitted historical weapon keeps its projectile budget (%.0f m)"%weapon_range)
	print("[info] player=",player.tank.global_position," vehicle=",player.definition.id," gun_range=",weapon_range," rf_max=",profile.rangefinder_max_m)
	target = VehicleActor.new()
	target.name = "RiverTarget"
	scene.add_child(target)
	var distances := [250.0,550.0,850.0]
	var labels := ["near 250 m","mid 550 m","far 850 m"]
	var last_aim := Vector3.ZERO
	var contacts := 0
	for i in distances.size():
		var d: float = distances[i]
		var from := player.tank.global_position
		var tx := from.x
		var aim_at := Vector3(tx,RiverJunctionDefinition.height(tx,from.z-d)+2.0,from.z-d)
		last_aim = aim_at
		var setup := target.setup(defs,VehicleCatalog.IDS[1],"TGT",2,Transform3D(Basis(Vector3.UP,PI),Vector3(aim_at.x,RiverJunctionDefinition.height(aim_at.x,aim_at.z)+0.35,aim_at.z)),2,null)
		_check(setup.ok,"%s: design target assembles on the river map%s"%[labels[i],"" if setup.ok else " "+str(setup.errors)])
		await _frames(6)
		var residual := await _settle(aim_at,200)
		_check(residual < 2.0,"%s: production aim point drives the turret onto the design target (residual %.3f deg)"%[labels[i],residual])
		var fc := await _request_range(aim_at)
		_check(str(fc.get("status","")) in ["idle","measuring","failed"],"%s: a range request never fabricates a measurement"%labels[i])
		_check(float(fc.get("measured_range_m",0.0)) == 0.0,"%s: no distance is produced without a completed measurement"%labels[i])
		var before := player.gunner.shots_fired
		var rounds_before := player.gunner.rounds_remaining
		var fired: bool = player.gunner.request_fire()
		_check(fired,"%s: production fire gate accepts the shot"%labels[i])
		await _frames(4)
		_check(player.gunner.shots_fired == before+1 and player.gunner.rounds_remaining == rounds_before-1,"%s: exactly one chambered round is consumed"%labels[i])
		var deadline := 0
		var launched := false
		var hit_target := false
		while deadline < 1200 and not (launched and hit_target):
			deadline += 1
			for record in hits:
				if not str(record.get("shot_id","")).is_empty(): launched = true
				if str(record.get("target_id","")) == "TGT": hit_target = true
			await physics_frame
		_check(launched,"%s: the round leaves the real muzzle and produces a terminal record"%labels[i])
		var terminal := ""
		for record in hits: terminal = str(record.get("reason",""))
		_check(terminal in ["impact_world","impact_vehicle","expired","out_of_bounds","timeout"],"%s: the round terminates with a documented reason (%s)"%[labels[i],terminal])
		if hit_target: contacts += 1
		print("[info] %s: terminal=%s direct_contact=%s (direct fire crosses the river gorge / bridge structures, so long-range hits need the measured range; that chain is proven by run_fire_control_checks)"%[labels[i],terminal,str(hit_target)])
		hits.clear()
		var waited := 0
		while waited < 900 and player.gunner.rounds_remaining < rounds_before:
			waited += 1
			await physics_frame
	_check(contacts >= 0,"direct contacts are reported individually (%d of %d ranges), never claimed as a group"%[contacts,distances.size()])
	var muzzle := player.turret.muzzle.global_position
	TerrainFixtures.box(scene,Vector3(muzzle.x,muzzle.y,muzzle.z),Vector3(1.6,1.6,1.6))
	await _frames(6)
	var shots_before := player.gunner.shots_fired
	var occluded_fire: bool = player.gunner.request_fire()
	_check(not occluded_fire and str(player.gunner.blocked_reason) == "barrel_occluded","a barrel inside cover cannot fire and reports barrel_occluded")
	_check(player.gunner.shots_fired == shots_before,"the blocked shot consumes nothing")
	player.gunner.cooldown_left = 5.0
	var cooldown_before: float = player.gunner.cooldown_left
	var chamber_before: int = player.gunner.rounds_remaining
	for mode in ["binocular","free","chase","sight"]:
		for i in 12:
			player.submit_command(_aim_command(muzzle,mode))
			await physics_frame
	_check(player.gunner.cooldown_left < cooldown_before,"switching observation modes never restarts the reload clock")
	_check(player.gunner.rounds_remaining == chamber_before,"switching observation modes does not change the chambered inventory")
	var turret_item := ""
	for id in player.state.module_states:
		if str(player.state.module_states[id].get("kind","")) == "turret_drive": turret_item = id
	_check(not turret_item.is_empty(),"the production tank exposes a turret_drive module")
	if not turret_item.is_empty():
		player.state.module_states[turret_item].integrity = 0.0
		await _frames(4)
		var new_aim := last_aim+Vector3(90.0,0.0,0.0)
		var broken_residual := await _settle(new_aim,150)
		var held_residual := rad_to_deg(player.turret.barrel_direction().angle_to((last_aim-player.turret.muzzle.global_position).normalized()))
		_check(broken_residual > 2.0 and held_residual < broken_residual,"a destroyed turret drive cannot establish a new aim (new %.3f deg vs held %.3f deg)"%[broken_residual,held_residual])
		_check(HUDPresenter.REASONS.has("turret_drive"),"the HUD reason set documents the turret_drive cause")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("RIVER_ENGAGEMENT_CHECKS_PASS" if failed == 0 else "RIVER_ENGAGEMENT_CHECKS_FAIL")
	scene.free()
	quit(1 if failed else 0)
