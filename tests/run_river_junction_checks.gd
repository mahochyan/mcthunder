extends SceneTree
var passed := 0
var failed := 0
var survey: RiverJunctionSurvey
var output := "res://docs/evidence/WT032-river/first-design"

func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	if value: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)

func connected(graph: Dictionary) -> bool:
	var pending: Array=[graph.nodes.keys()[0]]; var visited := {}
	while not pending.is_empty():
		var id: String=pending.pop_back()
		if visited.has(id): continue
		visited[id]=true
		for edge in graph.edges:
			if edge[0]==id: pending.append(edge[1])
			elif edge[1]==id: pending.append(edge[0])
	return visited.size()==graph.nodes.size()

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output+"/"+label+".png")
	check(result==OK,"capture "+label)

func run() -> void:
	var args := OS.get_cmdline_user_args(); var arg_index := args.find("--shot-dir")
	if arg_index>=0 and arg_index+1<args.size(): output=args[arg_index+1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1600,900)
	for count in [10,16]:
		var config := RiverJunctionDefinition.layout(count)
		check(config.objectives.size()==3,"at most three capture points "+str(count))
		check(not config.combat_admitted,"preview is not battle admission "+str(count))
		for id in config.objectives: check(config.bounds.has_point(RiverJunctionDefinition.OBJECTIVES[id].xz),"objective inside active area "+str(count)+id)
		for team in [1,2]:
			var poses := RiverJunctionDefinition.spawns(count,team)
			check(poses.size()==count,"deployment capacity %d team %d"%[count,team])
			var spacing := true; var inside := true
			for i in poses.size():
				inside=inside and config.bounds.has_point(Vector2(poses[i].origin.x,poses[i].origin.z))
				for j in range(i+1,poses.size()): spacing=spacing and poses[i].origin.distance_to(poses[j].origin)>=17.9
			check(spacing and inside,"nonoverlapping in-bounds deployment %d team %d"%[count,team])
		check(connected(RiverJunctionDefinition.route_graph(count)),"strategic route connectivity "+str(count))
		for crossing in config.crossings: check(connected(RiverJunctionDefinition.route_graph(count,crossing)),"alternate route with crossing closed %d %.0f"%[count,crossing])
	var garage := GarageShell.new(); garage.profile=ProfileStore.new(""); root.add_child(garage)
	for i in 5: await process_frame
	var initial_profile := garage.profile.snapshot()
	garage.frontend.show_page(2)
	for i in 5: await process_frame
	if DisplayServer.get_name()=="headless": garage.frontend.map_survey_button.pressed.emit()
	else:
		var p := garage.frontend.map_survey_button.get_global_rect().get_center()
		for down in [true,false]:
			var event := InputEventMouseButton.new(); event.position=p; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; Input.parse_input_event(event)
			await process_frame
	for i in 5: await process_frame
	survey=garage.get_node_or_null("RiverJunctionSurvey")
	check(survey!=null,"garage training button opens map survey")
	if survey==null: garage.free(); quit(1); return
	if not survey.ready_map: await survey.map_ready
	await physics_frame; await physics_frame
	check(survey.ready_map,"survey world ready")
	print("WORLD ",JSON.stringify(survey.world_builder.stats))
	check(survey.world_builder.stats.bridges==5,"five real bridge decks")
	check(survey.world_builder.stats.buildings>=30 and survey.world_builder.stats.trees>500,"environment sample populated")
	var space := survey.stage.get_world_3d().direct_space_state
	for count in [10,16]:
		var clear := true
		for team in [1,2]:
			for pose in RiverJunctionDefinition.spawns(count,team):
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pose.origin+Vector3.UP*20,pose.origin-Vector3.UP*20,1))
				clear=clear and not hit.is_empty() and absf(hit.position.y-pose.origin.y+.15)<.15
		check(clear,"actual terrain under deployment without building obstruction "+str(count))
		# Crossings must have solid road-height support across the entire riverbed.
		var bridge_support := true
		for x in RiverJunctionDefinition.layout(count).crossings:
			for dz in range(-45,46,5):
				var z := RiverJunctionDefinition.river_z(x)+dz
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,25,z),Vector3(x,-10,z),1))
				bridge_support=bridge_support and not hit.is_empty() and absf(hit.position.y-8)<.1
		check(bridge_support,"physical bridge support "+str(count))
	survey.mode.select(1); survey.mode.item_selected.emit(1)
	check(survey.team_size==10 and survey.objective_buttons.filter(func(b: Button) -> bool: return b.visible).size()==3,"10v10 selector keeps three capture points")
	await capture("layout_10v10")
	survey.mode.select(0); survey.mode.item_selected.emit(0)
	check(survey.team_size==16 and survey.objective_buttons.size()==3 and survey.objective_buttons.all(func(b: Button) -> bool: return b.visible),"16v16 keeps three capture points")
	await capture("overview_16v16")
	survey.objective_buttons[2].pressed.emit(); check(survey.location_label.text.begins_with("C"),"real objective button positions survey camera")
	await capture("riverside_town")
	survey.focus_objective("B"); await capture("freight_depot")
	survey.street_view(); await capture("town_street")
	root.size=Vector2i(1280,720)
	for i in 5: await process_frame
	var screen := Rect2(Vector2.ZERO,Vector2(1280,720))
	check(screen.encloses(survey.atlas.get_global_rect()),"atlas fits default 1280x720 window")
	check(screen.encloses(survey.mode.get_global_rect()),"mode selector fits default window")
	await capture("default_720")
	survey._notification(NOTIFICATION_APPLICATION_FOCUS_OUT); check(not survey.focused,"focus loss stops survey movement")
	check(MapRegistry.IDS==["hill_village","industrial_edge"],"unverified 20/32 player mode not added to battle registry")
	var close := InputEventKey.new(); close.keycode=KEY_ESCAPE; close.pressed=true
	if DisplayServer.get_name()=="headless":
		for child in survey.get_children():
			if child is ModalNavigation: child._input(close)
	else: Input.parse_input_event(close)
	await process_frame; await process_frame
	check(not is_instance_valid(survey),"Escape returns from survey to garage")
	check(garage.profile.snapshot()==initial_profile,"survey does not change saved lineup or progress")
	garage.free(); await process_frame
	print("RESULT river_junction passed=%d failed=%d"%[passed,failed]); quit(0 if failed==0 else 1)
