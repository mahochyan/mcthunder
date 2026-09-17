extends SceneTree
## Actual roster, Actor creation and explicit factory rebuilds. Rebuild fixtures
## do not claim a natural death/respawn sequence (covered by the live-round test).
var checks := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func check_actor(scene: RiverTeamRange, actor: VehicleActor, expected: String, label: String) -> void:
	check(actor != null and actor.definition != null,label+": actual Actor exists")
	if actor == null or actor.definition == null: return
	check(actor.definition.id == expected,label+": actual vehicle is "+expected+" (got "+actor.definition.id+")")
	check(actor.gunner.shell.id.begins_with(expected) and actor.definition.layout_id == scene.defs.get_vehicle(expected).layout_id,label+": ammunition and layout belong to the expected side")

func run() -> void:
	root.size = Vector2i(1280,720)
	create_timer(120,true,false,true).timeout.connect(func() -> void: print("MODERN_TEAM_IDENTITY_TIMEOUT"); quit(2))
	for id in VehicleCatalog.ENGINEERING_IDS:
		var opposite := "germ_leopard_2a4" if id == "ussr_t_80b" else "ussr_t_80b"
		var scene := RiverTeamRange.new()
		scene.selected_vehicle_id = id
		scene.opposing_engineering_id = opposite
		scene.ai_only = true
		root.add_child(scene)
		for i in 600:
			await physics_frame
			if scene.team_ready: break
		check(scene.team_ready,str(id)+": registered river match initialises")
		if not scene.team_ready: scene.free(); continue
		var state := scene.director.state
		var rule_hash := state.rule_fingerprint()
		var counts := {1:0,2:0}
		for slot in state.roster:
			var team: int = state.roster[slot].team
			counts[team] += 1
			var expected: String = id if team == state.roster.A.team else opposite
			check_actor(scene,state.actor_for(slot),expected,str(id)+" / "+slot)
		check(counts == {1:4,2:4},str(id)+": actual composition stays registered 4v4")
		# A changed player-side team assignment must use roster membership, never
		# slot-prefix guessing. Only query selection here; restore before rebuild.
		var original_team: int = state.roster.A2.team
		state.roster.A2.team = state.roster.B.team
		check(scene.vehicle_id_for_slot("A2") == opposite,str(id)+": selection follows authoritative team membership")
		state.roster.A2.team = original_team
		for slot in ["A2","B2"]:
			var previous := state.actor_for(slot)
			if previous == null: check(false,"rebuild fixture needs an original Actor"); continue
			var old_life := previous.life_id
			previous.free()
			await frames(2)
			var rebuilt := scene.spawn_slot(slot)
			check(rebuilt != null and state.register_spawn(slot,rebuilt),str(id)+" / "+slot+": explicit factory rebuild registers a new life")
			if rebuilt != null:
				check(rebuilt.life_id != old_life,str(id)+" / "+slot+": rebuild has a distinct life identity")
				check_actor(scene,rebuilt,id if slot == "A2" else opposite,str(id)+" / rebuilt "+slot)
		check(state.rule_fingerprint() == rule_hash,str(id)+": identity handling leaves match rules unchanged")
		scene.free()
		await frames(2)
	print("=== result: %d checks, %d failed ==="%[checks,failed])
	print("MODERN_TEAM_IDENTITY_CHECKS_PASS" if failed == 0 else "MODERN_TEAM_IDENTITY_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
