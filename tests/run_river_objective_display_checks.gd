extends SceneTree
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func run() -> void:
	root.size = Vector2i(1280,720)
	var scene := RiverTeamRange.new()
	root.add_child(scene)
	current_scene = scene
	for i in 5: await process_frame
	check(scene.team_ready,"actual river team scene initializes")
	if not scene.team_ready: quit(1); return
	scene.set_process(false)
	scene.director.set_physics_process(false)
	for actor in scene.combat_actors(): actor.set_physics_process(false)
	var state := scene.director.state
	# Presentation fixture: distinct states expose accidental reuse of legacy A.
	state.objectives.points.A.state.capture_owner = 1
	state.objectives.points.A.state.capture_progress = 1.0
	state.objectives.points.B.state.capture_owner = 2
	state.objectives.points.B.state.capture_progress = -.4
	state.objectives.points.B.state.contested = true
	state.objectives.points.C.state.capture_progress = .25
	var before := state.objectives.snapshot()
	var tickets := state.tickets.duplicate()
	var info := scene.battle_ui.match_info()
	check(info.objectives == before and info.title.contains("A / B / C"),"HUD receives all three authoritative objective snapshots")
	info.objectives[0].owner = 2
	check(state.objectives.snapshot() == before,"presentation snapshot cannot mutate capture authority")
	scene.battle_ui._process(0)
	scene._refresh_capture_markers(state)
	for i in 5: await process_frame
	var hud := scene.battle_ui.overlay
	check(hud.objective_strip.visible and not hud.capture_bar.visible,"three-point strip replaces ambiguous single capture bar")
	check(hud.objective_cards.size() == 3 and hud.objective_cards[0].label.text.contains("友军控制") and hud.objective_cards[1].label.text.contains("争夺中") and hud.objective_cards[2].label.text.contains("25%"),"A ownership, B contested and C progress render independently")
	check(hud.minimap.objectives == before,"minimap uses real A/B/C positions, radius and state")
	check(scene.objective_materials.size() == 3 and scene.capture_ring == null,"river replaces legacy origin ring with exactly three authored zones")
	for row in before:
		var ring := scene.get_node_or_null("CaptureZone_"+row.id) as MeshInstance3D
		var label := scene.get_node_or_null("CaptureLabel_"+row.id) as Label3D
		check(ring != null and label != null and label.position == row.center+Vector3.UP*5,"world label matches authoritative zone "+row.id)
		if ring == null: continue
		var vertices: PackedVector3Array = ring.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var terrain_correct := true
		for p in vertices:
			if absf(p.y-RiverJunctionDefinition.point(Vector2(p.x,p.z),.20).y) > .001: terrain_correct = false
		check(terrain_correct,"capture ring follows river terrain: "+row.id)
	check(scene.objective_materials.B.albedo_color == Color("ffe135") and scene.objective_materials.A.albedo_color == RiverObjectiveHUD.COLORS[1],"world rings show independent owner and contention")
	check(state.objectives.snapshot() == before and state.tickets == tickets,"HUD and world drawing preserve match state and tickets")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions
		for i in 5: await process_frame
		var viewport := Rect2(Vector2.ZERO,Vector2(dimensions))
		check(viewport.encloses(hud.header.get_global_rect()) and viewport.encloses(hud.objective_strip.get_global_rect()) and not hud.header.get_global_rect().intersects(hud.objective_strip.get_global_rect()),"three-point status fits below header: "+str(dimensions))
	var args := OS.get_cmdline_user_args()
	var shot_index := args.find("--shot-dir")
	if shot_index >= 0 and shot_index+1 < args.size() and DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280,720)
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(args[shot_index+1])
		check(root.get_texture().get_image().save_png(args[shot_index+1].path_join("river_three_objectives.png")) == OK,"actual river objective display screenshot saved")
	scene.free()
	current_scene = null
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("RIVER_OBJECTIVE_DISPLAY_CHECKS_PASS" if failed == 0 else "RIVER_OBJECTIVE_DISPLAY_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
