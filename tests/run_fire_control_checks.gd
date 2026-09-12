extends SceneTree
## Production authority regression: commands -> optical query -> range setting
## -> finite mechanism -> Gunner -> ProjectileManager -> real wall contact.
## Fixture shell speeds and the raised firing platform are test data only.

var checks := 0
var failures := 0
var scene: BallisticsRange
var actor: VehicleActor
var wall: StaticBody3D
var records: Array[Dictionary] = []
var chamber_probe: ChamberAimProbe

class ChamberAimProbe extends Node:
	var actor: VehicleActor
	var previous_shell := ""
	var transitions := 0
	var maximum_error := 0.0
	func _physics_process(_delta: float) -> void:
		if not is_instance_valid(actor) or actor.gunner.shell == null: return
		var current_shell := actor.gunner.shell.id
		if current_shell != previous_shell and not previous_shell.is_empty() and actor.fire_control.zeroing_m > 0.0:
			transitions += 1
			var ray := actor.cam_rig.optical_ray()
			var target: Vector3 = ray.origin + ray.direction * actor.fire_control.zeroing_m
			var expected := SightBallistics.solve(actor.turret.muzzle.global_position, target, actor.gunner.shell)
			var demanded := (actor.turret._aim_point() - actor.turret.barrel_pivot.global_position).normalized()
			maximum_error = maxf(maximum_error, demanded.angle_to(expected.direction) if expected.get("ok", false) else INF)
		previous_shell = current_shell

func _initialize() -> void:
	create_timer(180.0).timeout.connect(func() -> void:
		print("[WATCHDOG] fire-control checks exceeded 180 seconds")
		quit(2))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + message)

func ticks(count: int) -> void:
	for _i in count:
		await physics_frame
	await process_frame

func command(mode: String = "sight", pitch: float = 0.0) -> VehicleCommand:
	var cmd := VehicleCommand.new()
	cmd.aim_intent.active = true
	cmd.aim_intent.mode = mode
	cmd.aim_intent.pitch = pitch
	cmd.aim_held = mode == "sight"
	cmd.clear_aim = true
	return cmd

func drive(cmd: VehicleCommand, count: int = 1) -> void:
	for _i in count:
		if not actor.submit_command(cmd):
			check(false, "fixture command accepted by real actor")
			return
		await physics_frame
		await process_frame

func measure(cmd: VehicleCommand) -> void:
	cmd.range_requested = true
	await drive(cmd)
	cmd.range_requested = false
	await drive(cmd, 130)

func optical_contact_point() -> Vector3:
	var hit := actor.cam_rig.measure_contact(2000.0)
	if not hit.get("ok", false):
		return Vector3.INF
	var ray := actor.cam_rig.optical_ray()
	return ray.origin + ray.direction * hit.distance_m

func shoot(cmd: VehicleCommand, label: String) -> Dictionary:
	var before := actor.gunner.shots_fired
	var start := records.size()
	cmd.fire_requested = true
	await drive(cmd)
	cmd.fire_requested = false
	check(actor.gunner.shots_fired == before + 1, label + ": actual command launches exactly one round")
	if actor.gunner.shots_fired != before + 1:
		return {}
	var projectile := actor.gunner.last_projectile_id
	for _i in 600:
		for index in range(start, records.size()):
			if int(records[index].projectile_id) == projectile:
				return records[index]
		await drive(cmd)
	check(false, label + ": real projectile reaches a terminal contact before watchdog")
	return {}

func run() -> void:
	InputBindingService.initialize()
	scene = BallisticsRange.new()
	scene.selected_vehicle_id = VehicleCatalog.IDS[0]
	root.add_child(scene)
	current_scene = scene
	await ticks(35)
	actor = scene.actor
	actor.set_controller(null)
	# Preserve the production scene, query service and firing pipeline; disable
	# the stock short lanes so they cannot intercept this 600m experiment.
	for node in scene._boards.values() + scene._walls.values():
		scene._enable_node(node, false)
	TerrainFixtures.box(scene, Vector3(0, 39.5, 0), Vector3(20, 1, 20))
	actor.position.y = 40.0
	wall = TerrainFixtures.box(scene, Vector3(0, 40, -600.5), Vector3(400, 200, 1))
	wall.name = "FireControlFarWall"
	scene.projectiles.projectile_finished.connect(func(record: Dictionary) -> void: records.append(record.duplicate(true)))
	# Isolated design fixtures retain the admitted shell's damage data. A short
	# ordinary reload keeps this suite focused on sighting instead of wall time.
	var weapon: WeaponDefinition = actor.weapon.duplicate(true)
	weapon.reload_time = 0.25
	actor.weapon = weapon
	actor.gunner.weapon = weapon
	actor.cam_rig.configure_weapon(weapon)
	var slow: ShellDefinition = actor.shell.duplicate(true)
	slow.id = "TEST_fire_control_300"
	slow.source_refs = ["TEST ONLY: stationary fire-control integration fixture"]
	slow.verification = "unknown"
	slow.allowed_vehicle_ids.clear()
	slow.muzzle_velocity_mps = 300.0
	slow.max_flight_time_s = 15.0
	var fast: ShellDefinition = slow.duplicate(true)
	fast.id = "TEST_fire_control_600"
	fast.muzzle_velocity_mps = 600.0
	var options: Array[ShellDefinition] = [slow, fast]
	check(actor.gunner.configure_shell_loadout(options, {slow.id: 8, fast.id: 8}, slow.id), "two-speed typed loadout is admitted through production Gunner")
	chamber_probe = ChamberAimProbe.new()
	chamber_probe.actor = actor
	chamber_probe.process_physics_priority = SimulationPhases.SNAPSHOT
	scene.add_child(chamber_probe)
	await ticks(50)
	check(actor.tank.velocity.length() < 0.01, "raised firing platform provides a stationary real launcher")
	await check_live_shots(slow, fast)
	await check_lifecycle()
	check_command_contract()
	scene.free()
	await process_frame
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks, failures])
	print("FIRE_CONTROL_CHECKS_PASS" if failures == 0 else "FIRE_CONTROL_CHECKS_FAIL")
	quit(0 if failures == 0 else 1)

func check_live_shots(slow: ShellDefinition, fast: ShellDefinition) -> void:
	var cmd := command()
	await drive(cmd, 65)
	var contact := optical_contact_point()
	check(contact.is_finite() and absf(contact.z + 600.0) < 0.02, "real optical query reaches the 600m wall, not a fallback or stock near lane")
	var direct := actor.turret.barrel_direction()
	cmd.range_requested = true
	await drive(cmd)
	cmd.range_requested = false
	check(actor.fire_control.status == "measuring" and actor.fire_control.measurement_left_s > 1.9, "range command starts the configured two-second authority measurement")
	await drive(cmd, 90)
	check(actor.fire_control.status == "measuring" and actor.fire_control.measured_range_m == 0, "measurement cannot publish a contact before its timer completes")
	await drive(cmd, 40)
	check(actor.fire_control.status == "measured" and actor.fire_control.measured_range_m == 600.0, "real contact becomes the expected 25m-resolution range estimate")
	check(actor.fire_control.zeroing_m == 0.0 and actor.turret.barrel_direction().angle_to(direct) < 0.001, "measuring alone leaves zero setting and mechanical aim unchanged")
	var baseline := await shoot(cmd, "unadjusted 300m/s shot")
	var baseline_error := INF
	if not baseline.is_empty():
		baseline_error = (baseline.impact_point as Vector3).distance_to(contact)
		check(baseline.reason == "impact_world" and baseline.impact_point.y < contact.y - 10.0, "actual unadjusted low-speed shell visibly falls below the observed wall point")
	cmd.apply_range_requested = true
	await drive(cmd)
	cmd.apply_range_requested = false
	check(actor.fire_control.zeroing_m == 600.0 and actor.turret.aim_error_deg() > 0.03, "applying measured range changes aim demand while finite gun motion still has error")
	await drive(cmd, 80)
	check(actor.turret.aim_error_deg() < 0.03, "finite mechanism naturally reaches the stationary firing solution")
	contact = optical_contact_point()
	var slow_solution := actor.fire_control.aim_solution(actor)
	cmd.select_shell = 1
	await drive(cmd)
	cmd.select_shell = -1
	check(actor.gunner.shell.id == slow.id and actor.fire_control.aim_solution(actor).direction.is_equal_approx(slow_solution.direction), "selecting next ammo does not change the loaded round's ballistic demand")
	var corrected := await shoot(cmd, "adjusted 300m/s shot")
	if not corrected.is_empty():
		var error := (corrected.impact_point as Vector3).distance_to(contact)
		check(corrected.reason == "impact_world" and corrected.shell_id == slow.id and error < 0.75 and error < baseline_error * 0.15, "range application corrects the real slow-shell impact within 75cm (error=%.3fm)" % error)
	check(actor.gunner.shell.id == fast.id and actor.gunner.inventory.chamber_shell == fast.id, "ordinary post-shot transfer really chambers the selected faster round")
	check(chamber_probe.transitions > 0 and chamber_probe.maximum_error < 0.001, "the first tick that chambers a new shell already demands that shell's trajectory (error=%.6frad)" % chamber_probe.maximum_error)
	var fast_solution := actor.fire_control.aim_solution(actor)
	check(fast_solution.get("ok", false) and slow_solution.get("ok", false) and fast_solution.time_s < slow_solution.time_s * 0.6 and fast_solution.direction.angle_to(slow_solution.direction) > 0.01, "ballistic demand recomputes from the actual chambered shell, not Actor's original shell")
	# A different optical pitch creates a genuinely different target elevation.
	cmd.aim_intent.pitch = deg_to_rad(3.0)
	await drive(cmd, 80)
	await measure(cmd)
	check(actor.fire_control.status == "measured", "elevated wall point can be measured with the new chambered shell")
	cmd.apply_range_requested = true
	await drive(cmd)
	cmd.apply_range_requested = false
	await drive(cmd, 65)
	contact = optical_contact_point()
	check(contact.y > actor.turret.muzzle.global_position.y + 25.0, "second impact scenario has a real positive target height difference")
	var elevated := await shoot(cmd, "adjusted elevated 600m/s shot")
	if not elevated.is_empty():
		var error := (elevated.impact_point as Vector3).distance_to(contact)
		check(elevated.reason == "impact_world" and elevated.shell_id == fast.id and error < 0.75, "actual faster projectile reaches the elevated sight point within 75cm (error=%.3fm)" % error)
	# An active wire intent does not have to carry the local player's clear_aim.
	cmd.clear_aim = false
	cmd.zeroing_steps = -20
	await drive(cmd)
	cmd.zeroing_steps = 0
	await drive(cmd, 50)
	check(actor.fire_control.zeroing_m == 0.0 and actor.turret._aim_point().is_equal_approx(actor.cam_rig.intent_point()), "returning to zero clears old ballistic override even without clear_aim")
	cmd.zeroing_steps = 6
	await drive(cmd)
	cmd.zeroing_steps = 0
	await drive(cmd, 45)
	var saved_lifetime := actor.gunner.shell.max_flight_time_s
	actor.gunner.shell.max_flight_time_s = 0.001
	await drive(cmd, 45)
	check(not actor.fire_control.solution_ok and actor.fire_control.solution_reason == "flight_time_exceeded" and actor.turret._aim_point().is_equal_approx(actor.cam_rig.intent_point()), "unreachable lifetime reports failure and removes the previous successful ballistic override")
	actor.gunner.shell.max_flight_time_s = saved_lifetime

func check_lifecycle() -> void:
	var cmd := command()
	await drive(cmd, 70)
	await measure(cmd)
	check(actor.fire_control.status == "measured", "lifecycle fixture obtains a real successful measurement")
	var validity := actor.fire_control.valid_left_s
	var setting := actor.fire_control.zeroing_m
	scene._pause()
	await ticks(8)
	check(actor.fire_control.valid_left_s == validity and actor.fire_control.zeroing_m == setting, "paused production scene freezes measurement validity and manual setting")
	scene._resume()
	await drive(cmd)
	# Use the public fixed-step state entry for a long elapsed interval; no
	# wall-clock wait or assignment manufactures an expired measurement.
	actor.fire_control.advance(actor, cmd, actor.definition.optics_profile.measurement_valid_s + 0.01)
	check(actor.fire_control.status == "expired" and actor.fire_control.valid_left_s == 0.0, "authority time expiry marks the range stale")
	cmd.apply_range_requested = true
	await drive(cmd)
	cmd.apply_range_requested = false
	check(actor.fire_control.reason == "no_measurement" and actor.fire_control.zeroing_m == setting, "expired reading cannot overwrite the retained manual range setting")
	cmd.range_requested = true
	await drive(cmd)
	cmd.range_requested = false
	scene._pause()
	check(actor.fire_control.status == "failed" and actor.fire_control.measurement_left_s == 0.0, "pausing cancels an unfinished authority measurement")
	scene._resume()
	await drive(cmd, 135)
	check(actor.fire_control.status == "failed" and actor.fire_control.measured_range_m == 0.0, "resume never completes a cancelled measurement or replays its old edge")
	cmd.range_requested = true
	await drive(cmd)
	cmd.range_requested = false
	cmd.aim_intent.mode = "free"
	await drive(cmd)
	check(actor.fire_control.status == "failed" and actor.fire_control.reason == "observation_changed", "changing from sight to free observation cancels the pending sample")
	cmd = command()
	await drive(cmd, 25)
	cmd.range_requested = true
	await drive(cmd)
	cmd.range_requested = false
	cmd.aim_intent.yaw = 0.03
	await drive(cmd)
	check(actor.fire_control.status == "failed" and actor.fire_control.reason == "aim_moved", "changing optical bearing during measurement invalidates the sample")
	cmd = command()
	await drive(cmd, 40)
	cmd.range_requested = true
	await drive(cmd)
	cmd.range_requested = false
	var person := str(actor.state.crew_assignments.get("gunner", ""))
	check(not person.is_empty(), "admitted sample vehicle has an actual gunner crew assignment")
	if not person.is_empty():
		actor.state.crew_states[person].alive = false
		await drive(cmd)
		check(actor.fire_control.status == "failed", "loss of assigned gunner cancels the gun-sight measurement")
		actor.state.crew_states[person].alive = true
	cmd = command("binocular")
	await drive(cmd, 25)
	var shots := actor.gunner.shots_fired
	cmd.fire_requested = true
	await drive(cmd)
	cmd.fire_requested = false
	check(actor.gunner.shots_fired == shots, "binocular command cannot fire the real main gun")
	await measure(cmd)
	check(actor.fire_control.status == "measured", "commander binocular mode measures a real contact while gun axes remain held")
	cmd = command("chase")
	await measure(cmd)
	check(actor.fire_control.status == "failed" and actor.fire_control.reason == "sight_required", "chase view cannot request a range estimate")
	cmd = command("sight", deg_to_rad(20.0))
	await drive(cmd, 120)
	await measure(cmd)
	check(actor.fire_control.status == "failed" and actor.fire_control.measured_range_m == 0.0, "sky fallback never becomes a successful measurement")
	cmd = command()
	wall.position.z = -2200.5
	await drive(cmd, 120)
	await measure(cmd)
	check(actor.fire_control.status == "failed" and actor.fire_control.measured_range_m == 0.0, "wall outside the 2km instrument limit is not reported as max range")
	wall.position.z = -600.5
	await drive(cmd, 30)
	cmd.range_requested = true
	await drive(cmd)
	cmd.range_requested = false
	actor.reset_vehicle()
	check(actor.fire_control.status == "idle" and actor.fire_control.zeroing_m == 0.0 and actor.fire_control.measured_range_m == 0.0 and actor.fire_control.measurement_left_s == 0.0, "vehicle reset clears reading, measurement timer and manual range setting")
	await drive(command(), 135)
	check(actor.fire_control.status == "idle", "new vehicle generation does not inherit a pending range request")

func check_command_contract() -> void:
	var box := CommandMailbox.new()
	var first := command()
	first.aim_intent.yaw = 0.2
	first.range_requested = true
	first.zeroing_steps = 2
	check(box.submit(first), "mailbox accepts a valid optical input edge")
	first.aim_intent.yaw = 0.9
	first.range_requested = false
	var copied := box.consume()
	check(is_equal_approx(copied.aim_intent.yaw, 0.2) and copied.range_requested, "mailbox deep-copies nested AimIntent and edge flags")
	var second := command()
	second.apply_range_requested = true
	second.zeroing_steps = -1
	box.submit(copied)
	box.submit(second)
	var merged := box.consume()
	check(merged.range_requested and merged.apply_range_requested and merged.zeroing_steps == 1 and merged.aim_intent.yaw == 0.0, "merged inputs preserve both edges, add signed range steps and use newest optical direction")
	var consumed := box.consume()
	check(not consumed.range_requested and not consumed.apply_range_requested and consumed.zeroing_steps == 0, "consumed range edges and steps never repeat on the next tick")
	var packet := VehicleCommandCodec.encode(merged, actor, 1, Engine.get_physics_frames())
	var decoded := VehicleCommandCodec.decode(JSON.parse_string(JSON.stringify(packet)))
	check(decoded.ok and decoded.command.range_requested and decoded.command.apply_range_requested and decoded.command.zeroing_steps == 1, "strict versioned JSON command round trip preserves range operations")
	for fault in ["nan_yaw", "unknown_mode", "numeric_active", "missing_intent", "extra_measured_range", "too_many_steps", "fractional_steps", "numeric_range_edge", "ambiguous_point"]:
		var malformed: Dictionary = packet.duplicate(true)
		match fault:
			"nan_yaw": malformed.command.aim_intent.yaw = NAN
			"unknown_mode": malformed.command.aim_intent.mode = "radar"
			"numeric_active": malformed.command.aim_intent.active = 1
			"missing_intent": malformed.command.erase("aim_intent")
			"extra_measured_range": malformed.command.measured_range_m = 600.0
			"too_many_steps": malformed.command.zeroing_steps = 21
			"fractional_steps": malformed.command.zeroing_steps = 0.5
			"numeric_range_edge": malformed.command.range_requested = 1
			"ambiguous_point": malformed.command.has_aim_point = true; malformed.command.clear_aim = false
		check(not VehicleCommandCodec.decode(malformed).ok, "malformed optical command is rejected: " + fault)
	var bad := command()
	bad.aim_intent.yaw = NAN
	check(not box.submit(bad), "local mailbox rejects nonfinite AimIntent before mutation")
	bad = command()
	bad.aim_intent = null
	check(not box.submit(bad), "local mailbox rejects a missing intent object")
	merged.reset()
	check(not merged.aim_intent.active and not merged.range_requested and not merged.apply_range_requested and merged.zeroing_steps == 0, "VehicleCommand.reset clears all fire-control input state")
