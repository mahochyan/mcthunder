extends SceneTree
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
func run() -> void:
	InputBindingService.initialize()
	var scene := BallisticsRange.new(); scene.selected_vehicle_id=VehicleCatalog.IDS[0]
	root.add_child(scene); current_scene=scene
	await ticks(35)
	var actor := scene.actor; actor.set_controller(null)
	var camera := actor.cam_rig
	check(actor.definition.optics_profile.sight_fovs.size()==2,"M4 production package supplies two optic steps")
	var definitions := VehicleDefs.new(); definitions.load_defaults(); VehicleCatalog.new().load_all(definitions)
	check(definitions.vehicles[VehicleCatalog.IDS[1]].optics_profile.sight_fovs[0]!=camera.optics().sight_fovs[0],"M24 uses its own admitted optics profile")
	camera.set_sight_requested(true); camera._update_camera_pose()
	check(camera.sight and camera.cam.fov==camera.optics().sight_fovs[0],"actual gun sight consumes first FOV")
	check(camera.cam.global_position.is_equal_approx(actor.turret.barrel_pivot.to_global(camera.optics().sight_offset)),"scope uses authored local optical offset")
	var muzzle := actor.turret.muzzle.global_transform
	camera.cycle_zoom(); camera._update_camera_pose()
	check(camera.cam.fov==camera.optics().sight_fovs[1] and actor.turret.muzzle.global_transform==muzzle,"zoom changes actual projection without moving weapon")
	check(camera.input_sensitivity_scale()<0.25,"magnified input has reduced angular sensitivity")
	camera.cycle_zoom(); check(camera.zoom_step==0,"zoom cycles through only configured FOV steps")
	var saved := Vector2(camera.aim_yaw,camera.aim_pitch)
	camera.set_observation(false,true); camera.set_aim(0.6,0.1); camera._update_camera_pose()
	check(camera.binoculars and not camera.sight and camera.cam.fov==camera.optics().binocular_fov,"binocular view takes precedence over held gun sight")
	check(camera.cam.global_position.is_equal_approx(actor.tank.hull_frame.to_global(camera.optics().binocular_offset)),"binocular origin follows actual sprung hull")
	camera.set_observation(true,false); camera._update_camera_pose()
	check(camera.free_look and camera.is_observing() and is_equal_approx(camera.aim_yaw,0.6),"switching observation modes does not overwrite saved gun intent")
	camera.set_observation(false,false)
	check(Vector2(camera.aim_yaw,camera.aim_pitch).is_equal_approx(saved),"leaving observation restores pre-observation aim")
	actor.turret.set_aim_point(actor.turret.barrel_pivot.global_position+Vector3(0,0,-500)); actor.turret.snap_to_aim()
	var wall := TerrainFixtures.box(scene,actor.turret.barrel_pivot.global_position+Vector3(0,0,-1),Vector3(0.2,3,0.3))
	await ticks(2); camera.set_aim(0,0); camera.set_sight_requested(true); camera.refresh_intent()
	check(camera.intent_point().z<wall.global_position.z-10,"offset scope observes beyond cover using the actual optical origin")
	var ammo := actor.gunner.rounds_remaining
	check(not actor.gunner.request_fire() and actor.gunner.blocked_reason=="barrel_occluded" and actor.gunner.rounds_remaining==ammo,"visible optical line does not permit firing a barrel inside cover")
	wall.free(); await ticks(2)
	actor.turret.set_aim_point(actor.turret.barrel_pivot.global_position+Vector3(0,100,-1)); actor.turret.snap_to_aim()
	var model := HUDPresenter.present(actor,{})
	check(actor.turret.aim_error_deg()<0.01 and model.aim_error_degrees>45,"pitch stop cannot falsely report aligned to unreachable target")
	var cmd := VehicleCommand.new(); cmd.hold_aim=true; cmd.has_aim_point=true; cmd.aim_world_point=Vector3(100,5,-30)
	var packet := VehicleCommandCodec.encode(cmd,actor,1,Engine.get_physics_frames())
	check(packet.version==VehicleCommandCodec.VERSION and VehicleCommandCodec.decode(JSON.parse_string(JSON.stringify(packet))).command.hold_aim,"observation hold has a strict versioned wire contract")
	packet.command.hold_aim=1
	check(not VehicleCommandCodec.decode(packet).ok,"numeric observation flag is rejected")
	packet=VehicleCommandCodec.encode(cmd,actor,1,Engine.get_physics_frames()); packet.version=1
	check(not VehicleCommandCodec.decode(packet).ok,"old command version is explicitly rejected")
	var yaw := actor.turret.rotation.y; var pitch := actor.turret.barrel_pivot.rotation.x
	for i in 30:
		actor.submit_command(cmd); await physics_frame
	check(actor.turret.rotation.y==yaw and actor.turret.barrel_pivot.rotation.x==pitch,"authoritative command holds both axes without a local observation camera")
	cmd.hold_aim=false; actor.submit_command(cmd); await ticks(2)
	check(actor.turret.rotation.y!=yaw,"released observation resumes finite mechanical pursuit")
	camera.set_sight_requested(true); camera.cycle_zoom(); camera.set_observation(false,true)
	actor.reset_vehicle()
	check(camera.zoom_step==0 and not camera.is_observing() and not actor.turret.observation_hold,"vehicle reset clears zoom observation and mechanical hold")
	# Explicit render/physics boundary: observe fire, then release binoculars
	# before the next command consumption. No synthetic projectile is inserted.
	var player := PlayerController.new(); scene.add_child(player); player.cam_rig=camera
	camera.set_observation(false,true)
	Input.action_press("fire"); player._process(1.0/60)
	camera.set_observation(false,false)
	check(not player.poll().fire_requested,"leaving binoculars between render capture and physics cannot release an old fire edge")
	Input.action_release("fire"); player.free()
	var bad := OpticsProfile.new(); bad.sight_fovs=PackedFloat32Array([15,30])
	check(not bad.validate().is_empty(),"out-of-order zoom profiles fail admission")
	bad=OpticsProfile.new(); bad.binocular_offset=Vector3.INF
	check(not bad.validate().is_empty(),"nonfinite optic geometry fails admission")
	var previous := InputBindingService.bindings.duplicate()
	previous.erase("binoculars"); previous.erase("optic_zoom"); previous.erase("free_look"); previous.fire=KEY_L
	var path := "user://tests/optics-migration-"+str(Time.get_ticks_usec())+".json"
	DirAccess.make_dir_recursive_absolute("user://tests")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":2,"bindings":previous,"accessibility":AccessibilitySettings.DEFAULTS,"display":InputBindingService.DISPLAY_DEFAULT,"language":"zh_CN"})); file.close()
	var loaded := InputBindingService.read_settings(path)
	check(loaded.ok and loaded.data.bindings.fire==KEY_L and loaded.data.bindings.binoculars!=KEY_L and loaded.data.bindings.has("optic_zoom"),"old settings preserve occupied keys while adding optics actions")
	DirAccess.remove_absolute(path)
	scene.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("OPTICS_CHECKS_PASS" if failures==0 else "OPTICS_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
