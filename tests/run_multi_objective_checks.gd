extends SceneTree
var passed := 0
var failed := 0
var app: AppFlow
var scene: RiverJunctionRange
var shot_dir := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func frames(count: int = 3) -> void:
	for i in count: await physics_frame
	await process_frame
func capture(label: String) -> void:
	if shot_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	check(root.get_texture().get_image().save_png(shot_dir+"/"+label+".png")==OK,"actual window image "+label)
func throttle(down: bool) -> void:
	if DisplayServer.get_name()=="headless":
		if down: Input.action_press("move_forward")
		else: Input.action_release("move_forward")
	else:
		var event := InputEventKey.new(); event.keycode=KEY_W; event.physical_keycode=KEY_W; event.pressed=down; Input.parse_input_event(event)
func click(button: Button) -> void:
	if DisplayServer.get_name()=="headless": button.pressed.emit(); await process_frame; return
	# A newly shown pause container must finish its layout before choosing the mouse coordinate.
	await frames(3)
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.position=button.get_global_rect().get_center(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; Input.parse_input_event(event)
		await frames(3)

func rule_cases() -> void:
	var layout := RiverJunctionDefinition.capture_definitions()
	var zones := BattleObjectives.new()
	check(zones.configure(layout) and zones.points.keys()==["A","B","C"],"only the three authored objectives are admitted")
	var fourth := layout.duplicate(true); fourth.append({"id":"D","center":Vector3(900,8,0),"radius":20})
	var duplicate := layout.duplicate(true); duplicate[2].id="A"
	var overlap := layout.duplicate(true); overlap[2].center=layout[0].center
	var invalid := layout.duplicate(true); invalid[0].radius=NAN
	for sample in [[],fourth,duplicate,overlap,invalid]:
		check(not zones.configure(sample) and zones.points.size()==3,"invalid layout rejected atomically: "+str(sample.size()))
	var state := TeamMatchState.new(); state.initialize(); state.phase="playing"
	var occupants: Array = []
	for row in layout: occupants.append({"id":"A" if row.id=="A" else "A2","team":1,"position":row.center})
	var tick := zones.step(state,occupants,15)
	TicketLedger.apply_events(state,tick.owned)
	check(state.tickets[2]==291 and tick.player_seconds==15,"three simultaneous captures allocate only three owned seconds per point")
	check(state.events.size()==3 and state.events[2].objective_id=="C","point ownership is journaled with stable point identity")
	var copy := zones.snapshot(); copy[0].owner=2
	check(zones.snapshot()[0].owner==1,"objective snapshots do not expose writable authority")
	var enemies: Array = []
	for row in layout: enemies.append({"id":"B","team":2,"position":row.center})
	var frozen := zones.snapshot()
	tick=zones.step(state,occupants+enemies,2)
	check(tick.owned[1]==6 and tick.player_seconds==0 and zones.snapshot()[0].contested and zones.snapshot()[0].progress==frozen[0].progress,"all contested zones freeze capture while existing owners retain exact drain")
	tick=zones.step(state,enemies,24.5)
	check(is_equal_approx(tick.owned[1],36) and is_equal_approx(tick.owned[2],1.5),"three hostile reversals split old-owner, neutral and new-owner time")
	var split := BattleObjectives.new(); split.configure(layout)
	var split_state := TeamMatchState.new(); split_state.initialize(); split_state.phase="playing"
	for i in 150: TicketLedger.apply_events(split_state,split.step(split_state,occupants,.1).owned)
	check(split_state.tickets[2]==291 and is_zero_approx(split_state.drain_bank[2]),"fractional ticks produce the same aggregate tickets as a large capture tick")
	state.phase="finished"; frozen=zones.snapshot()
	zones.step(state,occupants,100)
	check(zones.snapshot()==frozen,"finished match cannot change point ownership")
	var director := TeamMatchDirector.new(); root.add_child(director); director.set_physics_process(false)
	for capacity in [4,10,16]:
		check(director.begin(capacity,layout) and director.state.roster.size()==capacity*2 and director.state.roster.has("B"+str(capacity)),"unique authoritative slots for "+str(capacity)+" per team")
	var current := director.state
	check(not director.begin(17,layout) and not director.begin(16,fourth) and director.state==current,"invalid capacity or fourth point cannot replace current match")
	current.record("test",{}); current.capture_owner=2; current.tickets[1]=5
	check(current.initialize(10) and current.roster.size()==20 and current.events.is_empty() and current.capture_owner==0 and current.tickets[1]==300,"reinitializing a smaller roster removes old lives, points and ledger state")
	director.free()

func make_vehicle(id: String, position: Vector3) -> VehicleActor:
	var vehicle := VehicleActor.new(); scene.add_child(vehicle)
	var team: int=scene.capture_director.state.roster[id].team
	var result := vehicle.setup(scene.defs,VehicleCatalog.IDS[0],id,team,Transform3D(Basis.IDENTITY,position),4,null)
	if not result.ok: push_error("fixture vehicle setup failed "+id); vehicle.free(); return null
	vehicle.cam_rig.set_process(false); vehicle.cam_rig.set_physics_process(false); vehicle.set_controller(null)
	vehicle.set_physics_process(false)
	scene.capture_director.state.register_spawn(id,vehicle)
	return vehicle

func run() -> void:
	var args := OS.get_cmdline_user_args(); var index := args.find("--shot-dir")
	if index>=0 and index+1<args.size(): shot_dir=args[index+1]
	rule_cases()
	root.size=Vector2i(1280,720)
	app=AppFlow.new(); app.profile=ProfileStore.new(""); root.add_child(app); current_scene=app
	await frames(8)
	app.garage.vehicle_choice.select(1); app.garage._select_vehicle(1); app.garage.frontend.show_page(2); await frames(3)
	var profile_before := app.profile.snapshot()
	await click(app.garage.frontend.map_drive_button); await frames(15)
	scene=app.training as RiverJunctionRange
	check(scene!=null and scene.capture_director!=null,"normal garage route installs production objective director")
	if scene==null: app.free(); quit(1); return
	scene.select_stop(9); await frames(190)
	var director := scene.capture_director
	check(director.state.phase=="playing" and director.state.objectives.snapshot()[2].owner==0,"countdown completes before real vehicle enters a zone")
	throttle(true)
	var ticks := 0
	while ticks<1800 and scene.actor.tank.global_position.z>124:
		await physics_frame; ticks+=1
	throttle(false); await frames(10)
	check(scene.actor.tank.global_position.z<126 and director.state.objectives.snapshot()[2].progress>0,"normal W input drives the real M4 into C and advances capture")
	await capture("01_entering_C")
	scene._pause(); var pause_state := director.state.objectives.snapshot(); var clock_before := director.state.elapsed
	director.advance(15); await frames(8)
	check(director.state.objectives.snapshot()==pause_state and director.state.elapsed==clock_before,"pause freezes all objective progress and match time")
	scene._resume(); await frames(780)
	check(director.state.objectives.snapshot()[2].owner==1 and director.state.tickets[2]<300,"real vehicle completes C and drains opponent tickets through production ledger")
	check(scene.map_atlas.objective_states.C.owner==1 and scene.objective_hud.rows[2].owner==1,"HUD and tactical atlas show authoritative C ownership")
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(scene.objective_hud.get_global_rect()),"three point strip fits default viewport")
	await capture("02_C_owned")
	# Controlled real-Actor fixtures isolate authoritative occupancy, damage and result semantics.
	director.set_physics_process(false); director.begin(16,RiverJunctionDefinition.capture_definitions()); director.state.phase="playing"
	director.state.register_spawn("A",scene.actor)
	scene.controller.commands_enabled=false; scene.actor.tank.velocity=Vector3.ZERO; scene.actor.tank.forward_speed=0
	var count := 0
	for id in director.state.roster:
		if id=="A": continue
		if DisplayServer.get_name()!="headless" and id not in ["A2","B","B2"]: continue
		var team: int=director.state.roster[id].team
		var slot := 0 if id.length()==1 else int(id.substr(1))-1
		var vehicle := make_vehicle(id,RiverJunctionDefinition.spawns(16,team)[slot].origin)
		if vehicle!=null: count+=1
	check(count==(31 if DisplayServer.get_name()=="headless" else 3),"configured roster accepts actual distinct vehicle lives ("+str(count+1)+" loaded)")
	var centers := RiverJunctionDefinition.capture_definitions()
	scene.actor.tank.global_position=centers[0].center
	var ally := director.state.actor_for("A2"); var enemy := director.state.actor_for("B"); var enemy2 := director.state.actor_for("B2")
	ally.tank.global_position=centers[1].center; enemy.tank.global_position=centers[1].center+Vector3(8,0,0); enemy2.tank.global_position=centers[2].center
	for row in director.state.roster.values(): row.protection_left=0
	director.state.roster.A.protection_left=3
	director.advance(3)
	check(director.state.objectives.snapshot()[0].progress==0 and director.state.objectives.snapshot()[1].contested,"spawn protection excludes A while opposing real tanks contest B")
	director.advance(12)
	var rows := director.state.objectives.snapshot()
	check(rows[0].owner==1 and rows[1].owner==0 and rows[1].contested and rows[2].owner==2,"one tick independently resolves actual A capture, B contest and enemy C capture")
	await frames(3); await capture("03_three_independent_points")
	enemy.state.destroy_once("objective_fixture",{}); director.advance(.25)
	check(not director.state.objectives.snapshot()[1].contested and director.state.objectives.snapshot()[1].progress>0 and director.state.roster.B.deaths==1,"destroyed enemy stops contesting and death ledger charges once")
	var after_death: int=director.state.tickets[2]; director.advance(.25)
	check(director.state.roster.B.deaths==1 and director.state.tickets[2]>=after_death-1,"repeated destroyed actor cannot charge a second death")
	var before_stale: float=director.state.objectives.snapshot()[1].progress
	ally.state.generation+=1; director.advance(.25)
	check(director.state.objectives.snapshot()[1].progress==before_stale,"stale registered generation cannot capture")
	ally.state.generation-=1
	await frames(2); await capture("04_contest_cleared")
	director.state.tickets={1:1,2:1}; director.state.drain_bank={1:0.0,2:0.0}; director.advance(1)
	check(director.state.phase=="finished" and director.state.result.outcome=="draw" and director.state.result.objectives.size()==3,"simultaneous opposing point drain settles one draw with all three final states")
	var final := director.state.result.duplicate(true); director.advance(50)
	check(director.state.finish_count==1 and director.state.result==final and not director.finish_once("victory","late"),"final result and point evidence remain immutable on late ticks")
	await frames(2); await capture("05_training_result")
	scene._pause(); await frames(3); await capture("06_pause_restart"); await click(scene.restart_capture_button)
	check(scene._paused and director.state.phase=="countdown" and director.state.tickets[1]==300 and director.state.objectives.snapshot()[0].owner==0,"pause restart button creates a fresh three-point exercise without resuming")
	scene.hud.training_requested.emit(); await frames(5)
	check(app.garage!=null and app.training==null and app.profile.snapshot()==profile_before and app.match_token.is_empty(),"return restores garage without committing training reward or changing lineup")
	app.free(); await frames(2)
	print("RESULT multi_objective passed=%d failed=%d"%[passed,failed]); quit(0 if failed==0 else 1)
