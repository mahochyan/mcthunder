extends SceneTree
## Actual production client commands and suspension, with an explicit 1m ledge.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func ticks(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var args := OS.get_cmdline_user_args(); var index := args.find("--shot-dir")
	if index<0 or index+1>=args.size(): return
	var folder := args[index+1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"actual client capture "+name)
func run() -> void:
	var space := SubViewport.new(); space.own_world_3d=true; root.add_child(space)
	var server := NetworkBattleServer.new(); space.add_child(server)
	check(server.start(19114)==OK and server.world.ready_ok,"production loopback server starts")
	var view := NetworkClientView.new(); view.port=19114; root.add_child(view)
	await ticks(90)
	check(view.owned!=null,"normal client handshake assigns vehicle")
	if view.owned==null: view.free(); space.free(); quit(1); return
	var authority: VehicleActor
	for actor in server.world.actors:
		if actor.entity_id==view.connection.entity_id: authority=actor
	# Same real ledge in isolated server/client worlds; only the server solves it.
	for parent in [server.world,view]:
		TerrainFixtures.box(parent,Vector3(0,0.5,8),Vector3(10,1,10))
	authority.reset_vehicle(); authority.tank.global_position=Vector3(0,1,8)
	await ticks(120)
	check(authority.tank.is_on_floor() and absf(authority.tank.hull_frame.position.y)<0.02,"authority settles on 1m ledge")
	await shot("01_before_departure")
	view.player.commands_enabled=true
	Input.action_press("move_forward")
	var departed := false
	var server_min := 0.0
	var client_min := 0.0
	var client_droop := false
	var captured := false
	for i in 540:
		await process_frame
		var tank := authority.tank
		if not tank.is_on_floor() and tank.global_position.z<3: departed=true
		server_min=minf(server_min,tank.hull_frame.position.y)
		client_min=minf(client_min,view.owned.tank.hull_frame.position.y)
		if view.owned.tank.track_left_frame.position.y < -0.2: client_droop=true
		if departed: Input.action_release("move_forward")
		if departed and view.owned.tank.hull_frame.position.y < -0.03 and not captured:
			captured=true
			await shot("02_landing_response")
	Input.action_release("move_forward")
	check(departed and authority.tank.global_position.z<3,"normal forward input crosses network and drives off ledge")
	check(authority.tank.suspension.impacts==1 and server_min < -0.03,"actual server landing excites spring once")
	check(client_min < -0.03 and client_droop,"rendered replica receives dynamic compression and extension")
	await ticks(120)
	check(authority.tank.is_on_floor() and absf(authority.tank.hull_frame.position.y)<0.02 and absf(view.owned.tank.hull_frame.position.y)<0.02,"authority and delayed display return to rest")
	check(view.owned.tank.drive_call_count()==0 and not view.owned.tank.suspension.initialized,"client never simulates its own suspension or driving")
	check(GeometryOverlay.compare(view.owned).ok,"rendered suspended armor remains aligned")
	print("[NETWORK_SPRING] server_min=",server_min," client_min=",client_min," impacts=",authority.tank.suspension.impacts)
	await shot("03_settled")
	view.free(); space.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("SUSPENSION_NETWORK_CHECKS_PASS" if failures==0 else "SUSPENSION_NETWORK_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
