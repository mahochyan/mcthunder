extends SceneTree
var checks := 0
var failed := 0
var shot_dir := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+text)
func frames() -> void:
	for i in 5: await process_frame
func capture(name: String) -> void:
	if shot_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(shot_dir.path_join(name+".png"))==OK,"capture actual frontend: "+name)
func click(button: Control) -> void:
	if DisplayServer.get_name()=="headless":
		(button as Button).pressed.emit(); await frames(); return
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position=point; Input.parse_input_event(motion)
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.pressed=down
		Input.parse_input_event(event); await frames()
func run() -> void:
	var args := OS.get_cmdline_user_args(); var index := args.find("--shot-dir")
	if index>=0 and index+1<args.size(): shot_dir=args[index+1]; DirAccess.make_dir_recursive_absolute(shot_dir)
	var g := GarageShell.new(); g.profile=ProfileStore.new(""); root.add_child(g); await frames()
	var initial := g.profile.snapshot()
	check(g.frontend!=null and g.frontend.cards.size()==g.vehicle_choice.item_count,"real roster drives frontend cards")
	await capture("01_deployment_720")
	await click(g.frontend.cards[1])
	check(g.selected_vehicle_id()==VehicleCatalog.IDS[0] and g.preview.layout==g.catalog.packages[VehicleCatalog.IDS[0]].layout,"card activation switches actual vehicle and inspection geometry")
	await click(g.frontend.tabs[1])
	check(g.preparation.details.is_visible_in_tree() and not g.frontend.pages[0].visible,"equipment navigation exposes real ammunition and lineup controls")
	await capture("02_equipment_720")
	await click(g.frontend.tabs[2])
	check(g.start_button.is_visible_in_tree() and not g.preparation.details.is_visible_in_tree(),"training tab retains actual range entry")
	await capture("03_training_720")
	await click(g.frontend.tabs[0])
	var selected := {"mode":""}
	g.laboratory_requested.connect(func(id: String) -> void: selected.mode=id)
	await click(g.frontend.deploy)
	check(selected.mode=="team","primary deploy emits actual existing team match request")
	check(g.profile.snapshot()==initial,"navigation and preview do not write profile or award progress")
	g.frontend.deploy.grab_focus(); await frames()
	check(root.gui_get_focus_owner()==g.frontend.deploy,"primary action has keyboard focus")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=dimensions; await frames()
		check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(g.frontend.deploy.get_global_rect()),"deployment action stays in viewport: "+str(dimensions))
		for card in g.frontend.cards: check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(card.get_global_rect()),"vehicle card stays in viewport")
		await capture("04_deployment_"+str(dimensions.x))
	g.free(); await frames()
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("GARAGE_FRONTEND_CHECKS_PASS" if failed==0 else "GARAGE_FRONTEND_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
