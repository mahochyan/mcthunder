extends "res://tests/run_garage_demo.gd"
## Normal menu, keyboard and mouse input only. No score, clock, actor or controller edits.
func drive_to(scene: TeamRange, goal: Vector3, maximum_frames: int = 3600) -> bool:
	var held := {KEY_W:false,KEY_S:false,KEY_A:false,KEY_D:false}
	for i in maximum_frames:
		if scene.actor.state.destroyed or scene.director.state.phase != "playing": break
		var offset := (goal-scene.actor.tank.global_position)*Vector3(1,0,1)
		var distance := offset.length()
		var difference := wrapf(atan2(-offset.x,-offset.z)-scene.actor.tank.rotation.y,-PI,PI)
		var speed := scene.actor.tank.forward_speed
		var desired := {KEY_W:distance>3 and absf(difference)<0.18 and speed<7.0,KEY_S:distance<=3 and speed>0.2,KEY_A:distance>3 and difference>0.06,KEY_D:distance>3 and difference< -0.06}
		for code in held:
			if held[code] != desired[code]: key(code,desired[code]); held[code] = desired[code]
		if distance<=3 and absf(speed)<0.2: break
		await frames(1)
	for code in held:
		if held[code]: key(code,false)
	await frames(20)
	return ((scene.actor.tank.global_position-goal)*Vector3(1,0,1)).length()<5

func run(flow: AppFlow) -> void:
	app = flow
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--shot-dir" and i+1<args.size(): shot_dir=args[i+1]
	if shot_dir.is_empty(): shot_dir=ProjectSettings.globalize_path("res://docs/evidence/023/wip")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await frames(30)
	await click(find_button(app.garage,"M24\n轻型"))
	await click(app.garage.preparation.settings_button)
	await choose(app.garage.preparation.map_choice,1)
	check(app.garage.preparation.map_choice.text=="工业边缘" and app.garage.preparation.map_note.text.contains("街角"),"actual garage popup selects industrial map with route description")
	await capture("00_industrial_selected")
	await click(find_button(app.garage,"4 对 4 占点"))
	var industrial := app.training as IndustrialRange
	check(industrial != null and industrial.team_ready and industrial.combat_actors().size()==8,"normal start button opens selected industrial eight-vehicle battle")
	if industrial == null: get_tree().quit(1); return
	await frames(195); await capture("01_industrial_spawn")
	check(await drive_to(industrial,Vector3(-78,0,185)),"normal WASD leaves screened spawn via west exit")
	check(await drive_to(industrial,Vector3(-78,0,100)),"normal WASD drives the warehouse access street")
	await capture("02_warehouse_corner")
	var shots_before := industrial.actor.gunner.shots_fired
	mouse(MOUSE_BUTTON_LEFT,true); await frames(2); mouse(MOUSE_BUTTON_LEFT,false); await frames(18)
	check(industrial.actor.gunner.shots_fired==shots_before+1,"normal mouse click fires an actual historical round on industrial map")
	await capture("03_industrial_shot")
	check(await drive_to(industrial,Vector3(-160,0,100)),"normal WASD reaches independent outer road")
	await capture("04_outer_route")
	await observe_finish(industrial,"industrial")
	await capture("05_industrial_result")
	await click(industrial.restart_button)
	await frames(195)
	industrial = app.training as IndustrialRange
	check(industrial != null and industrial.definition.id=="industrial_edge_023","normal result restart button preserves industrial map")
	await capture("06_industrial_restarted")
	await tap(KEY_ESCAPE)
	await click(industrial.hud._training_btn)
	check(app.training==null and app.garage != null,"normal pause return closes restarted industrial match")
	await click(app.garage.preparation.settings_button)
	await choose(app.garage.preparation.map_choice,0)
	check(app.garage.preparation.map_choice.text=="丘陵村落","normal map popup switches back to original village")
	await capture("07_village_selected")
	await click(find_button(app.garage,"4 对 4 占点"))
	var village := app.training as VillageRange
	check(village != null and not village is IndustrialRange and village.definition.id=="hill_village_018","normal start after switch creates village without industrial world")
	await frames(195); await capture("08_village_spawn")
	await observe_finish(village,"village")
	await capture("09_village_result")
	await click(village.return_button)
	check(app.training==null and app.profile.snapshot().research_points==100,"both free matches finish and return without progression rewards")
	await capture("10_returned_garage")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("INDUSTRIAL_PLAYER_CHECKS_PASS" if failed == 0 else "INDUSTRIAL_PLAYER_CHECKS_FAIL")
	get_tree().quit(0 if failed == 0 else 1)

func observe_finish(scene: TeamRange, id: String) -> void:
	# Player stops at their actually driven position; all AI and match rules run unchanged.
	for sample in 122:
		if scene.director.state.phase=="finished": break
		await frames(300)
		if sample%12==0: print("[normal ",id,"] elapsed=",scene.director.state.elapsed," tickets=",scene.director.state.tickets)
	check(scene.director.state.phase=="finished" and scene.result_panel.visible,"normal "+id+" match reaches genuine ticket or time-limit result")
	print("[normal result ",id,"] ",scene.director.state.result)
