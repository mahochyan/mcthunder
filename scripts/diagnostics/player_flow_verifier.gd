extends "res://scripts/diagnostics/window_input_driver.gd"
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
		# WT-040-R1: keep closing until the goal is genuinely reached. The measured stop error was 0.66 m in the
		# package and 0.80 m in the source tree, and that drift alone moved the burst point 0.45 m - enough to
		# credit the loader instead of the ammunition rack - so the tolerance is tightened here. The value stays
		# bounded and the loop can still time out.
		var desired := {KEY_W:distance>0.6 and absf(difference)<0.18 and speed<7.0,KEY_S:distance<=1.2 and speed>0.2,KEY_A:distance>0.6 and difference>0.06,KEY_D:distance>0.6 and difference< -0.06}
		for code in held:
			if held[code] != desired[code]: key(code,desired[code]); held[code] = desired[code]
		if distance<=0.6 and absf(speed)<0.15: break
		await frames(1)
	for code in held:
		if held[code]: key(code,false)
	await frames(20)
	print("[drive] goal=",goal," actual=",battle.actor.tank.global_position," elapsed=",battle.director.elapsed)
	return ((battle.actor.tank.global_position-goal)*Vector3(1,0,1)).length()<1.0
func aim_at(battle: ChallengeRange, point: Vector3) -> void:
	for pass_index in 6:
		var delta := point-battle.actor.cam_rig.cam.global_position
		var yaw := atan2(-delta.x,-delta.z)
		var pitch := atan2(delta.y,Vector2(delta.x,delta.z).length())
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-wrapf(yaw-battle.actor.cam_rig.aim_yaw,-PI,PI)/GameConfig.MOUSE_SENS,-(pitch-battle.actor.cam_rig.aim_pitch)/GameConfig.MOUSE_SENS)
		Input.parse_input_event(motion); await frames(30)
	# WT-040-R1 measured evidence and the correction it forces. The camera's intent_point() is the FIRST surface
	# its ray hits, so for a point behind armour it can never equal that point: a run with forty correction
	# passes ended with the intent still 0.90 m away, which is why waiting for the intent to converge cannot
	# work. What actually decides the shot is the BARREL's own line, so convergence is measured there - as the
	# perpendicular distance from that line to the requested point - and the tolerance is geometric rather than a
	# dot product, because dot > 0.9995 still allows about 1.8 degrees, roughly 0.4 m at thirteen metres, which
	# is more than the target's 0.06 m half-height ammunition rack. The camera keeps being corrected toward the
	# requested point (the barrel follows it), and the barrel is given a bounded number of passes to settle.
	# Nothing about armour, damage, cooldown or inventory is written, and no game criterion is relaxed.
	var aim_tolerance := 0.03
	var aim_target: Vector3 = point
	var aim_settled := false
	for pass_index in 60:
		var muzzle_at: Vector3 = battle.actor.turret.muzzle.global_position
		var barrel_dir: Vector3 = battle.actor.turret.barrel_direction()
		var to_point: Vector3 = point - muzzle_at
		var miss: float = (to_point - barrel_dir*to_point.dot(barrel_dir)).length()
		if miss <= aim_tolerance:
			aim_settled = true
			print("[aim] barrel converged miss=%.4f m on pass %d" % [miss, pass_index])
			break
		# WT-040-R1: the camera's intent_point is the FIRST surface its ray hits, so aiming it at a point behind
		# armour pins the barrel about 0.13 m high - measured residuals were 0.1396 m from one firing position
		# and 0.1316 m from another, which is why the position was ruled out as the cause. The camera target is
		# therefore shifted each pass by the vector from where the barrel line passes closest to the requested
		# point, so the correction acts on the barrel's own error. No game value is written or relaxed.
		aim_target = aim_target + (point - (muzzle_at + barrel_dir*to_point.dot(barrel_dir)))
		var aim_delta := aim_target - battle.actor.cam_rig.cam.global_position
		var aim_yaw := atan2(-aim_delta.x,-aim_delta.z)
		var aim_pitch := atan2(aim_delta.y,Vector2(aim_delta.x,aim_delta.z).length())
		var aim_motion := InputEventMouseMotion.new()
		aim_motion.relative = Vector2(-wrapf(aim_yaw-battle.actor.cam_rig.aim_yaw,-PI,PI)/GameConfig.MOUSE_SENS,-(aim_pitch-battle.actor.cam_rig.aim_pitch)/GameConfig.MOUSE_SENS)
		Input.parse_input_event(aim_motion); await frames(20)
	if not aim_settled:
		var muzzle_now: Vector3 = battle.actor.turret.muzzle.global_position
		var dir_now: Vector3 = battle.actor.turret.barrel_direction()
		var to_now: Vector3 = point - muzzle_now
		print("[aim] barrel NOT converged miss=%.4f m" % [(to_now - dir_now*to_now.dot(dir_now)).length()])
	await frames(240)
	print("[aim] camera=",battle.actor.cam_rig.cam.global_position," intent=",battle.actor.cam_rig.intent_point()," muzzle=",battle.actor.turret.muzzle.global_position," dir=",battle.actor.turret.barrel_direction())
func run(flow: AppFlow) -> void:
	app = flow
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot-dir" and i+1 < args.size(): shot_dir = args[i+1]
	if shot_dir.is_empty(): shot_dir = ProjectSettings.globalize_path("user://tests/player_flow034_%d"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(shot_dir)
	print("PLAYER_FLOW_EVIDENCE="+shot_dir)
	check(OS.has_feature("release") and DisplayServer.get_name()!="headless","actual rendered Release player-flow verification")
	get_tree().create_timer(2000,true,false,true).timeout.connect(func() -> void: print("PLAYER_FLOW_TIMEOUT"); get_tree().quit(2))
	await frames(30)
	await capture("00_garage_main_menu")
	await click(app.garage.challenge_button)
	check(is_instance_valid(app.garage.challenge_selection),"normal garage challenge button opens task selection")
	await capture("01_challenge_rules")
	await click(app.garage.challenge_selection.start_button); await frames(195)
	var battle := app.training as ChallengeRange
	await ready_challenge(battle)
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
		var close_rect := battle.battle_ui.overlay.replay_close_button.get_global_rect()
		check(Rect2(Vector2.ZERO,Vector2(get_tree().root.size)).encloses(close_rect),"visible replay close button is fully inside actual game window")
		await capture("05_real_shot_replay")
		await tap(KEY_V)
		await click(battle.return_button); await frames(10)
	else:
		await leave_through_menu(battle)
	check(is_instance_valid(app.garage),"normal return restores garage")
	await click(app.garage.challenge_button)
	check(app.garage.challenge_selection.best_label.text.contains("星"),"task selection displays saved personal best after returning")
	await capture("06_personal_best")
	await choose(app.garage.challenge_selection.task_choice,1)
	await click(app.garage.challenge_selection.start_button); await frames(195)
	battle = app.training as ChallengeRange
	await ready_challenge(battle)
	check(battle.challenge_id=="hold_ground" and battle.director.phase=="playing" and battle.map_definition.id=="industrial_edge_023","normal selector enters industrial finite-wave defense")
	await capture("07_defense_start")
	var old_attempt := battle.director.attempt_id; var old_life := battle.actor.life_id
	await tap(KEY_R); await frames(195)
	battle = app.training as ChallengeRange
	await ready_challenge(battle)
	check(battle.director.attempt_id!=old_attempt and battle.actor.life_id!=old_life and battle.combat_actors().size()==2,"normal R retry creates one fresh defense attempt and opponent")
	await leave_through_menu(battle)
	await click(app.garage.challenge_button)
	await choose(app.garage.challenge_selection.task_choice,2)
	await choose(app.garage.challenge_selection.level_choice,1)
	await click(app.garage.challenge_selection.start_button); await frames(195)
	battle = app.training as ChallengeRange
	await ready_challenge(battle)
	check(battle.challenge_id=="td_route" and battle.difficulty=="hard" and battle.actor.gunner.rounds_remaining==4,"normal selector enters hard M36 route with its actual four-round loadout")
	await capture("08_m36_route_start")
	await leave_through_menu(battle)
	check(app.profile.snapshot().challenge_bests.size()==1,"quitting other challenges cannot overwrite or invent personal bests")
	if failed>0: finish(); return
	await natural_matches()
	complete = true
	finish()
func finish() -> void:
	check(complete,"normal challenge player flow reached its final step")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	if failed == 0: print("PLAYER_FLOW_CHECKS_PASS")
	get_tree().quit(0 if failed == 0 else 1)

func idle() -> void:
	for frame in 1200:
		await get_tree().process_frame
		if not app._transitioning: return
	check(false,"bounded normal scene transition")

func leave_through_menu(battle: BallisticsRange) -> void:
	if not battle._paused: await tap(KEY_ESCAPE)
	await click(battle.hud._training_btn); await frames(8)
	if is_instance_valid(app.navigation_overlay):
		await click(find_button(app.navigation_overlay,LocalizationService.text("flow_leave_accept")))
	await idle(); await frames(8)
	check(app.garage!=null and app.training==null,"normal live-match confirmation returns to garage")

func ready_challenge(battle: ChallengeRange) -> void:
	if battle==null: return
	for frame in 900:
		if battle._paused: await tap(KEY_ESCAPE)
		if battle.director.phase=="playing" and not battle._paused: await frames(25); return
		await get_tree().physics_frame
	check(false,"challenge countdown and focus pause resolve through ordinary input")

func natural_matches() -> void:
	# The challenge already proves normal keyboard driving, mouse aiming and
	# firing. These matches verify the full ordinary garage/result/save lifecycle.
	for map_index in 2:
		if is_instance_valid(app.garage.challenge_selection): await click(app.garage.challenge_selection.close_button)
		await frames(8)
		await choose(app.garage.vehicle_choice,1)
		await choose(app.garage.preparation.mode_choice,1)
		if not app.garage.preparation.details.visible: await click(app.garage.preparation.settings_button)
		await choose(app.garage.preparation.map_choice,map_index)
		# WT-040-R1: report the lookup itself, so a null or hidden start button is named instead of only failing
		# the generic visibility assertion.
		var start_button := find_button(app.garage,LocalizationService.text("ui_56b6b54bb00a"))
		print("[garage] map_index=",map_index," start_button_valid=",is_instance_valid(start_button),
			" visible=",is_instance_valid(start_button) and start_button.is_visible_in_tree(),
			" settings_visible=",app.garage.preparation.details.visible,
			" map_choice_index=",app.garage.preparation.map_choice.selected)
		await click(start_button); await idle()
		var battle:=app.training as TeamRange
		check(battle!=null and battle.team_ready,"normal garage button enters complete map "+str(map_index))
		if battle==null: return
		var token:=app.match_token
		var last_print:=0.0
		var captured:=false
		for tick in 36500:
			await get_tree().physics_frame
			if battle._paused: await tap(KEY_ESCAPE)
			if battle.director.state.phase=="finished": break
			if battle.actor.state.destroyed: battle.request_respawn()
			if battle.director.state.elapsed>=last_print:
				print("[RC natural match] map=",map_index," seconds=",battle.director.state.elapsed," tickets=",battle.director.state.tickets)
				last_print+=60
			if not captured and battle.director.state.elapsed>30:
				await capture("09_battle_"+str(map_index)); captured=true
		var result: Dictionary=battle.director.state.result.duplicate(true)
		check(battle.director.state.phase=="finished" and result.get("reason","") in ["tickets","time_limit"],"actual rules naturally finish map "+str(map_index))
		if result.is_empty(): return
		var saved:=app.profile.snapshot()
		check(saved.receipts.has(token) and saved.pending.is_empty() and app.pending_reward.is_empty(),"natural match saves one actual receipt "+str(map_index))
		check(ProfileStore.new(app.profile._path).snapshot()==saved,"fresh profile reader restores settled match from disk "+str(map_index))
		await capture("10_settled_"+str(map_index))
		await click(battle.restart_button); await idle()
		check(not is_instance_valid(battle) and app.training is TeamRange,"result button starts fresh match "+str(map_index))
		await leave_through_menu(app.training)
		check(app.garage!=null and app.training==null,"normal exit returns to usable garage "+str(map_index))
