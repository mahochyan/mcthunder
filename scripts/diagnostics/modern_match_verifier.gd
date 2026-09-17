extends "res://scripts/diagnostics/window_input_driver.gd"
## Normal garage and keyboard/mouse pilot, on the unmodified river match.
## No pose, health, ammo, cooldown, AI-controller or match-rule writes.
const ID := "ussr_t_80b"
var held := {KEY_W:false,KEY_S:false,KEY_A:false,KEY_D:false}
var navigator := DriveNavigator.new()
var route: Array = []
var waypoint := 0
var route_life := -1
var goal_id := ""
var travelled := 0.0
var last_position := Vector3.ZERO
var telemetry: Array = []
var shot_evidence: Array = []
var wanted: Dictionary = {}

func idle() -> void:
	for i in 1200:
		await get_tree().process_frame
		if not app._transitioning: return
	check(false,"bounded modern scene transition")

func hold(next: Dictionary) -> void:
	for code in held:
		var down: bool = next.get(code,false)
		if held[code] != down:
			key(code,down)
			held[code] = down

func type_count(spin: SpinBox, value: int) -> void:
	await click(spin.get_line_edit())
	var select := InputEventKey.new()
	select.keycode = KEY_A; select.physical_keycode = KEY_A; select.ctrl_pressed = true; select.pressed = true
	Input.parse_input_event(select)
	await frames(2)
	select = select.duplicate(); select.pressed = false; Input.parse_input_event(select)
	for character in str(value):
		var event := InputEventKey.new()
		event.keycode = character.unicode_at(0); event.unicode = character.unicode_at(0); event.pressed = true
		Input.parse_input_event(event)
		await frames(1)
		event = event.duplicate(); event.pressed = false; Input.parse_input_event(event)
	await tap(KEY_ENTER)
	check(int(spin.value) == value,"normal keyboard edits ammunition count")

func point_camera(actor: VehicleActor, point: Vector3) -> void:
	var delta := point-actor.cam_rig.cam.global_position
	var yaw := atan2(-delta.x,-delta.z)
	var pitch := atan2(delta.y,Vector2(delta.x,delta.z).length())
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-wrapf(yaw-actor.cam_rig.aim_yaw,-PI,PI)/GameConfig.MOUSE_SENS,-(pitch-actor.cam_rig.aim_pitch)/GameConfig.MOUSE_SENS)
	Input.parse_input_event(motion)

func pilot(battle: RiverTeamRange, tick: int) -> void:
	var actor := battle.actor
	if actor.life_id != route_life:
		route.clear(); waypoint = 0; goal_id = ""
		route_life = actor.life_id; last_position = actor.tank.global_position
	var displacement := actor.tank.global_position.distance_to(last_position)
	if displacement < 5: travelled += displacement
	last_position = actor.tank.global_position
	var target: VehicleActor
	for enemy in battle.combat_actors():
		if enemy.state.team_id == actor.state.team_id or enemy.state.destroyed: continue
		if battle.battle_ui.intel.visible_enemy(enemy.entity_id,enemy.life_id):
			if target == null or enemy.tank.global_position.distance_to(last_position) < target.tank.global_position.distance_to(last_position): target = enemy
	if target != null:
		point_camera(actor,target.turret.global_position+Vector3.UP*.35)
		# Read the same world/armor preview as the player's barrel marker. The
		# actual launch still re-queries and runs full ballistic/damage rules.
		var contact := ExternalContactSelector.select_contact(actor.gunner._aim_query_cache)
		if tick%30 == 0 and actor.gunner.cooldown_left <= 0 and contact.get("status") == "vehicle" and contact.get("event",{}).get("entity_id") == target.entity_id:
			mouse(MOUSE_BUTTON_LEFT,true)
			await frames(1)
			mouse(MOUSE_BUTTON_LEFT,false)
		if actor.tank.forward_speed > .3: hold({KEY_S:true})
		else: hold({})
		return
	var chosen: Dictionary = battle.director.state.objectives.snapshot()[0]
	for row in battle.director.state.objectives.snapshot():
		if row.owner != actor.state.team_id:
			chosen = row
			break
	if goal_id != chosen.id or route.is_empty():
		var goal: Vector3 = battle._snap_to_graph(chosen.center)
		var planned := navigator.request_path(last_position,goal,actor.definition.drive_collision_size.x)
		goal_id = chosen.id; waypoint = 0
		route = Array(planned.points) if planned.ok else []
		print("MODERN_ROUTE life=",route_life," goal=",goal_id," ok=",planned.ok," points=",route.size())
	while waypoint < route.size() and ((route[waypoint]-last_position)*Vector3(1,0,1)).length() < 7: waypoint += 1
	if waypoint >= route.size(): hold({}); return
	var offset: Vector3 = (route[waypoint]-last_position)*Vector3(1,0,1)
	var difference := wrapf(atan2(-offset.x,-offset.z)-actor.tank.global_rotation.y,-PI,PI)
	var speed := actor.tank.forward_speed
	hold({KEY_W:absf(difference)<.35 and speed<12,KEY_S:absf(difference)>.55 and speed>1.0,KEY_A:difference>.08,KEY_D:difference<-.08})
	point_camera(actor,route[waypoint]+Vector3.UP*2)

func run(flow: AppFlow) -> void:
	app = flow
	if DisplayServer.get_name() == "headless":
		check(false,"modern player flow requires a real rendered window")
		finish(); return
	get_tree().create_timer(1500,true,false,true).timeout.connect(func() -> void: print("MODERN_MATCH_TIMEOUT"); hold({}); get_tree().quit(2))
	shot_dir = ProjectSettings.globalize_path("user://tests/modern_match_shots")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	print("MODERN_MATCH_RUNTIME release=",OS.has_feature("release")," evidence=",shot_dir)
	await idle(); await frames(10)
	if OS.get_cmdline_user_args().has("--resume-proof"):
		var saved := app.profile.snapshot()
		check(saved.garage.selected_vehicle_id == ID and app.garage.selected_vehicle_id() == ID,"fresh process restores selected modern vehicle")
		var total := 0
		for amount in saved.garage.loadouts.get(ID,{}).get("counts",{}).values(): total += int(amount)
		check(total == 18 and saved.pending.is_empty(),"fresh process restores eighteen-round loadout without pending reward")
		await capture("06_fresh_process")
		finish(); return
	var g := app.garage
	var index := -1
	for i in g.vehicle_choice.item_count:
		if g.vehicle_choice.get_item_metadata(i) == ID: index = i
	check(index >= 0,"modern player vehicle is present in real garage")
	if index < 0: finish(); return
	# WT-UI-004: bring the card on screen first - the collection row scrolls horizontally at 1280.
	if g.frontend.collection_scroll != null:
		g.frontend.collection_scroll.ensure_control_visible(g.frontend.cards[index]); await get_tree().process_frame
	await click(g.frontend.cards[index]); await click(g.frontend.tabs[1])
	check(g.selected_vehicle_id() == ID,"real card selects T-80B")
	for shell_id in g.preparation.shell_spins:
		await type_count(g.preparation.shell_spins[shell_id],12 if shell_id.ends_with("_shell") else 6)
	if failed > 0: finish(); return
	wanted = g.preparation.loadouts[ID].duplicate(true)
	await capture("00_prepared")
	await click(g.frontend.deploy); await idle()
	var battle := app.training as RiverTeamRange
	check(battle != null and battle.team_ready,"real deployment enters river team match")
	if battle == null: finish(); return
	check(battle.actor.definition.id == ID and battle.actor.gunner.rounds_remaining == 18,"actual player spawn consumes edited eighteen-round loadout")
	check(ProfileStore.new(app.profile._path).snapshot().garage.loadouts[ID] == wanted,"normal deployment saves exact edited loadout to disk")
	check(navigator.configure(battle.navigation_graph()).ok,"pilot reads actual river road graph")
	var match_id := battle.director.state.match_id
	await capture("01_deployed")
	for tick in 39000:
		await get_tree().physics_frame
		if battle.director.state.phase == "finished": break
		if battle._paused: await tap(KEY_ESCAPE)
		if battle.director.state.phase != "playing": continue
		if battle.actor.state.destroyed:
			hold({})
			if battle.respawn_button.is_visible_in_tree() and not battle.respawn_button.disabled:
				await capture("02_waiting")
				await click(battle.respawn_button)
			continue
		if tick%6 == 0: await pilot(battle,tick)
		if tick%600 == 0:
			var row := {"seconds":battle.director.state.elapsed,"life":battle.actor.life_id,"position":str(battle.actor.tank.global_position),"distance":travelled,"shots":battle.actor.gunner.shots_fired,"tickets":battle.director.state.tickets.duplicate()}
			telemetry.append(row); print("MODERN_PLAYER ",row)
			if tick == 600: await capture("03_driving")
	hold({}); mouse(MOUSE_BUTTON_LEFT,false)
	var launches := 0; var contacts := 0; var damage := 0
	for i in battle.projectiles.shot_records.count():
		var record: Dictionary = battle.projectiles.shot_records.get_record(i)
		if record.identity.shooter_id != "A": continue
		launches += 1; contacts += record.contacts.size(); damage += record.damage.size()
		shot_evidence.append(record)
	check(travelled > 100,"normal keyboard player advances more than 100 metres")
	check(launches > 0 and contacts > 0 and damage > 0,"normal player fire produces real contacts and damage")
	check(battle.director.state.phase == "finished" and battle.director.state.result.get("reason") in ["tickets","time_limit"],"unchanged river rules naturally finish the player's match")
	var result := battle.director.state.result.duplicate(true)
	check(app.pending_reward.is_empty() and app.profile.snapshot().pending.is_empty(),"engineering result settles without blocked reward receipt")
	await capture("04_result")
	var file := FileAccess.open(shot_dir.path_join("events.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"kind":"normal keyboard/mouse river player pilot","result":result,"events":battle.director.state.events,"telemetry":telemetry,"player_shots":shot_evidence},"\t")); file.close()
	check(file != null,"natural player flow event evidence saved")
	if battle.director.state.phase == "finished":
		await click(battle.restart_button); await idle()
		battle = app.training as RiverTeamRange
		check(battle != null and battle.director.state.match_id != match_id and battle.actor.definition.id == ID and battle.actor.gunner.rounds_remaining == 18,"result button starts next river match with selected vehicle and saved loadout")
		await capture("05_next_match")
		if not battle._paused: await tap(KEY_ESCAPE)
		await click(battle.hud._training_btn)
		if is_instance_valid(app.navigation_overlay):
			await click(find_button(app.navigation_overlay,LocalizationService.text("flow_leave_accept")))
		await idle()
		check(app.garage != null and app.training == null and app.profile.snapshot().pending.is_empty(),"normal leave returns to saved garage before process restart")
	finish()

func finish() -> void:
	hold({})
	print("=== result: %d checks, %d failed ==="%[checks,failed])
	print("MODERN_MATCH_PASS" if failed == 0 else "MODERN_MATCH_FAIL")
	get_tree().quit(0 if failed == 0 else 1)
