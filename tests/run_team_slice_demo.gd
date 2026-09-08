extends Node
## A reproducible keyboard/mouse session. Reads own HUD and sanitized visible markers only.
var app: AppFlow
var scene: VillageRange
var count := 0
var failed := 0
var shot_dir := ""
var held := {KEY_W:false,KEY_A:false,KEY_D:false}
var mouse_down := false
var captures := {}
var next_aim := 0.0
var next_recovery := 0.0
var next_shot := 0.0
var next_status := 0.0
var saw_repair := false
var saw_death := false
var saw_respawn := false
var requested_abandon := false
var waypoints := [Vector3(-72,0,116),Vector3(-120,0,65),Vector3(-120,0,0),Vector3(-72,0,-50),Vector3(-42,0,-20),Vector3(-8,0,6)]
var waypoint := 0
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 3) -> void:
	for i in n: await get_tree().physics_frame
	await get_tree().process_frame
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func hold(code: Key, pressed: bool) -> void:
	if held[code] == pressed: return
	held[code] = pressed
	key(code,pressed)
func release_drive() -> void:
	for code in held: hold(code,false)
func mouse(pressed: bool) -> void:
	mouse_down = pressed
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
func tap(code: Key) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)
func click(button: Control) -> void:
	for i in 3: await get_tree().process_frame
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for i in 3: await get_tree().process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		for i in 3: await get_tree().process_frame
	await frames(10)
func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found := find_button(child,title)
		if found != null: return found
	return null
func capture(id: String) -> void:
	if captures.has(id): return
	captures[id] = true
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	check(not image.is_empty() and image.save_png(shot_dir.path_join(id+".png")) == OK,"actual exported window capture "+id)
func aim_from_public_markers() -> bool:
	var own := scene.actor
	var intel := scene.battle_ui.intel.snapshot(own)
	var nearest := INF
	var target := Vector3.ZERO
	var found := false
	for marker in intel.markers:
		if marker.kind != "enemy": continue
		var d: float = own.tank.global_position.distance_to(marker.position)
		if d>=nearest: continue
		nearest = d
		target = marker.position
		found = true
	if not found: return false
	# Marker position is the visible tank's public centre, not a hidden module coordinate.
	target.y += [0.0,0.7,-0.25][own.gunner.shots_fired%3]
	var offset := target-own.cam_rig.cam.global_position
	var yaw := atan2(-offset.x,-offset.z)
	var pitch := atan2(offset.y,Vector2(offset.x,offset.z).length())
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(wrapf(own.cam_rig.aim_yaw-yaw,-PI,PI),own.cam_rig.aim_pitch-pitch)/GameConfig.MOUSE_SENS
	Input.parse_input_event(motion)
	return true
func drive() -> void:
	var own := scene.actor
	if not own.capabilities().drive or not own.state.recovery_action.is_empty() or waypoint>=waypoints.size(): release_drive(); return
	var offset: Vector3 = (waypoints[waypoint]-own.tank.global_position)*Vector3(1,0,1)
	if offset.length()<3.5:
		waypoint += 1
		release_drive()
		return
	var forward := VehiclePose.flat_forward(own.tank.global_basis)
	var angle := wrapf(atan2(-offset.x,-offset.z)-atan2(-forward.x,-forward.z),-PI,PI)
	hold(KEY_A,angle>deg_to_rad(2))
	hold(KEY_D,angle<deg_to_rad(-2))
	hold(KEY_W,absf(angle)<deg_to_rad(12))
func run(flow: AppFlow) -> void:
	app = flow
	if DisplayServer.get_name() == "headless": get_tree().quit(1); return
	var args := OS.get_cmdline_user_args()
	var index := args.find("--shot-dir")
	if index<0 or index+1>=args.size(): get_tree().quit(1); return
	shot_dir = ProjectSettings.globalize_path(args[index+1])
	DirAccess.make_dir_recursive_absolute(shot_dir)
	get_tree().root.size = Vector2i(1280,720)
	await frames(20)
	await capture("01_exported_garage")
	for i in 6:
		for pressed in [true,false]:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.position = Vector2(260,460)
			wheel.pressed = pressed
			Input.parse_input_event(wheel)
			await frames(2)
	await click(find_button(app.garage,"4 对 4 占点"))
	scene = app.training as VillageRange
	check(scene != null and not scene.ai_only,"normal exported garage click starts player plus seven AI")
	if scene == null: finish(); return
	var original_id := scene.get_round_id()
	await capture("02_countdown")
	while scene.director.state.phase == "countdown": await frames()
	var maximum := {"actors":0,"wrecks":0,"projectiles":0,"nodes":0}
	var started := Time.get_ticks_msec()
	var last_frame := Time.get_ticks_usec()
	var frame_times := PackedFloat64Array()
	while scene.director.state.phase == "playing" and Time.get_ticks_msec()-started<750000:
		if mouse_down: mouse(false)
		var own := scene.actor
		var now := scene.director.state.elapsed
		if own.state.destroyed:
			release_drive()
			saw_death = true
			await capture("06_death_lineup")
			if not scene.respawn_button.disabled:
				await click(scene.respawn_button)
				saw_respawn = not scene.actor.state.destroyed
				waypoint = 0
				await capture("07_redeployed")
		else:
			drive()
			if now>=next_recovery:
				next_recovery = now+1.0
				if not own.state.fires.is_empty(): await tap(KEY_F)
				elif not own.capabilities().drive or not own.capabilities().fire:
					release_drive()
					await tap(KEY_C if not own.state.role_available("driver") or not own.state.role_available("gunner") else KEY_T)
			if own.state.recovery_action == "repair": saw_repair = true; await capture("05_actual_repair")
			if now>=next_aim:
				next_aim = now+0.15
				var visible := aim_from_public_markers()
				if visible and now>=next_shot and own.capabilities().fire and own.gunner.cooldown_left<=0:
					next_shot = now+2.05
					mouse(true)
			if own.gunner.shots_fired>0: await capture("03_first_real_shot")
			if own.tank.global_position.y>5: await capture("04_hill_flank")
			# A documented ordinary abandon command guarantees the redeploy UI is exercised;
			# it really deducts tickets and does not fabricate an enemy-caused death.
			if now>65 and not saw_death and not requested_abandon:
				requested_abandon = true
				release_drive()
				if mouse_down: mouse(false)
				await tap(KEY_ESCAPE)
				await click(find_button(scene.hud._pause_root,"放弃当前车（扣30票）"))
		if now>=next_status:
			next_status = now+15
			var snapshot := TelemetrySnapshot.capture(scene)
			for key in maximum: maximum[key] = maxi(maximum[key],int(snapshot[key]))
			print("[normal player %.1fs] tickets=%s deaths=%d player_shots=%d position=%s"%[now,scene.director.state.tickets,scene.director.state.roster.A.deaths,scene.director.player_shots,scene.actor.tank.global_position])
		await RenderingServer.frame_post_draw
		var frame_now := Time.get_ticks_usec()
		if now>10: frame_times.append((frame_now-last_frame)/1000.0)
		last_frame = frame_now
	release_drive()
	if mouse_down: mouse(false)
	check(scene.director.state.phase == "finished" and scene.director.state.finish_count == 1 and not scene.director.state.result.is_empty(),"T019-H01 normal player session naturally reaches one real result")
	check(saw_death and saw_respawn,"actual death/ordinary abandon and eight-second redeploy occurred in the full session")
	check(scene.director.player_shots>0,"player used ordinary mouse fire during the match")
	await capture("08_actual_match_result")
	var result := scene.director.state.result.duplicate(true)
	var report := {"result":result,"saw_repair":saw_repair,"saw_death":saw_death,"saw_respawn":saw_respawn,"ordinary_abandon_requested":requested_abandon,"max":maximum,"frame_intervals_including_captures":TelemetrySnapshot.frame_summary(frame_times),"human":"NOT_RUN"}
	var file := FileAccess.open(shot_dir.path_join("SESSION.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
	if scene.director.state.phase == "finished":
		await click(scene.restart_button)
		scene = app.training as VillageRange
		check(scene != null and scene.get_round_id()!=original_id and not scene.ai_only and scene.actor.controller == scene.controller,"normal result button starts a second match with correct player binding")
		await capture("09_second_match")
		await tap(KEY_ESCAPE)
		await click(scene.hud._training_btn)
		check(app.training == null and app.garage != null,"normal pause return cleans second battle and restores garage")
		await capture("10_returned_garage")
	finish()
func finish() -> void:
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("TEAM_SLICE_PLAYER_CHECKS_PASS" if failed == 0 else "TEAM_SLICE_PLAYER_CHECKS_FAIL")
	get_tree().quit(0 if failed == 0 else 1)
