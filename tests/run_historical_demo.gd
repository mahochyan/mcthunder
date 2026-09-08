extends Node
## Windowed evidence from the normal garage, keys and mouse. No direct fire/cooldown/state writes.
var app: AppFlow
var shot_dir := ""
var checks := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)

func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
	await get_tree().process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code,true); await frames(2); key(code,false); await frames(2)

func mouse(button: MouseButton, pressed: bool, point: Vector2 = Vector2(640,360)) -> void:
	var event := InputEventMouseButton.new()
	event.position = point; event.global_position = point; event.button_index = button; event.pressed = pressed
	Input.parse_input_event(event)

func click(button: Control) -> void:
	check(is_instance_valid(button) and button.is_visible_in_tree(),"normal UI control is visible before click")
	if not is_instance_valid(button): return
	# Follow the public scroll interaction when the expanded garage puts a control below the fold.
	var ancestor := button.get_parent()
	while ancestor != null and not ancestor is ScrollContainer: ancestor = ancestor.get_parent()
	if ancestor is ScrollContainer:
		for attempt in 35:
			var clip: Rect2 = ancestor.get_global_rect()
			var rect := button.get_global_rect()
			if rect.position.y >= clip.position.y+2 and rect.end.y <= clip.end.y-2: break
			var wheel := MOUSE_BUTTON_WHEEL_DOWN if rect.end.y > clip.end.y-2 else MOUSE_BUTTON_WHEEL_UP
			mouse(wheel,true,clip.get_center()); mouse(wheel,false,clip.get_center()); await frames(3)
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	Input.parse_input_event(motion); await frames(3)
	mouse(MOUSE_BUTTON_LEFT,true,point); await frames(2); mouse(MOUSE_BUTTON_LEFT,false,point)
	await frames(12)

func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found := find_button(child,title)
		if found != null: return found
	return null

func capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	check(not image.is_empty() and image.save_png(shot_dir.path_join(id+".png")) == OK,"actual window capture "+id+" (review pending)")

func run(flow: AppFlow) -> void:
	app = flow
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot-dir" and i+1 < args.size(): shot_dir = args[i+1]
	if shot_dir.is_empty(): shot_dir = ProjectSettings.globalize_path("res://docs/evidence/020/wip")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await frames(30)
	for index in range(1,5):
		var id: String = VehicleCatalog.IDS[index-1]
		await click(app.garage.vehicle_choice)
		await tap(KEY_HOME)
		for step in index+1: await tap(KEY_DOWN)
		await tap(KEY_ENTER)
		await frames(16)
		check(app.garage.selected_vehicle_id() == id,"normal popup selects "+id)
		await capture(str(index)+"_garage")
		await click(app.garage.inspect_button)
		await capture(str(index)+"_armor")
		await click(app.garage.inspect_button)
		await capture(str(index)+"_interior")
		await click(app.garage.dossier_button)
		await capture(str(index)+"_dossier")
		await click(find_button(app.garage,"关闭资料档案"))
		await click(app.garage.start_button)
		await frames(30)
		var range: BallisticsRange = app.training
		check(range != null and range.actor.definition.id == id,"normal garage entry drives selected "+id)
		if range == null: break
		var start := range.actor.tank.global_position
		key(KEY_W,true); await frames(65); key(KEY_W,false); await frames(15)
		check(range.actor.tank.global_position.distance_to(start) > 0.5,"normal W input moves "+id)
		await capture(str(index)+"_driving")
		mouse(MOUSE_BUTTON_LEFT,true); await frames(8); mouse(MOUSE_BUTTON_LEFT,false)
		check(range.actor.gunner.shots_fired == 1,"normal mouse input fires selected weapon "+id)
		await capture(str(index)+"_fired")
		mouse(MOUSE_BUTTON_RIGHT,true); await frames(12)
		await capture(str(index)+"_scope")
		check(range.actor.cam_rig.cam.cull_mask & GameConfig.VIS_LAYER_VEHICLE == 0,"scope excludes own reconstructed vehicle "+id)
		mouse(MOUSE_BUTTON_RIGHT,false)
		await tap(KEY_ESCAPE)
		await click(range.hud._training_btn)
		await frames(20)
		check(is_instance_valid(app.garage),"normal pause menu returns to garage")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	if failed == 0: print("HISTORICAL_DEMO_CHECKS_PASS")
	get_tree().quit(0 if failed == 0 else 1)
