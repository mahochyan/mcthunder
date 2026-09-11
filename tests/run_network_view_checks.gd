extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1
	print(("[PASS] " if value else "[FAIL] ")+message)
func wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until: await process_frame
func run() -> void:
	var view := NetworkClientView.new(); view.port=19111; root.add_child(view)
	await wait_seconds(2)
	check(view.owned!=null,"interactive client receives server-assigned vehicle")
	if view.owned==null: view.free(); quit(1); return
	var observer := NetworkBattleClient.new(); root.add_child(observer); observer.connect_local(19111)
	await wait_seconds(1)
	check(observer.entity_id!="" and observer.entity_id!=view.connection.entity_id,"second connected peer owns a different vehicle")
	var start := view.owned.tank.global_position
	view.player.commands_enabled=true
	Input.action_press("move_forward")
	var until := Time.get_ticks_msec()+1000
	var intermediate_frames := 0
	var previous_sequence := -1
	var previous_position := start
	var observed_hull_pitch := false
	while Time.get_ticks_msec()<until:
		await RenderingServer.frame_post_draw
		var sequence := int(view.connection.latest.get("sequence",-1))
		var position := view.owned.tank.global_position
		if absf(view.owned.tank.global_rotation.x)>0.0001: observed_hull_pitch=true
		if sequence==previous_sequence and position.distance_to(previous_position)>0.0001:
			intermediate_frames+=1
		previous_sequence=sequence; previous_position=position
	check(intermediate_frames>=5,"rendered replica moves between authoritative packet arrivals (%d frames)"%intermediate_frames)
	check(observed_hull_pitch,"rendered client receives actual server acceleration pitch")
	Input.action_release("move_forward")
	await wait_seconds(0.5)
	check(view.owned.tank.global_position.distance_to(start)>0.5,"keyboard drive traverses real network and returns as server movement")
	view.player.require_fire_release()
	await wait_seconds(0.15)
	var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; Input.parse_input_event(event)
	await wait_seconds(0.1)
	event=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=false; Input.parse_input_event(event)
	await wait_seconds(0.5)
	var shots := 0
	for row in view.connection.latest.vehicles:
		if row.entity_id==view.connection.entity_id: shots=int(row.shots)
	check(shots==1,"mouse edge creates one server-authoritative shot")
	check(view.connection.own_status.has("ammo") and float(view.connection.own_status.cooldown)>0,"own ammunition and reload feedback comes from server")
	check(view.owned.gunner.shots_fired==0 and view.owned.tank.drive_call_count()==0,"client replica does not run local gunner or driving")
	var file := OS.get_cmdline_user_args()[0]
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(file)==OK,"actual interactive client frame saved")
	var previous_epoch := -1
	for row in view.connection.latest.vehicles:
		if row.entity_id==view.connection.entity_id: previous_epoch=int(row.control_epoch)
	view.connection.close(); view.clear_input()
	await wait_seconds(0.5)
	var reconnect := InputEventKey.new(); reconnect.keycode=KEY_R; reconnect.pressed=true; Input.parse_input_event(reconnect)
	await wait_seconds(0.8)
	var epoch := -1
	for row in view.connection.latest.get("vehicles",[]):
		if row.entity_id==view.connection.entity_id: epoch=int(row.control_epoch)
	check(epoch>previous_epoch,"disconnect and new handshake change authoritative control epoch")
	check(view.owned!=null and view.player.commands_enabled,"R key reconnect restores interactive control")
	check(not view.player._fire_pending,"disconnect does not retain a fire edge")
	view.connection.disconnected.emit()
	check(view.pose_buffer.frames.is_empty() and not view.player.commands_enabled,"transport disconnect clears interpolation and disables input")
	view.free(); observer.free()
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("NETWORK_VIEW_CHECKS_PASS" if failures==0 else "NETWORK_VIEW_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
