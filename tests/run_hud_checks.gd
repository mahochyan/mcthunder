extends SceneTree
var count := 0
var failed := 0
var scene: TeamRange
var test_clock := 0.0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await frames()
func tap(code: Key) -> void:
	await key(code,true)
	await key(code,false)
func fire(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)
	await frames()
func fresh() -> void:
	if is_instance_valid(scene): scene.free()
	scene = TeamRange.new()
	root.add_child(scene)
	current_scene = scene
	await frames(190)
	scene.director.set_physics_process(false)
	for vehicle in scene.combat_actors():
		vehicle.set_physics_process(false)
		vehicle.tank.velocity = Vector3.ZERO
		vehicle.tank.forward_speed = 0
	scene.battle_ui.intel.set_physics_process(false)
func damage(id: String) -> void:
	var vehicle := scene.actor
	vehicle.apply_projectile_damage({"kind":"module","module_id":id,"entity_id":vehicle.entity_id,"life_id":vehicle.life_id,"event_id":"hud_"+id,"round_id":scene.get_round_id()},120)
func model_cases() -> void:
	await fresh()
	var vehicle := scene.actor
	var before := {"damage":vehicle.state.damage_snapshot(),"ammo":vehicle.gunner.inventory.snapshot(),"cooldown":vehicle.gunner.cooldown_left,"tickets":scene.director.state.tickets.duplicate(),"generation":vehicle.state.generation}
	var model := HUDPresenter.present(vehicle,scene.battle_ui.match_info())
	check(model.ammo == vehicle.gunner.rounds_remaining and model.cooldown == vehicle.gunner.cooldown_left and model.actual_point == vehicle.gunner.actual_hit_point,"T017-01 ammo, reload and actual barrel point come from production gunner")
	for i in 100: HUDPresenter.present(vehicle,scene.battle_ui.match_info())
	check(vehicle.state.damage_snapshot() == before.damage and vehicle.gunner.inventory.snapshot() == before.ammo and vehicle.gunner.cooldown_left == before.cooldown and scene.director.state.tickets == before.tickets and vehicle.state.generation == before.generation,"T017-H04 repeated HUD presentation cannot change health, ammo, timers, tickets or identity")
	model.modules[0].fraction = -100
	model.match.phase = "fake"
	check(vehicle.state.damage_snapshot() == before.damage and scene.director.state.phase == "playing","view-model mutation cannot write into authoritative state")
	damage("track_left")
	damage("breech")
	damage("engine")
	model = HUDPresenter.present(vehicle,scene.battle_ui.match_info())
	check(model.drive_text.contains("左履带") and model.drive_text.contains("发动机") and model.weapon_text.contains("炮闩") and not model.ready,"damaged drive and gun show separate concrete capability reasons")
	var command := VehicleCommand.new()
	command.repair_requested = true
	vehicle._apply_command_once(command,1.0/60)
	model = HUDPresenter.present(vehicle,scene.battle_ui.match_info())
	check(model.fire and model.recovery_feedback.contains("先按 F") and model.weapon_text.contains("炮闩"),"fire, rejected repair and weapon restriction remain visible concurrently")
	command = VehicleCommand.new()
	command.extinguish_requested = true
	vehicle._apply_command_once(command,1.0/60)
	model = HUDPresenter.present(vehicle,scene.battle_ui.match_info())
	check(model.action_duration == RecoveryRules.EXTINGUISH_SECONDS and model.action_progress == vehicle.state.action_progress and model.extinguishers == vehicle.state.extinguisher_charges,"recovery progress and extinguisher charge reflect same real action")
	vehicle.gunner.try_fire()
	model = HUDPresenter.present(vehicle,scene.battle_ui.match_info())
	check(not model.shot_feedback.is_empty() and not model.action.is_empty() and model.fire,"last firing rejection does not overwrite fire or current action")
func intel_cases() -> void:
	await fresh()
	var own := scene.actor
	var enemy := scene.director.state.actor_for("B")
	var intelligence := scene.battle_ui.intel
	intelligence.sensor.clear()
	intelligence.observations.clear()
	intelligence._observer_life = -1
	intelligence._next_scan = 0
	intelligence.actor_provider = func() -> Array: return [own,enemy]
	intelligence.observer_provider = func() -> VehicleActor: return own
	intelligence.clock_provider = func() -> float: return test_clock
	intelligence.sensor.actor_provider = intelligence.actor_provider
	own.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(0,0.03,48))
	enemy.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(0,0.03,22))
	own.turret.set_aim_point(enemy.tank.global_position+Vector3.UP*2.2)
	own.turret.snap_to_aim()
	await frames()
	test_clock = 1
	intelligence._physics_process(0.3)
	var snapshot := intelligence.snapshot(own)
	check(snapshot.markers.size() == 1 and snapshot.markers[0].kind == "self","T017-02 never-seen enemy behind actual spawn wall stays absent from minimap")
	own.tank.global_position.x = 30
	enemy.tank.global_position.x = 30
	own.turret.set_aim_point(enemy.tank.global_position+Vector3.UP*2.2)
	own.turret.snap_to_aim()
	await frames()
	test_clock = 2
	intelligence._physics_process(0.3)
	snapshot = intelligence.snapshot(own)
	check(snapshot.markers.size() == 2 and snapshot.markers[1].kind == "enemy" and intelligence.visible_enemy("B",enemy.life_id),"visible exterior creates one enemy marker and permits its world label")
	var last_position: Vector3 = snapshot.markers[1].position
	check(not snapshot.markers[1].has("modules") and not snapshot.markers[1].has("actor") and not snapshot.markers[1].has("health"),"minimap accepts sanitized numeric observations without enemy internals")
	own.tank.global_position.x = 0
	enemy.tank.global_position = Vector3(0,0.03,22)
	await frames()
	test_clock = 3
	intelligence._physics_process(0.3)
	snapshot = intelligence.snapshot(own)
	check(snapshot.markers[1].kind == "last_seen" and snapshot.markers[1].position == last_position and not intelligence.visible_enemy("B",enemy.life_id),"lost sight leaves hollow last-seen marker and hides enemy world label")
	enemy.tank.global_position.z = 18
	await frames()
	test_clock = 4
	intelligence._physics_process(0.3)
	check(intelligence.snapshot(own).markers[1].position == last_position,"moving under cover cannot update remembered minimap coordinates")
	test_clock = 9
	intelligence._physics_process(0.3)
	check(intelligence.snapshot(own).markers.size() == 1,"six-second expired enemy marker disappears")
func layout_cases() -> void:
	await fresh()
	var ui := scene.battle_ui.overlay
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size = dimensions
		for scale_factor in [1.0,1.25]:
			AccessibilitySettings.ui_scale = scale_factor
			scene.battle_ui.apply_settings()
			await frames(6)
			var viewport := Rect2(Vector2.ZERO,Vector2(dimensions))
			var panels := [ui.header,ui.own_panel,ui.weapon_panel,ui.map_panel]
			var inside := true
			var separated := true
			for i in panels.size():
				inside = inside and viewport.encloses(panels[i].get_global_rect())
				for j in range(i+1,panels.size()): separated = separated and not panels[i].get_global_rect().intersects(panels[j].get_global_rect())
			check(inside and separated,"T017-03 primary HUD containers fit and do not overlap at %sx scale %.2f"%[dimensions,scale_factor])
			check(viewport.encloses(ui.replay_close_button.get_global_rect()),"replay close control stays completely inside viewport at %sx scale %.2f"%[dimensions,scale_factor])
			ui.scoreboard.visible = true
			await frames(3)
			check(viewport.encloses(ui.scoreboard_panel.get_global_rect()) and ui.board_close_button.is_visible_in_tree(),"battle status and close control remain in viewport")
			ui.scoreboard.visible = false
			scene._pause()
			scene.battle_ui._open_settings()
			await frames(3)
			check(viewport.encloses(ui.settings_panel.get_global_rect()) and ui.settings_close_button.is_visible_in_tree(),"settings and large-font choices remain in viewport")
			scene.battle_ui._close_settings()
			scene._resume()
	AccessibilitySettings.ui_scale = 1.0
	scene.battle_ui.apply_settings()
func input_cases() -> void:
	await fresh()
	var ui := scene.battle_ui
	var gun := scene.actor.gunner
	var before := gun.shots_fired
	await tap(KEY_TAB)
	check(ui.overlay.scoreboard.visible and ui.focus.mode == "scoreboard" and not scene.controller.commands_enabled,"T017-04 Tab opens battle status and disables driving/fire intent")
	await fire(true)
	ui._close_board()
	await frames()
	var command := scene.controller.poll()
	check(not command.fire_requested and gun.shots_fired == before,"closing panel while fire is held cannot emit a shot")
	await fire(false)
	await fire(true)
	command = scene.controller.poll()
	check(command.fire_requested,"fresh release-then-press works again after panel closure")
	await fire(false)
	await tap(KEY_V)
	check(not scene.replay.view.visible and ui.focus.mode == "playing" and ui.overlay.notice.contains("结束后"),"playing match rejects replay overlay with a clear HUD message")
	scene._pause()
	await frames()
	check(ui.focus.mode == "pause" and not scene.controller.commands_enabled and not ui.overlay.aim_allowed,"pause releases focus and hides aiming marker")
	ui._open_settings()
	await frames()
	check(ui.focus.mode == "settings" and not scene.hud._pause_root.visible,"settings replace pause controls without concurrent clickable layers")
	var damage_before := scene.actor.state.damage_snapshot()
	var ammo_before := gun.inventory.snapshot()
	AccessibilitySettings.reduce_flashes = true
	AccessibilitySettings.stable_camera = true
	AccessibilitySettings.replay_enabled = false
	ui.apply_settings()
	scene.actor.turret.kick_recoil()
	scene.actor.cam_rig._process(0)
	check(not scene.actor.turret._flash.visible and scene.actor.cam_rig.cam.h_offset == 0 and scene.actor.cam_rig.cam.v_offset == 0,"reduced flash and stable camera directly suppress optical effects")
	check(scene.actor.state.damage_snapshot() == damage_before and gun.inventory.snapshot() == ammo_before,"accessibility choices leave combat state and ammunition unchanged")
	check(not scene.replay.allowed_record.call({}),"disabled replay preference also gates the actual replay controller")
	ui._close_settings()
	scene._resume()
	await frames()
	check(ui.focus.mode == "playing" and scene.controller.commands_enabled,"resume returns focus to the same living local actor")
	scene.abandon_vehicle()
	scene.director.advance(0.01)
	await frames()
	check(ui.focus.mode == "respawn" and not scene.controller.commands_enabled and scene.waiting_panel.visible,"death uses selection focus without leaving input on the wreck")
	await tap(KEY_E)
	check(scene.spectator_index == 1,"017 E preserves friendly spectator switching while Tab is battle status")
	scene.director.advance(8)
	scene.request_respawn()
	scene.director.advance(0.01)
	await frames()
	check(ui.focus.mode == "playing" and not scene.waiting_panel.visible and scene.controller.commands_enabled,"new player life restores driving focus once after redeploy")
	AccessibilitySettings.reduce_flashes = false
	AccessibilitySettings.stable_camera = true
	AccessibilitySettings.replay_enabled = true
	ui.apply_settings()
	# A real stopped projectile supplies the finished-mode replay, without synthetic records.
	var enemy := scene.director.state.actor_for("B")
	var drive := VehicleCommand.new()
	drive.throttle = 1
	scene.director.observe_command(enemy,drive)
	var spec := {"round_id":scene.get_round_id(),"shooter_id":"A","shooter_life_id":scene.actor.life_id,"shooter_team_id":1,"shot_id":1701,"shell_id":"hud_fixture_ap","armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,120)]),"position_world":enemy.tank.global_transform*Vector3(0,1.2,-4),"velocity_world":enemy.tank.global_basis*Vector3(0,0,600),"gravity_world":Vector3.ZERO,"max_age_s":2.0,"max_distance_m":100.0}
	var accepted := scene.projectiles.try_spawn(spec)
	check(accepted.ok,"actual manager accepts the replay input fixture")
	var projectile := scene.projectiles.get_projectile_state(accepted.projectile_id)
	scene.projectiles.advance_projectile(projectile,1.0/60,scene.query_snapshots(),scene.get_world_3d().direct_space_state)
	check(projectile.is_terminal() and not projectile.contacts.is_empty(),"actual stopped shot yields contact geometry for replay")
	scene.director.finish_once("victory","test_fixture")
	await frames()
	var result_before := scene.director.state.result.duplicate(true)
	await tap(KEY_V)
	check(scene.replay.view.visible and ui.focus.mode == "replay" and not scene.result_panel.visible and not scene.controller.commands_enabled,"finished real-shot replay takes focus and replaces result controls")
	await tap(KEY_V)
	check(not scene.replay.view.visible and ui.focus.mode == "finished" and scene.result_panel.visible and scene.director.state.result == result_before,"closing replay restores result focus without changing frozen outcome")
func _run() -> void:
	root.size = Vector2i(1280,720)
	await model_cases()
	await intel_cases()
	await layout_cases()
	await input_cases()
	scene.free()
	current_scene = null
	await frames()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("HUD_CHECKS_PASS" if failed == 0 else "HUD_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
