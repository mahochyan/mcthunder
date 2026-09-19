extends Node
## Explicit encounter fixture, NOT a natural river match: flat physical ground,
## authored initial encounter positions, parked supporting slots and a scripted
## enemy gun operator. Production weapons, rounds, armor, damage, tickets and
## respawn delay remain unchanged. No teleport, abandonment or injected damage.
class Encounter extends RiverTeamRange:
	func _build_world() -> void:
		TerrainFixtures.box(self,Vector3(0,-.5,0),Vector3(2400,1,2000))
		var light := DirectionalLight3D.new(); light.rotation_degrees=Vector3(-50,-30,0); add_child(light)
	func spawn_candidates(team: int) -> Array[Transform3D]:
		var poses := super.spawn_candidates(team)
		for i in poses.size(): poses[i].origin.y=.5
		poses.push_front(Transform3D(Basis.IDENTITY if team==1 else Basis(Vector3.UP,PI/2),Vector3(-350 if team==1 else -320,.5,720)))
		return poses
class EnemyOperator extends Node:
	var cam_rig: CameraRig
	var gunner: Gunner
	var target: VehicleActor
	var layout: VehicleLayoutDefinition
	func is_local_controller() -> bool: return false
	func poll() -> VehicleCommand:
		var cmd := VehicleCommand.new()
		if not is_instance_valid(target) or target.state.destroyed: return cmd
		# The explicit side-fire fixture targets occupied turret seats first.
		# This is a scripted operator, not evidence of natural AI target choice.
		var seats: Array=layout.crew_stations.duplicate()
		seats.sort_custom(func(a: CrewStationDefinition,b: CrewStationDefinition) -> bool: return a.part_id=="turret" and b.part_id!="turret")
		for station in seats:
			# WT-EXPANSION-02 (CD16-T04 regression): this read crew_states by STATION id. CD08-T02 then separated the
			# person identity from the station and the role (crew_states is keyed by PERSON id, with station_roles and
			# crew_assignments as the bridge), so every station lookup returned empty, the loop continued past every
			# seat, fire_requested was never set and the scripted enemy never fired once - measured as shots=0 with
			# query_events=[] while the same case passed on 2026-09-17. Resolved through the SAME production mapping
			# DamageResolver uses (station -> role -> person, damage_resolver.gd:74-80).
			var station_role := str(target.state.station_roles.get(station.id,""))
			var person := str(target.state.crew_assignments.get(station_role,""))
			if person.is_empty() or not target.state.crew_states.get(person,{}).get("alive",false): continue
			cmd.has_aim_point=true
			cmd.aim_world_point=DamageTrainingLayout.part_node(target,station.part_id).global_transform*station.local_box_transform.origin
			var aim: Vector3=(cmd.aim_world_point-gunner.turret.muzzle.global_position).normalized()
			cmd.fire_requested=gunner.turret.barrel_direction().dot(aim)>cos(deg_to_rad(.25))
			break
		return cmd
var checks := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
	await get_tree().process_frame
func resume_if_paused(scene: RiverTeamRange) -> void:
	if not scene._paused: return
	print("LIVE_ROUND resume focus pause through Escape")
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode=KEY_ESCAPE; event.physical_keycode=KEY_ESCAPE; event.pressed=down
		Input.parse_input_event(event); await get_tree().process_frame
func run(flow: AppFlow) -> void:
	get_tree().create_timer(180,true,false,true).timeout.connect(func() -> void: print("PLAYER_LIVE_ROUND_TIMEOUT"); get_tree().quit(2))
	var output := "user://tests/modern_live_round/run_%d" % Time.get_unix_time_from_system()
	print("LIVE_ROUND_EVIDENCE=",output)
	print("MODERN_LIFE_RUNTIME release=",OS.has_feature("release")," fixture=flat encounter / scripted enemy operator")
	DirAccess.make_dir_recursive_absolute(output)
	var service := GarageService.new()
	var id := "ussr_t_80b"
	var wanted := service.default_loadout(id)
	for shell in wanted.counts: wanted.counts[shell]=4
	# WT-EXPANSION-02 (CD16-T04 expectation migration): the new-life assertion below carried a literal 8, which is four
	# rounds for each of TWO shells. CD07 then delivered the third round, so this fixture edits twelve and the literal
	# went stale exactly like the modern-match verifier's 18. Derived from the fixture's own edit, so it cannot go stale.
	var wanted_total := 0
	for shell in wanted.counts: wanted_total += int(wanted.counts[shell])
	var configured := MatchConfig.build({"mode":"engineering","selected_vehicle_id":id,"map":"river_junction_team","difficulty":"normal","lineup":[id],"loadouts":{id:wanted}},service,[])
	check(configured.ok,"fixture validates actual modern loadout")
	if not configured.ok: get_tree().quit(1); return
	var scene := Encounter.new(); scene.selected_vehicle_id=id; scene.opposing_engineering_id="germ_leopard_2a4"; scene.prepared_match=configured.config
	flow.ui_layer.visible=false; flow.training=scene; flow.add_child(scene)
	check(scene.team_ready,"encounter uses the real team director and modern actors")
	if not scene.team_ready: get_tree().quit(1); return
	var victim := scene.actor
	var initial_life := victim.life_id
	var enemy: VehicleActor=scene.find_actor("B",scene.director.state.roster.B.life_id)
	await frames(195)
	for other in scene.combat_actors():
		if other!=victim: other.set_controller(null)
	var operator := EnemyOperator.new(); enemy.add_child(operator); operator.target=victim; operator.layout=scene.defs.layouts[victim.definition.layout_id]; enemy.set_controller(operator)
	var tickets_before: int=scene.director.state.tickets[1]
	for step in 5400:
		await resume_if_paused(scene)
		if victim.state.destroyed or scene.director.state.phase=="finished": break
		await get_tree().physics_frame
		if step%600==0:
			var aim_cmd := operator.poll()
			var from := enemy.turret.muzzle.global_position
			var query := ShotQueryService.query({"query_id":"encounter_aim_probe","from_world":from,"to_world":aim_cmd.aim_world_point+(aim_cmd.aim_world_point-from).normalized()*3,"include_modules":true,"include_crew":true},scene.query_snapshots())
			print("LIVE_ROUND elapsed=",scene.director.state.elapsed," shots=",enemy.gunner.shots_fired," crew=",victim.state.alive_crew_count()," victim=",victim.tank.global_position," aim=",aim_cmd.aim_world_point," query_ok=",query.get("ok")," query_events=",query.get("events",[]))
	await frames(4)
	var records: Array=[]
	var attributed_contact := false
	var attributed_damage := false
	for i in scene.projectiles.shot_records.count():
		var record: Dictionary=scene.projectiles.shot_records.get_record(i)
		records.append(record)
		if record.identity.shooter_id!="B": continue
		for hit in record.contacts:
			if hit.get("entity_id")=="A" and hit.get("life_id")==initial_life: attributed_contact=true
		for hit in record.damage:
			if hit.get("entity_id")=="A" and hit.get("life_id")==initial_life: attributed_damage=true
	check(enemy.gunner.shots_fired>0 and attributed_contact and attributed_damage,"enemy actual round records contact and damage on the same player life")
	check(victim.state.destroyed and scene.director.state.roster.A.deaths==1,"that player life dies exactly once from enemy live rounds")
	check(scene.director.state.tickets[1]==tickets_before-TeamMatchState.DEATH_COST,"one death deducts the production ticket cost")
	var evidence := {"fixture":"flat encounter / scripted enemy gun operator / normal combat and respawn rules","initial_life":initial_life,"tickets_before":tickets_before,"tickets_after":scene.director.state.tickets[1],"destroyed":victim.state.destroyed,"shots":records,"events":scene.director.state.events.duplicate(true)}
	if victim.state.destroyed:
		var driver: Node = load("res://scripts/diagnostics/window_input_driver.gd").new(); add_child(driver)
		driver.shot_dir=ProjectSettings.globalize_path(output)
		for i in 660:
			await resume_if_paused(scene)
			if not scene.respawn_button.disabled and scene.respawn_button.is_visible_in_tree(): break
			await get_tree().physics_frame
		check(scene.waiting_panel.visible,"production waiting panel shown after real death")
		if DisplayServer.get_name()!="headless": await driver.capture("waiting")
		await driver.click(scene.respawn_button); await frames(20)
		check(driver.failed==0 and scene.actor.life_id!=initial_life and not scene.actor.state.destroyed,"actual mouse click creates a living new player life")
		check(scene.actor.definition.id==id and scene.actor.gunner.rounds_remaining==wanted_total and scene.actor.gunner.shell.id==wanted.first_shell,"new life preserves chosen model and the edited loadout")
		evidence["new_life"]=scene.actor.life_id; evidence["events"]=scene.director.state.events.duplicate(true)
		if DisplayServer.get_name()!="headless": await driver.capture("respawned")
	var file := FileAccess.open(output+"/evidence.json",FileAccess.WRITE)
	check(file!=null,"same-life event evidence can be written")
	if file!=null: file.store_string(JSON.stringify(evidence,"\t")); file.close()
	scene.free(); flow.training=null; await frames(3)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("PLAYER_LIVE_ROUND_PASS" if failed==0 else "PLAYER_LIVE_ROUND_FAIL")
	get_tree().quit(0 if failed==0 else 1)
