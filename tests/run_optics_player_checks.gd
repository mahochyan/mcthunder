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
func key(code: int, down: bool) -> void:
	var e := InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.pressed=down
	Input.parse_input_event(e); await ticks(4)
func mouse(button: int, down: bool) -> void:
	var e := InputEventMouseButton.new(); e.button_index=button; e.pressed=down
	Input.parse_input_event(e); await ticks(4)
func motion(amount: Vector2) -> void:
	var e := InputEventMouseMotion.new(); e.relative=amount
	Input.parse_input_event(e); await ticks(4)
func shot(name: String) -> void:
	var args := OS.get_cmdline_user_args(); var index := args.find("--shot-dir")
	if index<0 or index+1>=args.size(): check(false,"capture directory provided"); return
	var folder := args[index+1]; DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"actual capture "+name)
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	InputBindingService.initialize()
	var space := SubViewport.new(); space.own_world_3d=true; root.add_child(space)
	var server := NetworkBattleServer.new(); space.add_child(server)
	check(server.start(19115)==OK,"production authority starts with observation contract")
	server.world.actors[1].tank.global_position=Vector3(0,0,-35) # Visible opposing vehicle fixture.
	var view := NetworkClientView.new(); view.port=19115; root.add_child(view)
	await ticks(90)
	check(view.owned!=null,"normal client connects")
	if view.owned==null: view.free(); space.free(); quit(1); return
	var authority: VehicleActor
	for actor in server.world.actors:
		if actor.entity_id==view.connection.entity_id: authority=actor
	var camera := view.owned.cam_rig
	view.player.commands_enabled=true; Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await mouse(MOUSE_BUTTON_RIGHT,true); await ticks(60)
	check(camera.sight and camera.cam.fov==camera.optics().sight_fovs[0],"right mouse enters actual client gun sight")
	var enemy_skin: MeshInstance3D=view.actors.B.tank.hull_frame.get_node("Skin_hull")
	var own_skin: MeshInstance3D=view.owned.tank.hull_frame.get_node("Skin_hull")
	check(camera.cam.cull_mask&enemy_skin.layers!=0 and camera.cam.cull_mask&own_skin.layers==0,"gun sight renders opposing armor while hiding only own armor")
	await shot("00_scope_enemy_visible")
	var before := Vector2(authority.turret.rotation.y,authority.turret.barrel_pivot.rotation.x)
	await key(KEY_Z,true); await key(KEY_Z,false)
	check(camera.cam.fov==camera.optics().sight_fovs[1] and camera.zoom_step==1,"Z changes real client projection to second magnification")
	check(Vector2(authority.turret.rotation.y,authority.turret.barrel_pivot.rotation.x).distance_to(before)<0.0001,"zoom does not change authoritative weapon angles")
	var yaw := camera.aim_yaw
	var scale := camera.input_sensitivity_scale()
	await motion(Vector2(100,0))
	check(is_equal_approx(wrapf(yaw-camera.aim_yaw,-PI,PI),100*GameConfig.MOUSE_SENS*AccessibilitySettings.mouse_sensitivity*scale),"real magnified mouse input uses FOV-scaled angular motion")
	await shot("01_scope_zoom")
	await mouse(MOUSE_BUTTON_RIGHT,false); await ticks(90)
	var saved := Vector2(camera.aim_yaw,camera.aim_pitch)
	await key(KEY_L,true); await ticks(12)
	check(camera.binoculars and not camera.sight and authority.turret.observation_hold,"held L activates binocular view and real server hold")
	check(camera.cam.cull_mask&enemy_skin.layers!=0 and camera.cam.cull_mask&own_skin.layers==0,"binocular view preserves opposing vehicle visibility")
	var fixed := Vector2(authority.turret.rotation.y,authority.turret.barrel_pivot.rotation.x)
	var root_yaw := authority.tank.global_rotation.y
	await key(KEY_D,true); await key(KEY_W,true)
	await motion(Vector2(220,-40)); await ticks(90)
	check(absf(wrapf(authority.tank.global_rotation.y-root_yaw,-PI,PI))>0.1,"normal controls still steer and move during observation")
	check(Vector2(authority.turret.rotation.y,authority.turret.barrel_pivot.rotation.x).is_equal_approx(fixed),"server preserves both local gun axes while hull turns during binocular observation")
	await mouse(MOUSE_BUTTON_LEFT,true)
	check(authority.gunner.shots_fired==0,"binocular observation does not accidentally fire")
	print("[OBSERVATION] camera=",camera.cam.global_transform," aim=",Vector2(camera.aim_yaw,camera.aim_pitch)," authority_hold=",authority.turret.observation_hold," root=",authority.tank.global_position," accepted=",server.accepted," rejected=",server.rejected)
	await shot("02_binocular_observation")
	await key(KEY_D,false); await key(KEY_W,false); await key(KEY_L,false)
	check(Vector2(camera.aim_yaw,camera.aim_pitch).is_equal_approx(saved) and not camera.binoculars,"releasing L restores original aiming direction")
	await ticks(30)
	check(not authority.turret.observation_hold and authority.gunner.shots_fired==0,"release resumes pursuit without replaying held fire edge")
	await mouse(MOUSE_BUTTON_LEFT,false); await ticks(10)
	await mouse(MOUSE_BUTTON_LEFT,true); await mouse(MOUSE_BUTTON_LEFT,false); await ticks(12)
	check(authority.gunner.shots_fired==1 and view.owned.gunner.shots_fired==0,"new mouse edge fires one real authoritative projectile")
	await key(KEY_L,true); await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(not camera.is_observing() and not view.player.commands_enabled,"Escape cancels optics through normal input pause")
	await key(KEY_ENTER,true); await key(KEY_ENTER,false)
	check(not camera.is_observing(),"held L cannot reactivate observation across pause")
	await key(KEY_L,false); await ticks(5); await key(KEY_L,true)
	check(camera.binoculars,"fresh binocular press works after release guard")
	authority.reset_vehicle(); await ticks(30)
	check(not camera.is_observing() and camera.zoom_step==0,"server generation reset clears client optics without inheriting held key")
	await key(KEY_L,false)
	view.free(); space.free(); await process_frame
	# Normal battle HUD with real M4 actor; enemy controllers disabled as an explicit UI fixture.
	var battle := TeamRange.new(); battle.selected_vehicle_id=VehicleCatalog.IDS[0]
	root.add_child(battle); current_scene=battle; await ticks(200)
	for actor in battle.combat_actors():
		if actor!=battle.actor: actor.set_controller(null)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await motion(Vector2(200,0))
	check(battle.battle_ui.overlay.view_model.aim_error_degrees>0.5 and battle.battle_ui.overlay.optics_label.text.contains("追瞄"),"normal battle HUD explains mechanical pursuit separately from reload readiness")
	await shot("03_battle_tracking")
	await key(KEY_L,true)
	check(battle.actor.cam_rig.binoculars and battle.battle_ui.overlay.view_model.observing,"binocular input also uses normal offline battle path")
	await shot("04_battle_binocular")
	await key(KEY_L,false)
	battle.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("OPTICS_PLAYER_CHECKS_PASS" if failures==0 else "OPTICS_PLAYER_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
