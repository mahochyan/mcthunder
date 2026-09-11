extends SceneTree
## Fixed eight-vehicle query workload. Compare fingerprints before comparing cost.
## This isolates query CPU time; it is not a rendered match performance test.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty(): print("[FAIL] report path required"); quit(1); return
	var defs := VehicleDefs.new()
	defs.load_defaults()
	var catalog := VehicleCatalog.new()
	if not catalog.load_all(defs).ok: print("[FAIL] historical catalog"); quit(1); return
	var world := Node3D.new()
	root.add_child(world)
	var snapshots: Array = []
	for index in 8:
		var actor := VehicleActor.new()
		world.add_child(actor)
		var pose := Transform3D(Basis(Vector3.UP,index*0.17),Vector3((index%4)*12,100,(index/4)*24))
		if not actor.setup(defs,VehicleCatalog.IDS[index%4],"target%d"%index,2,pose,4,null).ok:
			print("[FAIL] historical actor"); world.free(); quit(1); return
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		snapshots.append(QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override))
	var requests: Array = []
	for index in 8:
		for height in [0.6,1.2,2.1,2.8]:
			for yaw in [0.0,0.5,1.2,2.0]:
				var direction := Vector3(sin(yaw),0,cos(yaw))
				var center := Vector3((index%4)*12,100+height,(index/4)*24)
				requests.append({"from_world":center-direction*80,"to_world":center+direction*80,
					"include_modules":index%2==0,"include_crew":index%2==0})
	var golden: Array = []
	var contacts := 0
	for request in requests:
		var result := ShotQueryService.query(request,snapshots)
		golden.append(result)
		contacts += result.events.size()
	var samples: Array = []
	var equal := true
	# Warmed cache, repeated identical requests; output comparison is outside timing.
	for batch in 7:
		var actual: Array = []
		var started := Time.get_ticks_usec()
		for request in requests: actual.append(ShotQueryService.query(request,snapshots))
		samples.append((Time.get_ticks_usec()-started)/1000.0)
		equal = equal and actual==golden
	var report := {"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),
		"actors":8,"requests_per_batch":requests.size(),"batch_ms":samples,
		"contacts":contacts,"outputs_identical":equal,"fingerprint":JSON.stringify(golden).sha256_text(),
		"scope":"fixed eight historical vehicle geometry; mixed external and internal rays; warm cache; excludes rendering and snapshot construction"}
	var path := ProjectSettings.globalize_path(args[0])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: print("[FAIL] cannot write report"); world.free(); quit(1); return
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	var passed := equal and contacts>0
	print("[query profile] ",JSON.stringify(report))
	print("QUERY_PROFILE_PASS" if passed else "QUERY_PROFILE_FAIL")
	world.free()
	quit(0 if passed else 1)
