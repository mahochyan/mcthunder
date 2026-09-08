extends SceneTree
var count := 0
var failed := 0
var scene: VillageRange
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	scene = load("res://scenes/maps/map_hill_village.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(190)
	check(scene.team_ready and scene.combat_actors().size() == 8 and scene.nav.valid,"actual village scene starts the same eight-vehicle match")
	var space := scene.get_world_3d().direct_space_state
	var bake := NavigationBakePipeline.build(scene.definition,space,scene.terrain.get_rid())
	check(bake.ok,"final roof and decoration world preserves the graybox road envelope")
	check(scene.battle_ui.overlay.minimap.world_rect == scene.definition.bounds and scene.battle_ui.overlay.minimap.obstacles.size() == scene.definition.obstacles.size(),"HUD reads authored village geometry instead of graybox coordinates")
	# Natural seven-AI match: player stays at their genuine spawn, no combat state edits.
	var starts := {}
	for actor in scene.combat_actors(): starts[actor.entity_id] = actor.tank.global_position
	var approached := {}
	var fired := {}
	var finite := true
	for sample in 24:
		await frames(300)
		for actor in scene.combat_actors():
			var p: Vector3 = actor.tank.global_position
			finite = finite and p.is_finite() and scene.definition.bounds.has_point(Vector2(p.x,p.z))
			if absf(p.z)<45: approached[actor.entity_id] = true
			if actor.gunner.shots_fired>0: fired[actor.entity_id] = true
		if sample%3 == 0:
			var summary := {}
			for actor in scene.combat_actors():
				summary[actor.entity_id] = {"position":actor.tank.global_position,"dead":actor.state.destroyed,"phase":actor.controller.phase if actor.controller is AITankController else "player","drive":actor.controller.driver.phase if actor.controller is AITankController else "player"}
			print("[natural battle %.1fs] %s"%[scene.director.state.elapsed,summary])
	check(finite,"120 seconds of normal eight-actor physics stays finite and within visible bounds")
	check(approached.size()==7,"all seven autonomous actors leave spawn and reach central approaches: "+str(approached.keys()))
	check(fired.size()>=2,"normal AI perception and projectile execution produce combat on the map: "+str(fired.keys()))
	# Freeze only for explicit collision/projectile fixtures after the untouched match run.
	scene.director.set_physics_process(false)
	for actor in scene.combat_actors(): actor.set_physics_process(false)
	await collision_cases(space)
	scene.free()
	var app := AppFlow.new()
	root.add_child(app)
	current_scene = app
	await frames()
	app.enter_laboratory("team")
	await frames(8)
	var original_id: int = app.training.get_round_id()
	check(app.training is VillageRange,"AppFlow normal team selection resolves the bundled village scene")
	app.restart_match()
	await frames(8)
	check(app.training is VillageRange and app.training.get_round_id()!=original_id,"restart preserves selected village and creates a fresh match identity")
	app.return_to_garage()
	await frames(6)
	check(app.training == null and app.garage != null,"village scene cleanup returns to the ordinary garage")
	app.free()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("VILLAGE_BATTLE_CHECKS_PASS" if failed == 0 else "VILLAGE_BATTLE_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)

func collision_cases(space: PhysicsDirectSpaceState3D) -> void:
	var manager := ProjectileManager.new()
	scene.add_child(manager)
	manager.set_physics_process(false)
	var shot := 0
	for id in ["spawn_screen_1","house_1_1","village_house_1","cover_1","fence_1","boundary_x160","roof"]:
		var obstacle := scene.get_node(NodePath("house_1_1" if id == "roof" else id)) as StaticBody3D
		var from := obstacle.position+Vector3(0,0,15)
		if id == "roof": from.y += 4.5
		var velocity := Vector3(0,0,-300)
		if id.begins_with("boundary_x") or id.begins_with("fence"):
			from = obstacle.position+Vector3(-15,0,0)
			velocity = Vector3(300,0,0)
		shot += 1
		var spec := {"round_id":1,"shooter_id":"fixture","shooter_life_id":1,"shooter_team_id":1,"shot_id":shot,"shell_id":"map_fixture","armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,500)]),"position_world":from,"velocity_world":velocity,"gravity_world":Vector3.ZERO,"max_age_s":2.0,"max_distance_m":90.0}
		var accepted := manager.try_spawn(spec)
		var projectile := manager.get_projectile_state(accepted.projectile_id)
		manager.advance_projectile(projectile,0.2,[],space)
		var ray := PhysicsRayQueryParameters3D.create(from,from+velocity*0.2,GameConfig.LAYER_WORLD)
		var hit := space.intersect_ray(ray)
		check(projectile.terminal_reason == "impact_world" and not hit.is_empty() and hit.collider == obstacle,"T018-H02 actual projectile stops at visible "+id)
	var grass := scene.get_node("LowGrass_028m_NoCover") as MeshInstance3D
	check(grass != null and grass.find_children("*","CollisionShape3D",true,false).is_empty() and WorldCollisionRules.classify(str(grass.get_meta("world_kind"))).blocks_los == false,"short original grass has no physical or AI-only obstruction")
	for side in [-1,1]:
		var a := Vector3(side*72,2.4,70)
		var b := Vector3(side*72,2.4,-70)
		var ray := PhysicsRayQueryParameters3D.create(a,b,GameConfig.LAYER_WORLD)
		check(space.intersect_ray(ray).is_empty(),"T018-H03 measured 140m clear main-route gun line side "+str(side))
	print("[sightlines] two actual 140m clear main-route lines")
	for sign in [-1,1]:
		var a := Vector3(-120,VillageDefinition.height(-120,0)+2.4,0)
		var b := Vector3(-72,2.4,sign*80)
		var ray := PhysicsRayQueryParameters3D.create(a,b,GameConfig.LAYER_WORLD)
		print("[hill sightline] distance=",a.distance_to(b)," endpoint=",b)
		check(space.intersect_ray(ray).is_empty(),"elevated western hill has a measured clear line to main-road approach "+str(sign))
	manager.free()
