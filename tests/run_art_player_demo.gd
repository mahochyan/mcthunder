extends "res://tests/run_challenge_demo.gd"
## Normal garage, keys, mouse, real finite shots and reset. Reads structural state
## only to verify outcomes; never teleports or writes damage, timers or ammunition.
func run(flow: AppFlow) -> void:
	app=flow
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--shot-dir" and i+1<args.size(): shot_dir=args[i+1]
	if shot_dir.is_empty(): shot_dir=ProjectSettings.globalize_path("res://docs/evidence/025/wip-player")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await frames(30)
	await click(app.garage.challenge_button)
	await click(app.garage.challenge_selection.start_button)
	await frames(210)
	var scene:=app.training as ChallengeRange
	check(scene!=null and scene.director.phase=="playing","normal challenge entry reaches live village world")
	if scene==null: get_tree().quit(1); return
	var starting_profile:=app.profile.snapshot()
	for point in [Vector3(64,0,32),Vector3(76,0,72),Vector3(82,0,120),Vector3(108,0,142),Vector3(125,0,141)]:
		check(await drive_to(scene,point),"normal WASD reaches optional shed approach "+str(point))
	var shed:=scene.get_node("Special_shed_1/Section0") as DestructibleSection
	var brick:=scene.get_node("Special_brick_screen_1/Section1") as DestructibleSection
	await aim_at(scene,shed.global_position+Vector3.UP*1.6)
	await capture("01_shed_intact")
	await fire_section(scene,shed,1)
	await capture("02_shed_damaged")
	await fire_section(scene,shed,2)
	await frames(100)
	await capture("03_shed_collapsed")
	check(await drive_to(scene,Vector3(125,0,125)),"normal tank drives into the collapsed shed footprint")
	check(await drive_to(scene,Vector3(121,0,117)),"normal tank reaches brick screen from shed")
	await aim_at(scene,brick.global_position+Vector3.UP*1.4)
	await capture("04_brick_intact")
	await fire_section(scene,brick,1); await fire_section(scene,brick,2)
	await frames(100)
	await capture("05_brick_breach")
	check(await drive_to(scene,Vector3(121,0,98)),"normal WASD crosses the real central breach")
	await aim_at(scene,brick.global_position+Vector3.UP*1.4)
	await capture("06_driven_through")
	check(scene.actor.gunner.shots_fired==4 and scene.actor.gunner.rounds_remaining==2,"four normal shots consume four of six rounds; no free shots")
	var old_life:=scene.actor.life_id
	await tap(KEY_R); await frames(210)
	scene=app.training as ChallengeRange
	var fresh:=scene!=null and scene.actor.life_id!=old_life
	if fresh:
		for section in scene.find_children("*","DestructibleSection",true,false): fresh=fresh and section.hits==0 and not section._shape.disabled
	check(fresh,"normal R retry reconstructs intact structures and a fresh vehicle life")
	await tap(KEY_ESCAPE); await frames(10)
	await click(scene.hud._training_btn); await frames(20)
	check(app.training==null and app.garage!=null and app.profile.snapshot()==starting_profile,"normal pause/return leaves isolated profile unchanged")
	await capture("07_returned_garage")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	if failed==0: print("ART_PLAYER_CHECKS_PASS")
	get_tree().quit(0 if failed==0 else 1)

func fire_section(scene: ChallengeRange, section: DestructibleSection, expected: int) -> void:
	var before:=scene.actor.gunner.shots_fired
	for i in 900:
		if scene.actor.gunner.cooldown_left<=0 and scene.actor.gunner.inventory.chamber==1: break
		await frames(1)
	mouse(MOUSE_BUTTON_LEFT,true); await frames(3); mouse(MOUSE_BUTTON_LEFT,false)
	await frames(25)
	check(scene.actor.gunner.shots_fired==before+1 and section.hits==expected,"normal left click produces structural state "+str(expected))
