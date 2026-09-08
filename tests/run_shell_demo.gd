extends "res://tests/run_historical_demo.gd"
## Actual menu, mouse aim, number keys, fire, natural reload and replay. No combat-state writes.
var player_flow_complete := false
var battle_flow_complete := false

func aim_at(scene: ShellRange) -> void:
	for pass_index in 3:
		var delta := scene.target_actor.tank.global_transform*Vector3(0,2,2)-scene.actor.cam_rig.cam.global_position
		var yaw := atan2(-delta.x,-delta.z)
		var pitch := atan2(delta.y,Vector2(delta.x,delta.z).length())
		var motion := InputEventMouseMotion.new()
		motion.relative=Vector2(-(yaw-scene.actor.cam_rig.aim_yaw)/GameConfig.MOUSE_SENS,-(pitch-scene.actor.cam_rig.aim_pitch)/GameConfig.MOUSE_SENS)
		Input.parse_input_event(motion); await frames(25)

func fire(scene: ShellRange) -> Dictionary:
	var before := scene.actor.gunner.shots_fired
	mouse(MOUSE_BUTTON_LEFT,true); await frames(3); mouse(MOUSE_BUTTON_LEFT,false)
	await frames(12)
	check(scene.actor.gunner.shots_fired==before+1,"one normal mouse shot is accepted")
	return scene.projectiles.shot_records.get_record(scene.projectiles.shot_records.count()-1)

func ready(scene: ShellRange) -> void:
	for i in 300:
		if scene.actor.gunner.cooldown_left<=0: break
		await frames(1)
	check(scene.actor.gunner.cooldown_left<=0,"natural reload reaches ready state")

func run(flow: AppFlow) -> void:
	app=flow
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--shot-dir" and i+1<args.size(): shot_dir=args[i+1]
	if shot_dir.is_empty(): shot_dir=ProjectSettings.globalize_path("res://docs/evidence/021/wip")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await frames(30)
	var button := find_button(app.garage,"AP / APHE 弹药实验室")
	check(button!=null,"normal garage includes ammunition laboratory")
	if button==null: finish(); return
	for i in 18:
		var rect := button.get_global_rect()
		if rect.position.y>100 and rect.end.y<690: break
		mouse(MOUSE_BUTTON_WHEEL_DOWN,true,Vector2(230,560)); mouse(MOUSE_BUTTON_WHEEL_DOWN,false,Vector2(230,560)); await frames(3)
	await capture("00_garage_entry")
	await click(button); await frames(35)
	var scene := app.training as ShellRange
	check(scene!=null,"real menu click enters shell laboratory")
	if scene==null: finish(); return
	check(scene.actor.gunner.shots_fired==0,"menu click cannot leak into a shot")
	await aim_at(scene); await capture("01_ready")
	await tap(KEY_2)
	check(scene.actor.gunner.inventory.chamber_shell=="test_ap120" and scene.actor.gunner.inventory.selected_shell=="test_aphe96","key 2 changes next round while AP stays in chamber")
	var record := await fire(scene)
	check(record.identity.shell_id=="test_ap120" and record.damage.is_empty(),"AP first shot follows actual narrow path through thin compartment")
	await tap(KEY_1)
	check(scene.actor.gunner.inventory.transfer_shell=="test_aphe96" and scene.actor.gunner.inventory.selected_shell=="test_ap120","key 1 cannot transform APHE already being loaded")
	if scene.replay.view.visible: await tap(KEY_V)
	await capture("02_fixed_transfer")
	await ready(scene)
	check(scene.actor.gunner.inventory.chamber_shell=="test_aphe96","natural reload places actual APHE in chamber")
	await capture("03_aphe_loaded")
	record=await fire(scene)
	check(record.identity.shell_id=="test_aphe96" and record.fragments.size()==12 and record.damage.size()>0,"actual APHE reaches thin compartment and damages off-axis modules")
	if scene.replay.view.visible: await tap(KEY_V)
	await tap(KEY_V)
	for i in scene.replay.view.events.size():
		await tap(KEY_N)
		if scene.replay.view.events[scene.replay.view.selected_event].get("fragment_id",-1)>=0: break
	await frames(8)
	check(scene.replay.view.visible and not scene.replay.view.playing and scene.replay.view.current_time>=float(record.burst.time_s)-0.000001 and scene.replay.view._fragments.mesh!=null,"normal V and N controls display the actual fragment burst")
	check(scene.replay.view.record.get("fragments",[])==record.fragments,"visible replay retains the exact recorded fragment paths")
	await capture("04_aphe_replay")
	var damage_before := scene.target_actor.state.damage_snapshot()
	if scene.replay.view.visible: await tap(KEY_V)
	await tap(KEY_X); await tap(KEY_X); await frames(8)
	check(not scene.replay.view.visible and scene.xray,"actual damaged modules are visible in X-ray mode")
	check(scene.target_actor.state.damage_snapshot()==damage_before,"X-ray and replay controls cannot change damage")
	await capture("05_actual_module_damage")
	await tap(KEY_X); await tap(KEY_4); await ready(scene); await aim_at(scene)
	await tap(KEY_2)
	record=await fire(scene)
	check(record.identity.shell_id=="test_ap120" and not record.contacts.is_empty() and record.contacts[0].result=="penetrated","loaded AP penetrates thick target while APHE is selected for next load")
	check(scene.status_label.text.contains("AP 120: entry penetrated"),"visible comparison explicitly reports AP penetration of the first thick plate")
	if scene.replay.view.visible: await tap(KEY_V)
	await capture("06_thick_ap")
	await ready(scene)
	record=await fire(scene)
	check(record.identity.shell_id=="test_aphe96" and record.fragments.is_empty() and not record.contacts.is_empty() and record.contacts[0].result=="stopped","APHE cannot penetrate the same thick target and creates no fragments")
	check(scene.status_label.text.contains("APHE 96: entry stopped"),"visible comparison explicitly reports APHE stopping at the first thick plate")
	if scene.replay.view.visible: await tap(KEY_V)
	await capture("07_thick_aphe")
	check(scene.actor.gunner.rounds_remaining==16 and scene.actor.gunner.inventory.conserved(),"four normal shots consume exactly four typed rounds")
	await tap(KEY_ESCAPE); await frames(5)
	check(scene._paused,"Esc opens real pause menu")
	await click(scene.hud._training_btn); await frames(20)
	check(is_instance_valid(app.garage) and app.training==null,"normal return button restores garage")
	await battle_flow()
	player_flow_complete=true
	finish()

func battle_flow() -> void:
	await click(app.garage.vehicle_choice); await tap(KEY_HOME); await tap(KEY_DOWN); await tap(KEY_DOWN); await tap(KEY_ENTER)
	check(app.garage.selected_vehicle_id()==VehicleCatalog.IDS[0],"normal popup selects historical M4 for battle supply test")
	var button := find_button(app.garage,"4 对 4 占点")
	for i in 12:
		if button.get_global_rect().end.y<690: break
		mouse(MOUSE_BUTTON_WHEEL_DOWN,true,Vector2(230,560)); mouse(MOUSE_BUTTON_WHEEL_DOWN,false,Vector2(230,560)); await frames(3)
	await click(button); await frames(200)
	var battle := app.training as VillageRange
	check(battle!=null and battle.team_ready,"normal menu enters actual village battle with historical loadout")
	if battle==null: return
	await capture("08_battle_ready")
	await tap(KEY_2)
	mouse(MOUSE_BUTTON_LEFT,true); await frames(3); mouse(MOUSE_BUTTON_LEFT,false); await frames(8)
	check(battle.actor.gunner.shots_fired==1 and battle.actor.gunner.inventory.transfer_shell.ends_with("m61_m3"),"normal battle input carries historical M61 while first M72 has fired")
	await capture("09_battle_loading")
	var goal: Vector3=battle.supply_positions(1)[0]
	var held := {KEY_W:false,KEY_S:false,KEY_A:false,KEY_D:false}
	for i in 2400:
		var offset := goal-battle.actor.tank.global_position
		var distance := Vector2(offset.x,offset.z).length()
		var difference := wrapf(atan2(-offset.x,-offset.z)-battle.actor.tank.rotation.y,-PI,PI)
		var speed := battle.actor.tank.forward_speed
		var desired := {KEY_W:distance>4 and absf(difference)<0.15 and speed<3.0,KEY_S:distance<=4 and speed>0.2,KEY_A:distance>4 and difference>0.06,KEY_D:distance>4 and difference< -0.06}
		for code in held:
			if held[code]!=desired[code]: key(code,desired[code]); held[code]=desired[code]
		if distance<=7 and absf(speed)<0.15 and i>60: break
		await frames(1)
	for code in held:
		if held[code]: key(code,false)
	await frames(20)
	check(Vector2(battle.actor.tank.global_position.x-goal.x,battle.actor.tank.global_position.z-goal.z).length()<=AmmunitionSupply.RADIUS_M,"normal W A S D controls drive historical M4 into friendly supply circle")
	await capture("10_battle_supply")
	await frames(150)
	check(battle.actor.gunner.rounds_remaining==battle.actor.weapon.initial_rounds and battle.actor.gunner.inventory.conserved(),"normal parked player replenishes one fired shell through actual village service")
	var panel := battle.battle_ui.overlay
	check(panel.ammo_label.get_global_rect().end.y<=720 and panel.weapon_panel.get_global_rect().end.y<=720,"historical ammunition and supply HUD remains inside 1280 by 720 viewport")
	await capture("11_battle_replenished")
	battle_flow_complete=true

func finish() -> void:
	check(player_flow_complete,"full normal player shell comparison completed")
	check(battle_flow_complete,"full normal player village ammunition flow completed")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("SHELL_PLAYER_CHECKS_PASS" if failed==0 else "SHELL_PLAYER_CHECKS_FAIL")
	get_tree().quit(0 if failed==0 else 1)
