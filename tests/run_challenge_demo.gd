extends "res://tests/run_historical_demo.gd"
## Normal garage/buttons, WASD, mouse aim and fire. Reads world and records for
## verification, never changes combat state, poses, clocks, cooldowns or inventory.
var complete := false
func choose(control: OptionButton, index: int) -> void:
	await click(control); await tap(KEY_HOME)
	for step in index+1: await tap(KEY_DOWN)
	await tap(KEY_ENTER)
func drive_to(battle: ChallengeRange, goal: Vector3, maximum_frames := 3600) -> bool:
	var held := {KEY_W:false,KEY_S:false,KEY_A:false,KEY_D:false}
	for i in maximum_frames:
		if battle.actor.state.destroyed or battle.director.phase != "playing": break
		var offset := (goal-battle.actor.tank.global_position)*Vector3(1,0,1)
		var distance := offset.length()
		var difference := wrapf(atan2(-offset.x,-offset.z)-battle.actor.tank.global_rotation.y,-PI,PI)
		var speed := battle.actor.tank.forward_speed
		var desired := {KEY_W:distance>2 and absf(difference)<0.18 and speed<7.0,KEY_S:distance<=2 and speed>0.2,KEY_A:distance>2 and difference>0.06,KEY_D:distance>2 and difference< -0.06}
		for code in held:
			if held[code] != desired[code]: key(code,desired[code]); held[code] = desired[code]
		if distance<=2 and absf(speed)<0.2: break
		await frames(1)
	for code in held:
		if held[code]: key(code,false)
	await frames(20)
	print("[drive] goal=",goal," actual=",battle.actor.tank.global_position," elapsed=",battle.director.elapsed)
	return ((battle.actor.tank.global_position-goal)*Vector3(1,0,1)).length()<4
func aim_at(battle: ChallengeRange, point: Vector3) -> void:
	for pass_index in 6:
		var delta := point-battle.actor.cam_rig.cam.global_position
		var yaw := atan2(-delta.x,-delta.z)
		var pitch := atan2(delta.y,Vector2(delta.x,delta.z).length())
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-wrapf(yaw-battle.actor.cam_rig.aim_yaw,-PI,PI)/GameConfig.MOUSE_SENS,-(pitch-battle.actor.cam_rig.aim_pitch)/GameConfig.MOUSE_SENS)
		Input.parse_input_event(motion); await frames(30)
	await frames(240)
	print("[aim] camera=",battle.actor.cam_rig.cam.global_position," intent=",battle.actor.cam_rig.intent_point()," muzzle=",battle.actor.turret.muzzle.global_position," dir=",battle.actor.turret.barrel_direction())
func run(flow: AppFlow) -> void:
	app = flow
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot-dir" and i+1 < args.size(): shot_dir = args[i+1]
	if shot_dir.is_empty(): shot_dir = ProjectSettings.globalize_path("res://docs/evidence/024/wip")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await frames(30)
	await click(app.garage.challenge_button)
	check(is_instance_valid(app.garage.challenge_selection),"normal garage challenge button opens task selection")
	await capture("01_challenge_rules")
	await click(app.garage.challenge_selection.start_button); await frames(195)
	var battle := app.training as ChallengeRange
	check(battle != null and battle.challenge_ready and battle.director.phase=="playing","normal challenge launch and countdown starts actual scene")
	if battle == null: finish(); return
	check(battle.actor.gunner.shots_fired==0 and battle.actor.gunner.rounds_remaining==6,"launch click leaks no shot and loads exactly six rounds")
	await capture("02_flank_start")
	await tap(KEY_ESCAPE); var stopped := battle.director.elapsed; await frames(30)
	check(battle._paused and battle.director.elapsed==stopped,"normal Esc pause freezes actual challenge clock")
	await click(battle.hud.resume_btn)
	check(await drive_to(battle,Vector3(-16,0,20)),"WASD drives from start toward visible western approach")
	check(await drive_to(battle,Vector3(-16,0,-20)),"WASD reaches side of the static armoured target")
	# Visible lower rear turret flank at the authored target pose; no module-state
	# inspection or damage injection is used to steer this normal mouse shot.
	await aim_at(battle,Vector3(0,1.99,-20.28))
	await capture("03_flank_aim")
	for attempt in 3:
		if battle.director.phase == "finished": break
		for i in 450:
			if battle.actor.gunner.cooldown_left<=0: break
			await frames(1)
		mouse(MOUSE_BUTTON_LEFT,true); await frames(3); mouse(MOUSE_BUTTON_LEFT,false); await frames(30)
		print("[normal shot] shots=",battle.actor.gunner.shots_fired," outcome=",battle.director.result," last=",battle.actor.gunner.last_shot_result)
		if battle.projectiles.shot_records.count()>0:
			var record := battle.projectiles.shot_records.get_record(battle.projectiles.shot_records.count()-1)
			var hits: Array = []; var damage: Array = []
			for contact in record.contacts: hits.append([contact.get("entity_id"),contact.get("surface_id"),contact.result,contact.point_world])
			for event in record.damage: damage.append([event.item_id,event.get("newly_destroyed",false)])
			print("[normal record] ",record.identity," contacts=",hits," damage=",damage," terminal=",record.terminal)
	check(battle.director.phase=="finished" and battle.director.result.status=="passed","normal keyboard and mouse session completes flank challenge")
	check(battle.director.flank_hits.has("B1") and battle.director.kills.has("B1"),"result backed by actual side penetration and attributed death")
	check(app.pending_challenge<0 and app.profile.snapshot().challenge_bests.has("flank_hunter:v1:normal"),"actual personal best is saved after verified success")
	var restored := ProfileStore.new(app.profile._path)
	check(restored.snapshot().challenge_bests==app.profile.snapshot().challenge_bests and restored.snapshot().revision>0,"new store reloads exact best from disk")
	print("[saved profile] ",app.profile._path," best=",restored.snapshot().challenge_bests)
	await capture("04_stars_saved")
	if battle.director.phase == "finished":
		await tap(KEY_V); await frames(15)
		check(battle.replay.view.visible,"normal V opens post-result real shot replay")
		await capture("05_real_shot_replay")
		await tap(KEY_V)
		await click(battle.return_button); await frames(10)
	else:
		await tap(KEY_ESCAPE); await click(battle.hud._training_btn); await frames(10)
	check(is_instance_valid(app.garage),"normal return restores garage")
	await click(app.garage.challenge_button)
	check(app.garage.challenge_selection.best_label.text.contains("星"),"task selection displays saved personal best after returning")
	await capture("06_personal_best")
	await choose(app.garage.challenge_selection.task_choice,1)
	await click(app.garage.challenge_selection.start_button); await frames(195)
	battle = app.training as ChallengeRange
	check(battle.challenge_id=="hold_ground" and battle.director.phase=="playing" and battle.map_definition.id=="industrial_edge_023","normal selector enters industrial finite-wave defense")
	await capture("07_defense_start")
	var old_attempt := battle.director.attempt_id; var old_life := battle.actor.life_id
	await tap(KEY_R); await frames(195)
	battle = app.training as ChallengeRange
	check(battle.director.attempt_id!=old_attempt and battle.actor.life_id!=old_life and battle.combat_actors().size()==2,"normal R retry creates one fresh defense attempt and opponent")
	await tap(KEY_ESCAPE); await click(battle.hud._training_btn); await frames(10)
	await click(app.garage.challenge_button)
	await choose(app.garage.challenge_selection.task_choice,2)
	await choose(app.garage.challenge_selection.level_choice,1)
	await click(app.garage.challenge_selection.start_button); await frames(195)
	battle = app.training as ChallengeRange
	check(battle.challenge_id=="td_route" and battle.difficulty=="hard" and battle.actor.gunner.rounds_remaining==4,"normal selector enters hard M36 route with its actual four-round loadout")
	await capture("08_m36_route_start")
	await tap(KEY_ESCAPE); await click(battle.hud._training_btn); await frames(10)
	check(app.profile.snapshot().challenge_bests.size()==1,"quitting other challenges cannot overwrite or invent personal bests")
	complete = true
	finish()
func finish() -> void:
	check(complete,"normal challenge player flow reached its final step")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	if failed == 0: print("CHALLENGE_DEMO_CHECKS_PASS")
	get_tree().quit(0 if failed == 0 else 1)
