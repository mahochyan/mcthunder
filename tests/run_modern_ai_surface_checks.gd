extends SceneTree
## Short, explicit stationary encounter. Production modern packets, mechanisms,
## observations, ammunition and projectile/damage rules; no natural-match claim.
var actors: Array[VehicleActor] = []
var trace: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var failed := 0
var checks := 0
func _initialize() -> void:
	create_timer(120,true,false,true).timeout.connect(func() -> void: print("MODERN_AIM_STALL_TIMEOUT"); quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		await run_case(PackedStringArray(),"clear")
		await run_case(PackedStringArray(["--low-cover"]),"low_cover")
		await run_case(PackedStringArray(["--friendly-lane"]),"friendly_lane")
	else:
		await run_case(args,"selected")
	print("=== result: %d checks, %d failed ==="%[checks,failed])
	quit(0 if failed == 0 else 1)

func run_case(args: PackedStringArray, label: String) -> void:
	actors.clear(); trace.clear(); contacts.clear()
	var failures_before := failed
	var output := "user://tests/modern_ai_surface/"+label+"/evidence.json"
	for i in args.size():
		if args[i] == "--out" and i+1 < args.size(): output = args[i+1]
	var defs := VehicleDefs.new()
	var loaded := VehicleCatalog.new().load_engineering(defs)
	check(loaded.ok,"registered modern packets retain their actual validation")
	if not loaded.ok: return
	var world := Node3D.new()
	root.add_child(world)
	VehicleSimulationDriver.for_scene(world)
	TerrainFixtures.box(world,Vector3(0,-0.5,-90),Vector3(300,1,400))
	if args.has("--low-cover"):
		TerrainFixtures.box(world,Vector3(0,0.65,-80),Vector3(6,1.3,0.5))
	for i in 2:
		var vehicle := VehicleActor.new()
		vehicle.presentation_enabled = false
		world.add_child(vehicle)
		var id := "ussr_t_80b" if i == 0 else "germ_leopard_2a4"
		var pose := Transform3D(Basis(Vector3.UP,0 if i == 0 else PI),Vector3(0,0.8,0 if i == 0 else -170))
		check(vehicle.setup(defs,id,"A" if i == 0 else "B",i+1,pose,4,null).ok,"actual Actor setup: "+id)
		vehicle.gunner.aim_preview_enabled = false
		actors.append(vehicle)
	if args.has("--friendly-lane"):
		var friendly := VehicleActor.new()
		friendly.presentation_enabled = false
		world.add_child(friendly)
		check(friendly.setup(defs,"ussr_t_80b","A2",1,Transform3D(Basis.IDENTITY,Vector3(1.8,0.8,-140)),4,null).ok,"real friendly hull partly screens the lower firing lane")
		friendly.gunner.aim_preview_enabled = false
		actors.append(friendly)
	if failed > failures_before: world.free(); return
	await frames(60)
	var shooter := actors[0]
	var target := actors[1]
	var manager := ProjectileManager.new()
	manager.presentation_enabled = false
	world.add_child(manager)
	manager.projectile_contact.connect(func(event: Dictionary) -> void: contacts.append(event.duplicate(true)))
	manager.snapshot_provider = func() -> Array:
		var rows: Array = []
		for actor in actors: rows.append(QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override))
		return rows
	manager.exclude_provider = func(_entity: String, _life: int) -> Array[RID]: return [shooter.tank.get_rid()]
	manager.damage_handler = func(event: Dictionary, budget: float) -> Dictionary:
		for actor in actors:
			if actor.entity_id == event.get("entity_id",""): return actor.apply_projectile_damage(event,budget)
		return {"ok":false,"reason":"missing_actor"}
	shooter.gunner.projectile_manager = manager
	shooter.gunner.round_provider = func() -> int: return 4044
	var ai := AITankController.new()
	shooter.add_child(ai)
	# The river configures initial A before register_spawn increments spawns:
	# match_seed 44001 + team 1 * 100 + initial spawns 0 * 101.
	ai.configure(shooter,DriveNavigator.new(),func() -> Array: return actors,"normal",44101)
	if args.has("--zero-error"): ai.difficulty.error_degrees = 0.0 # Diagnostic control only.
	shooter.set_controller(ai)
	var last_queries := -1
	var seen_visible := false
	for frame in 900:
		await physics_frame
		seen_visible = seen_visible or ai.observation.get("visible",false)
		if ai.sensor.lane_queries != last_queries:
			last_queries = ai.sensor.lane_queries
			trace.append({"frame":frame,"clock":ai.clock,"queries":last_queries,"shots":shooter.gunner.shots_fired,
				"authorization":ai.last_fire_authorization.duplicate(true),"error":ai._aim_error,"surface_sample":ai.sensor.preferred_sample,
				"observation":ai.observation.duplicate(true),"muzzle":shooter.turret.muzzle.global_position,
				"barrel":shooter.turret.barrel_direction(),"solution":ai.last_aim_solution.duplicate(true)})
		if shooter.gunner.shots_fired > 0: break
	await frames(20)
	check(seen_visible,"stationary encounter exposes a real visible enemy")
	check(shooter.capabilities().fire and shooter.gunner.rounds_remaining > 0,"own weapon remains usable with actual ammunition")
	check(shooter.gunner.shots_fired > 0,"usable AI can finish aiming and fire in the bounded stationary encounter")
	var errors: Array = []
	var missed := false
	var expected_veto := "world_blocked" if args.has("--low-cover") else "predicted_path_misses"
	if args.has("--friendly-lane"): expected_veto = "other_vehicle_first"
	var changed_surface := false
	var fired_only_when_allowed := true
	for row in trace:
		if row.queries == 0: continue
		if not errors.has(row.error): errors.append(row.error)
		missed = missed or row.authorization.get("reason","") == expected_veto
		changed_surface = changed_surface or row.surface_sample != 0
		if row.shots > 0: fired_only_when_allowed = fired_only_when_allowed and row.authorization.get("ok",false)
	check(errors.size() == 1,"surface retry retains the same difficulty error rather than rolling a better one")
	if not args.has("--zero-error"):
		check(missed and changed_surface,"the initial river-life error exercises "+expected_veto+" and surface retry")
	check(fired_only_when_allowed,"every observed shot still requires actual lane authorization")
	var records: Array = []
	var actual_contact := false
	for contact in contacts:
		actual_contact = actual_contact or contact.get("entity_id","") == target.entity_id
	for i in manager.shot_records.count():
		var record: Dictionary = manager.shot_records.get_record(i)
		records.append(record)
		for contact in record.contacts:
			actual_contact = actual_contact or contact.get("entity_id","") == target.entity_id
	check(actual_contact,"real projectile contacts the intended modern vehicle after the surface retry")
	if args.has("--friendly-lane"):
		var hit_friendly := false
		for contact in contacts: hit_friendly = hit_friendly or contact.get("entity_id","") == "A2"
		check(not hit_friendly,"surface retry does not fire through the actual friendly hull")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output,FileAccess.WRITE)
	check(file != null,"stationary diagnostic evidence can be written")
	if file != null:
		file.store_string(JSON.stringify({"fixture":"stationary 170 m modern encounter","seed":44101,"low_cover":args.has("--low-cover"),"friendly_lane":args.has("--friendly-lane"),"zero_error_control":args.has("--zero-error"),
			"shots":shooter.gunner.shots_fired,"target_destroyed":target.state.destroyed,"trace":trace,"contacts":contacts,"completed_shots":records},"  "))
		file.close()
	world.free()
	await frames(2)
