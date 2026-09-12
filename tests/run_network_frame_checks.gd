extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func ticks(count: int) -> void:
	for i in count: await physics_frame
	await process_frame
func run() -> void:
	# Separate physics worlds just as separate server/client processes have.
	var server_space := SubViewport.new(); server_space.own_world_3d=true; root.add_child(server_space)
	var server := NetworkBattleServer.new(); server_space.add_child(server)
	check(server.start(19113)==OK,"real loopback authority starts")
	if not server.world.ready_ok: server_space.free(); quit(1); return
	var view := NetworkClientView.new(); view.port=19113; root.add_child(view)
	# This fixture transmits nonzero authoritative part poses, not invented springs.
	# The view keeps its real receive/render paths; user commands are disabled.
	view.set_physics_process(false)
	await ticks(60)
	check(view.owned!=null,"production client handshake accepts pose protocol v2")
	if view.owned==null: view.free(); server_space.free(); quit(1); return
	var authority: VehicleActor
	for actor in server.world.actors:
		if actor.entity_id==view.connection.entity_id: authority=actor
	authority.tank.hull_frame.transform=Transform3D(Basis(Vector3.FORWARD,0.08),Vector3(0,-0.16,0))
	authority.tank.track_left_frame.transform=Transform3D(Basis(Vector3.RIGHT,0.03),Vector3(0,0.07,0))
	authority.tank.track_right_frame.transform=Transform3D(Basis(Vector3.RIGHT,-0.02),Vector3(0,-0.04,0))
	await ticks(30)
	check(view.connection.latest.version==2,"wire snapshot explicitly identifies revised pose format")
	for part in VehicleFramePose.PARTS:
		check(VehicleFramePose.node(view.owned.tank,part).transform.is_equal_approx(VehicleFramePose.node(authority.tank,part).transform),"real transport and rendered replica preserve relative "+part)
	var server_query := QuerySnapshotBuilder.build_from_vehicle(authority.tank,authority.damage_layout_override)
	var replica_query := QuerySnapshotBuilder.build_from_vehicle(view.owned.tank,view.owned.damage_layout_override)
	for part in ["hull","running_left","running_right","turret","barrel"]:
		check(server_query.part_world_transforms[part].is_equal_approx(replica_query.part_world_transforms[part]),"displayed world geometry matches stationary authority "+part)
	check(view.owned.turret.muzzle.global_transform.is_equal_approx(authority.turret.muzzle.global_transform),"displayed muzzle follows server hull rather than drive collision")
	if DisplayServer.get_name()!="headless":
		var args := OS.get_cmdline_user_args()
		var index := args.find("--shot-dir")
		if index>=0 and index+1<args.size():
			var folder := args[index+1]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(folder+"/01_network_relative_pose.png")==OK,"actual network replica frame captured")
	var state := VehicleFramePose.capture(authority.tank)
	var json_copy: Dictionary=JSON.parse_string(JSON.stringify(state))
	check(VehicleFramePose.valid(json_copy),"relative pose survives JSON round trip")
	json_copy.hull.position[1]=0.5
	json_copy.running_right.rotation=[0,0,0,0]
	check(not VehicleFramePose.apply(authority.tank,json_copy) and VehicleFramePose.capture(authority.tank)==state,"malformed right frame cannot partially overwrite hull")
	var frozen := server.world.snapshot(999)
	view.owned.tank.hull_frame.position.y=0.8
	check(VehicleFramePose.capture(authority.tank)==state,"client presentation changes cannot alter authority")
	authority.reset_vehicle()
	await ticks(30)
	check(view.pose_buffer.frames[-1].vehicles.any(func(row: Dictionary) -> bool: return row.entity_id==authority.entity_id and row.generation==authority.state.generation),"reset generation reaches actual client")
	for part in VehicleFramePose.PARTS:
		check(VehicleFramePose.node(view.owned.tank,part).transform==Transform3D.IDENTITY,"reset replaces old relative pose "+part)
	check(frozen.vehicles.filter(func(row: Dictionary) -> bool: return row.entity_id==authority.entity_id)[0].frame_pose==state,"captured packet remains immutable across reset")
	check(view.owned.tank.drive_call_count()==0 and view.owned.gunner.shots_fired==0,"replica still has no local driving or firing authority")
	view.free(); server_space.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("NETWORK_FRAME_CHECKS_PASS" if failures==0 else "NETWORK_FRAME_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
