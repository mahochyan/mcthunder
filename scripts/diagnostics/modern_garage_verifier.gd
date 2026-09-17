extends Node
## Integration checks only: not a complete natural match or live-fire death proof.
var checks := 0
var failed := 0
var app: AppFlow
var shot_dir := ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func idle() -> void:
	for i in 1200:
		await get_tree().process_frame
		if not app._transitioning: return
	check(false,"bounded scene transition")
func activate(button: Button) -> void:
	if DisplayServer.get_name()=="headless": button.pressed.emit(); await get_tree().process_frame; return
	for i in 5: await get_tree().process_frame
	check(button.is_visible_in_tree() and not button.disabled,"real mouse target is visible and enabled")
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position=point; Input.parse_input_event(motion)
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.pressed=down
		Input.parse_input_event(event)
		for i in 3: await get_tree().process_frame
func capture(name: String) -> void:
	if shot_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(shot_dir.path_join(name+".png"))==OK,"capture actual modern frontend: "+name)
func run(flow: AppFlow) -> void:
	get_tree().create_timer(180,true,false,true).timeout.connect(func() -> void: print("MODERN_GARAGE_TIMEOUT"); get_tree().quit(2))
	var save_path := flow.profile._path
	var args := OS.get_cmdline_user_args(); var shot_index := args.find("--shot-dir")
	if shot_index>=0 and shot_index+1<args.size(): shot_dir=args[shot_index+1]; DirAccess.make_dir_recursive_absolute(shot_dir)
	if shot_dir.is_empty() and DisplayServer.get_name()!="headless":
		shot_dir=ProjectSettings.globalize_path("user://tests/modern_garage_shots_%d" % Time.get_ticks_usec())
		DirAccess.make_dir_recursive_absolute(shot_dir)
	print("MODERN_GARAGE_RUNTIME release=",OS.has_feature("release")," evidence=",shot_dir)
	app = flow; await idle()
	var points: int = app.profile.snapshot().research_points
	for id in VehicleCatalog.ENGINEERING_IDS:
		var g := app.garage
		var index := -1
		for i in g.vehicle_choice.item_count:
			if g.vehicle_choice.get_item_metadata(i) == id: index = i
		check(index >= 0,"modern vehicle has actual garage entry: "+id)
		if index < 0: continue
		await activate(g.frontend.cards[index])
		var preview_hull: Node = g.preview._part_nodes.hull.get_node_or_null("Bound_hull")
		check(preview_hull!=null and preview_hull.get_meta("model_sha256","")==g.catalog.packages[id].packet.model_binding.model.sha256,"garage shows exact admitted bound model")
		g._view_mode=1; g._apply_preview_mode()
		check(not preview_hull.visible,"armor inspection hides opaque authored shell")
		g._view_mode=0; g._apply_preview_mode()
		var prep := g.preparation
		check(prep.mode()=="engineering" and not prep.research_button.visible,"modern selection uses explicit engineering mode without historical research lookup")
		prep.first_choice.select(1)
		for spin in prep.shell_spins.values(): spin.value = 3
		prep._ammo_changed()
		var wanted: Dictionary = prep.loadouts[id].duplicate(true)
		check(prep.save_settings().ok,"save selected modern vehicle and edited ammunition")
		var reopened := ProfileStore.new(save_path)
		check(reopened.problem.is_empty() and reopened.snapshot().garage.selected_vehicle_id==id and reopened.snapshot().garage.loadouts[id]==wanted,"disk reload retains modern identity, first round and quantities")
		var invalid: Dictionary = reopened.snapshot()
		invalid.garage.loadouts["unregistered_vehicle"] = wanted
		check(not reopened.validate(invalid).ok,"save still rejects unknown vehicle loadouts")
		await capture(id+"_garage")
		await activate(g.frontend.deploy); await idle()
		var battle := app.training as RiverTeamRange
		check(battle!=null and battle.team_ready,"normal deploy routes selected modern vehicle to actual river team scene")
		if battle==null: get_tree().quit(1); return
		check(battle.actor.definition.id==id and battle.actor.gunner.shell.id==wanted.first_shell and battle.actor.gunner.rounds_remaining==6,"first spawn consumes edited loadout, not defaults")
		check(battle.director.state.objectives.points.size()==3 and battle.combat_actors().size()==8,"three capture points and registered 4v4 roster")
		check(battle.opposing_engineering_id!=id and battle.opposing_engineering_id in VehicleCatalog.ENGINEERING_IDS,"opposing modern content explicitly selected")
		await capture(id+"_river")
		var previous_match: int = battle.director.state.match_id
		app.restart_match(); await idle()
		battle = app.training as RiverTeamRange
		check(battle!=null and battle.director.state.match_id!=previous_match and battle.actor.definition.id==id and battle.actor.gunner.rounds_remaining==6,"restart retains river, exact type and edited loadout")
		app.return_to_garage(); await idle()
		check(app.pending_reward.is_empty() and app.profile.snapshot().research_points==points,"engineering departure settles without rewards or blocking pending receipt")
		check(app.garage.selected_vehicle_id()==id,"return keeps modern garage selection")
	# Historical settings remain usable after visiting modern vehicles.
	app.garage.vehicle_choice.select(1); app.garage._select_vehicle(1)
	check(app.garage.preparation.save_settings().ok,"historical setup remains saveable with optional modern loadouts")

	print("=== 结果: %d 项检查, %d 失败 ===" % [checks,failed])
	print("MODERN_GARAGE_CHECKS_PASS" if failed==0 else "MODERN_GARAGE_CHECKS_FAIL")
	get_tree().quit(0 if failed==0 else 1)
