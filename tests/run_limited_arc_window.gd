extends SceneTree
## Explicit limited-arc engineering fixture; actual window mouse input, common player and turret logic.
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func _run() -> void:
	root.size = Vector2i(1280,720)
	var defs := VehicleDefs.new(); defs.load_defaults()
	var catalog := VehicleCatalog.new(); catalog.load_all(defs)
	var id: String = VehicleCatalog.IDS[1]
	var vehicle := defs.get_vehicle(id).duplicate(true) as VehicleDefinition
	vehicle.id = "limited_arc_window_fixture"; vehicle.content_tier = "test"; vehicle.verification = "estimated"
	vehicle.turret_yaw_min = -12; vehicle.turret_yaw_max = 12
	defs.vehicles[vehicle.id] = vehicle
	defs.content_packets[vehicle.id] = catalog.packages[id].packet
	var actor := VehicleActor.new(); root.add_child(actor)
	check(actor.setup(defs,vehicle.id,"ARC_FIXTURE",1,Transform3D.IDENTITY,2,null).ok,"limited traverse is an explicit engineering fixture")
	var controller := PlayerController.new(); actor.add_child(controller); actor.set_controller(controller)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"real window captures mouse")
	await frames(4)
	for horizontal in [600,-1200]:
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(640,360); motion.relative = Vector2(horizontal,0)
		Input.parse_input_event(motion)
		await frames(150)
		var intended := rad_to_deg(actor.cam_rig.aim_yaw)
		var actual := rad_to_deg(actor.turret.rotation.y)
		print("[mouse] dx=",horizontal," intent_deg=",intended," cannon_deg=",actual)
		check(absf(intended) > 12 and absf(actual) <= 12.001 and absf(actual) > 11.9,"real mouse moves view outside traverse while common cannon stops at 12 degrees")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	actor.free()
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	if failed == 0: print("LIMITED_ARC_WINDOW_CHECKS_PASS")
	quit(0 if failed == 0 else 1)
