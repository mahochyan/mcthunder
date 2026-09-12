extends SceneTree
## Real key events -> PlayerController -> command mailbox -> authority catalog
## -> ordinary Gunner chamber transfer and actual ProjectileManager launches.
const SOURCE := "res://tests/run_shell_cycle_player_checks.gd"
const HISTORICAL := "res://configs/vehicles/historical/us_m24_m6_t85e1_1951.json"
var checks := 0
var failures := 0
var world: Node3D
var actor: VehicleActor
var player: PlayerController
var manager: ProjectileManager

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("SHELL_CYCLE_PLAYER_WATCHDOG")
		quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + label)

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
	await process_frame

func send_key(code: int, down: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	event.echo = echo
	Input.parse_input_event(event)

func press(code: int) -> void:
	send_key(code, true)
	await frames(3)
	send_key(code, false)
	await frames(3)

func shoot() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await frames(3)
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	await frames(3)

func claim(value: Variant, unit: String) -> Dictionary:
	return {"value": value, "status": "estimated", "origin": "game_rule", "source_refs": ["fixture"],
		"location": "fixture in run_shell_cycle_player_checks.gd", "note": "TEST ONLY; not historical vehicle performance", "unit": unit}

func fixture(count: int) -> Dictionary:
	# Independent source-bound fixture; do not instantiate another SceneTree test.
	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HISTORICAL))
	packet.evidence_profile = "game_reference"
	packet.admission_status = "candidate"
	packet.verification = "estimated"
	packet.historical_verified = false
	packet.display_name = "TEST ONLY shell-cycle M24 geometry fixture"
	packet.source_binding = {"source_vehicle_id": "test_reference_fixture_m24", "primary_source": "fixture"}
	packet.unit_contract = ReferenceEvidenceGate.UNITS.duplicate()
	packet.sources = {"fixture": {"origin": "game_rule", "source_vehicle_id": "test_reference_fixture_m24",
		"applies_to_identity_ids": [packet.id], "excluded_identity_ids": [], "sha256": FileAccess.get_sha256(SOURCE),
		"artifact": SOURCE, "read_state": "authored"}}
	for field in packet.facts:
		var old: Dictionary = packet.facts[field]
		var unit := ReferenceEvidenceGate.unit_for(field)
		if unit.is_empty():
			unit = "structured" if old.value is Dictionary or old.value is Array else "text"
		packet.facts[field] = claim(old.value, unit)
		if old.status == "unknown":
			packet.facts[field].status = "unknown"
	var shells: Array = []
	var ids: Array = []
	for index in count:
		var shell := {"id": "fixture_shell_" + str(index), "label": "TEST ONLY AP " + str(index),
			"gun": "75-mm M6", "family": "AP", "source_bullet_type": "ap_tank", "effect_policy": "kinetic", "caliber_mm": 75,
			"muzzle_velocity_mps": 600.0 + index * 20.0, "penetration_curve": [[0, 70 + index * 5], [1000, 50 + index * 5]],
			"gravity_scale": 1.0, "max_flight_time_s": 12.0}
		shell.evidence = {
			"identity": claim({"id": shell.id, "gun": shell.gun, "family": shell.family, "source_bullet_type": shell.source_bullet_type, "caliber_mm": shell.caliber_mm}, "structured"),
			"ballistics": claim({"muzzle_velocity_mps": shell.muzzle_velocity_mps, "penetration_curve": shell.penetration_curve.duplicate(true), "gravity_scale": shell.gravity_scale, "max_flight_time_s": shell.max_flight_time_s}, "structured"),
			"effect": claim(shell.effect_policy, "text")}
		shells.append(shell)
		ids.append(shell.id)
	packet.shell_catalog = {"schema_version": 1, "default": "fixture_shell_0", "shells": shells}
	packet.assembly.shell = "fixture_shell_0"
	packet.compatible_shells = ids
	packet.facts["weapon.ammunition"].value = "fixture_shell_0"
	return packet

func install(count: int) -> bool:
	var packet := fixture(count)
	var defs := VehicleDefs.new()
	var admitted := VehicleCatalog.new().register(packet, defs)
	check(admitted.ok, "%d-option fixture passes production reference admission" % count)
	if not admitted.ok:
		print("[DETAIL] ", admitted.errors)
		return false
	world = Node3D.new()
	root.add_child(world)
	TerrainFixtures.box(world, Vector3(0, -0.5, 0), Vector3(100, 1, 100))
	player = PlayerController.new()
	world.add_child(player)
	actor = VehicleActor.new()
	world.add_child(actor)
	var result := actor.setup(defs, packet.id, "shell_cycle_player", 1, Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)), GameConfig.VIS_LAYER_VEHICLE, player)
	check(result.ok and actor.gunner.shell_options.size() == count, "%d-option actor installs its complete authoritative catalog" % count)
	if not result.ok:
		print("[DETAIL] ", result.get("errors", []))
		world.free()
		await frames(2)
		return false
	manager = ProjectileManager.new()
	manager.presentation_enabled = false
	world.add_child(manager)
	manager.exclude_provider = func(_entity: String, _life: int) -> Array[RID]:
		var excluded: Array[RID] = [actor.tank.get_rid()]
		return excluded
	actor.gunner.projectile_manager = manager
	actor.gunner.round_provider = func() -> int: return 3031
	actor.gunner.aim_preview_enabled = false
	await frames(40)
	return result.ok

func run() -> void:
	InputBindingService.initialize()
	InputBindingService.set_context("shell")
	check(InputBindingService.bindings.cycle_shell == KEY_M and InputBindingService.ACTIONS.cycle_shell[2] == "shell", "next-shell action defaults to rebindable M in shell contexts")
	if await install(3):
		await check_player_selection()
		await check_pause_edges()
		check_wire_contract()
		world.free()
		await frames(2)
	if await install(8):
		for index in range(1, 9):
			await press(KEY_M)
			check(actor.gunner.inventory.selected_shell == actor.gunner.shell_options[index % 8].id, "real M input reaches catalog option %d and wraps by actual count" % (index % 8 + 1))
		world.free()
		await frames(2)
	if await install(1):
		var first: String = actor.gunner.inventory.selected_shell
		await press(KEY_M)
		check(actor.gunner.inventory.selected_shell == first and actor.gunner.inventory.conserved(), "single-option catalog cycles safely without an invented second option")
		world.free()
		await frames(2)
	check_settings_migration()
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks, failures])
	print("SHELL_CYCLE_PLAYER_CHECKS_PASS" if failures == 0 else "SHELL_CYCLE_PLAYER_CHECKS_FAIL")
	quit(0 if failures == 0 else 1)

func check_player_selection() -> void:
	var gun := actor.gunner
	var first: String = gun.shell_options[0].id
	var second: String = gun.shell_options[1].id
	var third: String = gun.shell_options[2].id
	await press(KEY_M)
	check(gun.inventory.selected_shell == second and gun.inventory.chamber_shell == first, "real M key selects second option without replacing the loaded shell")
	# An empty read-only gun replica must never decide relative selection.
	var replica := Gunner.new()
	player.gunner = replica
	await press(KEY_M)
	player.gunner = gun
	replica.free()
	check(gun.inventory.selected_shell == third and gun.inventory.chamber_shell == first, "real M key selects third option from authority inventory even when player replica has no catalog")
	var before := gun.shots_fired
	await shoot()
	var original: ProjectileState = manager.get_projectile_state(gun.last_projectile_id)
	check(gun.shots_fired == before + 1 and original != null and original.shell_id == first, "real fire input launches the previously chambered first option")
	check(gun.inventory.transfer_shell == third and gun.cooldown_left > 0.0, "firing begins ordinary transfer of the selected third option")
	await press(KEY_M)
	check(gun.inventory.selected_shell == first and gun.inventory.transfer_shell == third, "cycling wraps the selected catalog without changing the round already being carried")
	await frames(ceili(gun.weapon.reload_time * Engine.physics_ticks_per_second) + 8)
	check(gun.shell.id == third and gun.inventory.chamber_shell == third and gun.cooldown_left == 0.0, "unmodified production reload naturally chambers the third option")
	await shoot()
	var loaded_third: ProjectileState = manager.get_projectile_state(gun.last_projectile_id)
	check(gun.shots_fired == before + 2 and loaded_third != null and loaded_third.shell_id == third and absf(loaded_third.launch_velocity.length() - 640.0) < 0.1, "real fire input launches the third option with its own frozen initial speed")
	check(gun.inventory.conserved(), "actual first and third launches preserve the inventory ledger")
	await press(KEY_2)
	check(gun.inventory.selected_shell == second, "existing 2 shortcut still selects the second option")
	await press(KEY_1)
	check(gun.inventory.selected_shell == first, "existing 1 shortcut still selects the first option")
	check(InputBindingService.apply_binding("cycle_shell", KEY_K).is_empty(), "next-shell action can be rebound through the production binding service")
	await press(KEY_M)
	check(gun.inventory.selected_shell == first, "old M binding no longer changes ammo after rebinding")
	await press(KEY_K)
	check(gun.inventory.selected_shell == second, "rebound physical key changes the real authoritative selection")
	check(InputBindingService.apply_binding("cycle_shell", KEY_M).is_empty(), "default cycling key is restored for following checks")
	await press(KEY_1)
	send_key(KEY_M, true)
	await frames(3)
	send_key(KEY_M, true, true)
	await frames(3)
	send_key(KEY_M, false)
	await frames(3)
	check(gun.inventory.selected_shell == second, "holding or key-repeat echo cycles once per press")

func check_pause_edges() -> void:
	await press(KEY_1)
	var first: String = actor.gunner.shell_options[0].id
	# Freeze only the actor's consumption, capture a real input event, then
	# pause before consumption. Controller notification must discard the edge.
	actor.set_physics_process(false)
	send_key(KEY_M, true)
	await frames(2)
	check(player._cycle_shell_pending, "real input edge is pending before the pause boundary")
	paused = true
	await frames(3)
	check(not player._cycle_shell_pending, "pause notification clears a captured cycle edge")
	paused = false
	actor.set_physics_process(true)
	await frames(5)
	check(actor.gunner.inventory.selected_shell == first, "resume while M remains held cannot replay the pending selection")
	send_key(KEY_M, false)
	await frames(5)
	await press(KEY_M)
	check(actor.gunner.inventory.selected_shell == actor.gunner.shell_options[1].id, "release followed by a new press restores normal cycling")
	player.commands_enabled = false
	await press(KEY_M)
	player.commands_enabled = true
	await frames(5)
	check(actor.gunner.inventory.selected_shell == actor.gunner.shell_options[1].id, "input-disabled overlays cannot leave a delayed cycle edge")

func check_wire_contract() -> void:
	var cmd := VehicleCommand.new()
	cmd.cycle_shell_requested = true
	var box := CommandMailbox.new()
	box.submit(cmd)
	cmd.cycle_shell_requested = false
	box.submit(cmd)
	var merged := box.consume()
	check(merged.cycle_shell_requested and not box.consume().cycle_shell_requested, "mailbox copies and OR-merges the cycle edge for one consumption only")
	var packet := VehicleCommandCodec.encode(merged, actor, 1, Engine.get_physics_frames())
	var decoded := VehicleCommandCodec.decode(JSON.parse_string(JSON.stringify(packet)))
	check(decoded.ok and decoded.command.cycle_shell_requested, "current v3 command transports the cycle intent without a client-computed index")
	packet.command.cycle_shell_requested = 1
	check(not VehicleCommandCodec.decode(packet).ok, "numeric cycle flag is rejected by the strict command contract")
	merged.reset()
	check(not merged.cycle_shell_requested, "command reset clears the new cycle edge")

func check_settings_migration() -> void:
	var previous := InputBindingService.bindings.duplicate()
	previous.erase("cycle_shell")
	previous.fire = KEY_M
	var path := "user://tests/shell-cycle-migration-" + str(Time.get_ticks_usec()) + ".json"
	DirAccess.make_dir_recursive_absolute("user://tests")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 2, "bindings": previous, "accessibility": AccessibilitySettings.DEFAULTS, "display": InputBindingService.DISPLAY_DEFAULT, "language": "zh_CN"}))
	file.close()
	var loaded := InputBindingService.read_settings(path)
	check(loaded.ok and loaded.data.bindings.fire == KEY_M and loaded.data.bindings.cycle_shell != KEY_M, "older settings preserve occupied M while assigning the new action a free key")
	DirAccess.remove_absolute(path)
