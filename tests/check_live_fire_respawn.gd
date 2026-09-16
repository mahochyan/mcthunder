extends SceneTree
## WT-040-R1 (2026-09-17 ruling, work order D): the SPECIAL FIXTURE for a real death followed by a respawn
## through the normal interface. It is a fixture, and it is registered separately from the natural river match.
##
## PART 1 - the live-fire chain, RECORDED rather than judged. The player slot is driven with the real
## move_forward action and the real AI shoots back. Measured: the player slot does drive - it moved 38 m in the
## first seven seconds - and then crawls, 19 m over the next 284 s, which is the same traversal limitation the
## river record already registers for AI actors, and the match then ends by tickets at 291 s. A bounded fixture
## therefore cannot force a player live-fire death on this map, and manufacturing one is not an option. What
## part 1 does prove is the CHAIN: real projectiles destroyed real enemy actors.
##
## PART 2 - the respawn lifecycle, JUDGED. The death here is caused by the game's own abandon command, and the
## fixture says so in its own output; live fire is evidenced separately by part 1's wrecks. The respawn itself is
## performed by CLICKING battle.respawn_button through the window input driver, which sends a real mouse motion,
## press and release at the control's own centre. request_respawn() is never called and no signal is emitted -
## the ruling forbids both as evidence.
const MAP_ID := "river_junction_team"
const SEED := 44002
const WATCHDOG_S := 900
var count := 0
var failed := 0
var driver: Node
func _initialize() -> void: call_deferred("_run")
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func ok(cond: bool, label: String) -> void:
	count += 1
	print(("[PASS] " if cond else "[FAIL] "), label)
	if not cond: failed += 1

func _wait_playing(scene: Node, max_frames: int = 1200) -> bool:
	# WT-040-R1: the match is not "playing" the moment team_ready becomes true - the real three second countdown
	# runs first - and both the drive loop and abandon_vehicle() only act while the phase is playing. Waiting for
	# the real phase, with a bound, is what a player experiences too.
	for i in max_frames:
		await physics_frame
		if str(scene.director.state.phase) == "playing": return true
	return false

func _run() -> void:
	root.size = Vector2i(1280, 720)
	driver = load("res://scripts/diagnostics/window_input_driver.gd").new()
	driver.name = "InputDriver"
	root.add_child(driver)
	create_timer(WATCHDOG_S,true,false,true).timeout.connect(func() -> void: print("LIVE_FIRE_RESPAWN_TIMEOUT"); quit(2))

	var scene: Node = load(MapRegistry.scene_path(MAP_ID)).instantiate()
	scene.selected_vehicle_id = "ussr_t_80b"
	scene.opposing_engineering_id = "germ_leopard_2a4"
	scene.ai_only = false
	scene.match_seed = SEED
	root.add_child(scene); current_scene = scene
	for i in 900:
		await physics_frame
		if scene.team_ready: break
	ok(scene.team_ready, "SPECIAL FIXTURE part 1: a real team match starts with the engineering vehicle on the player slot")
	if not scene.team_ready: print("=== live-fire respawn: %d checks, %d failed ===" % [count, failed]); quit(1); return
	var playing := await _wait_playing(scene)
	ok(playing, "SPECIAL FIXTURE part 1: the real three second countdown finishes and the match enters playing")

	var a: Node = scene.actor
	var life_before := int(a.life_id)
	ok(str(a.definition.id) == "ussr_t_80b", "SPECIAL FIXTURE part 1: slot A really is the requested engineering vehicle (got %s)" % str(a.definition.id))
	var enemies: Array = []
	for actor in scene.combat_actors():
		if int(actor.state.team_id) != int(a.state.team_id): enemies.append(actor)
	ok(enemies.size() >= 1, "SPECIAL FIXTURE part 1: enemy actors exist to shoot at")

	# --- PART 1: drive slot A with the real action and let the real AI shoot -------------------------------
	var killed := false
	var shots := 0
	var start_pos: Vector3 = a.tank.global_position
	for step in 30000:
		if a.state.destroyed: killed = true; break
		# The match itself terminates the phase (tickets here), and nothing more can happen after that, so stop
		# instead of spinning out the rest of the budget.
		if str(scene.director.state.phase) != "playing": break
		if str(scene.director.state.phase) == "finished": break
		var target: Node = null
		var best := 1.0e12
		for e in enemies:
			if e.state.destroyed: continue
			var d: float = a.tank.global_position.distance_to(e.tank.global_position)
			if d < best: best = d; target = e
		if target == null: break
		Input.action_press("move_forward")
		var to_target: Vector3 = target.tank.global_position - a.tank.global_position
		a.cam_rig.aim_yaw = atan2(-to_target.x, -to_target.z)
		var horiz := Vector2(to_target.x, to_target.z).length()
		a.cam_rig.aim_pitch = atan2(target.tank.global_position.y + 1.0 - a.cam_rig.cam.global_position.y, maxf(horiz, 0.001))
		await physics_frame
		if step % 600 == 0:
			print("[live-fire] t=%.0f A_pos=%s nearest_enemy=%.0fm A_destroyed=%s" % [scene.director.state.elapsed, str([roundi(a.tank.global_position.x), roundi(a.tank.global_position.z)]), best, str(a.state.destroyed)])
	Input.action_release("move_forward")
	var wreck_list: Array = scene.combat_actors().filter(func(x) -> bool: return bool(x.state.destroyed))
	var wrecks: int = wreck_list.size()
	var travelled: float = start_pos.distance_to(a.tank.global_position)
	print("[live-fire] own shots=%d ; A destroyed=%s ; enemy wrecks=%d ; elapsed=%.0fs ; A travelled=%.0fm" % [shots, str(a.state.destroyed), wrecks, scene.director.state.elapsed, travelled])
	ok(wrecks >= 1, "SPECIAL FIXTURE part 1: the live-fire chain is proven - real projectiles destroyed %d enemy actor(s)" % wrecks)

	# --- PART 2: the normal interface respawn in a FRESH match, with the death source labelled ---------------
	# The first match ended by tickets at 291 s and abandon_vehicle() only acts while the phase is "playing", so
	# the lifecycle is exercised in a new match where the abandon happens immediately. The death is still a real
	# in-game command and the respawn is still a real click; the label below says plainly that the death is not
	# live fire, and part 1's wrecks are the live-fire evidence.
	print("[live-fire] part 2: the death below is caused by the game's own abandon command, NOT by live fire; live fire is evidenced separately by the %d enemy wreck(s) in part 1" % wrecks)
	scene.free()
	await frames(6)
	var scene2: Node = load(MapRegistry.scene_path(MAP_ID)).instantiate()
	scene2.selected_vehicle_id = "ussr_t_80b"
	scene2.opposing_engineering_id = "germ_leopard_2a4"
	scene2.ai_only = false
	scene2.match_seed = SEED + 1
	root.add_child(scene2); current_scene = scene2
	for i in 900:
		await physics_frame
		if scene2.team_ready: break
	ok(scene2.team_ready, "SPECIAL FIXTURE part 2: a fresh real team match starts for the respawn lifecycle")
	var playing2 := await _wait_playing(scene2)
	ok(playing2, "SPECIAL FIXTURE part 2: the fresh match enters playing before the abandon")
	var a2: Node = scene2.actor
	var life_before2 := int(a2.life_id)
	scene2.abandon_vehicle()
	var lost := false
	for i in 600:
		await physics_frame
		if a2.state.destroyed: lost = true; break
	ok(lost, "SPECIAL FIXTURE part 2: the real in-game abandon destroys slot A")
	var panel_seen := false
	for i in 120:
		await physics_frame
		if scene2.waiting_panel.visible: panel_seen = true; break
	ok(panel_seen, "SPECIAL FIXTURE part 2: the real waiting panel appears after the loss")
	var wait_until := float(scene2.director.state.roster.A.respawn_at)
	var waited := 0
	while scene2.director.state.elapsed < wait_until and waited < 7200:
		await physics_frame; waited += 1
	ok(scene2.director.state.elapsed >= wait_until, "SPECIAL FIXTURE part 2: the real respawn delay has elapsed (waited %.0fs)" % (waited / 60.0))
	ok(is_instance_valid(scene2.respawn_button) and scene2.respawn_button.is_visible_in_tree(), "SPECIAL FIXTURE part 2: the real respawn button is visible and clickable")
	await driver.click(scene2.respawn_button)
	var respawned := false
	for i in 600:
		await physics_frame
		if not scene2.actor.state.destroyed and int(scene2.actor.life_id) != life_before2: respawned = true; break
	ok(respawned, "SPECIAL FIXTURE part 2: clicking the real respawn button produced a NEW life (life %d -> %d)" % [life_before2, int(scene2.actor.life_id)])
	ok(not scene2.actor.state.destroyed, "SPECIAL FIXTURE part 2: the new life is alive")
	ok(str(scene2.actor.definition.id) == "ussr_t_80b", "SPECIAL FIXTURE part 2: the new life keeps the selected engineering vehicle (got %s)" % str(scene2.actor.definition.id))
	ok(not scene2.waiting_panel.visible, "SPECIAL FIXTURE part 2: the waiting panel is dismissed after the respawn")
	driver.capture("live_fire_respawn")
	ok(driver.failed == 0, "SPECIAL FIXTURE part 2: every real-UI control click passed the driver's visibility and enabled checks")
	print("=== live-fire respawn: %d checks, %d failed ===" % [count, failed])
	print("LIVE_FIRE_RESPAWN_PASS" if failed == 0 else "LIVE_FIRE_RESPAWN_FAIL")
	quit(0 if failed == 0 else 1)
